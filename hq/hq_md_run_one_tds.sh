#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_md_run_one_tds.sh

Has to be run in the TDS root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "0" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 0"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Standard error response
error_response_std() {

    # Printing some information
    echo
    echo "An error was trapped" 1>&2
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE_BS}/error.pipeline
            exit 1
        else
            cd ..
        fi
    done

    # Printing some information
    echo "Error: Cannot find the input-files directory..."
    exit 1
}
trap 'error_response_std $LINENO' ERR SIGINT SIGQUIT SIGTERM

# Exit cleanup
cleanup_exit() {

    echo
    echo " * Cleaning up..."

    # Removing output files to reduce total number of files
    if [ "${md_keep_logfiles^^}" == "FALSE" ]; then

        # i-PI
        rm ipi/RESTART >/dev/null 2>&1 || true
        rm ipi/ipi.out.*screen >/dev/null 2>&1 || true

        # CP2K
        for bead_folder in $(ls -v cp2k/); do
            rm cp2k/${bead_folder}/cp2k.out* >/dev/null 2>&1 || true # Problematic if using CPMD2 (which uses restart files)
        done
    fi

    # Terminating all processes
    if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then

        echo -e "\n * Information about all jobs of the user: \n"
        ps -fu $USER

        echo -e "\n * The following jobs processes will be terminated: \n"
        echo
        pgrep ${pids[*]} | xargs ps -o pid,pgid,ppid,command
        echo
        pgrep ${pids[*]} | xargs pwdx
        echo
        pgrep -P ${pids[*]} | xargs ps -o pid,pgid,ppid,command
        echo
        pgrep -P ${pids[*]} | xargs pwdx
        echo
        pgrep -P $$ | xargs ps -o pid,pgid,ppid,command
        echo
        pgrep -P $$ | xargs pwdx
        echo
    fi

    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Terminating the main processes
        kill ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 5 || true
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.*.${tds_folder//tds.} 1>/dev/null 2>&1 || true

        # Removing output files to reduce total number of files
        if [ ${md_keep_logfiles^^} = FALSE ]; then
            # i-PI
            rm ipi/RESTART >/dev/null 2>&1 || true
            # CP2K
            for bead_folder in $(ls -v cp2k/); do
                rm cp2k/${bead_folder}/cp2k.out* >/dev/null 2>&1 || true
            done
        fi

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1 || true
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent (again because sometimes a few are still left)
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.*.${tds_folder//tds.} 1>/dev/null 2>&1 || true

        # Removing output files to reduce total number of files
        if [ ${md_keep_logfiles^^} = FALSE ]; then
            # i-PI
            rm ipi/RESTART >/dev/null 2>&1 || true
            # CP2K
            for bead_folder in $(ls -v cp2k/); do
                rm cp2k/${bead_folder}/cp2k.out* >/dev/null 2>&1 || true
            done
        fi

        # Terminating everything else which is still running and which was started by this script, which will include the current exit-code
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true
    " &> /dev/null || true
}
trap "cleanup_exit" EXIT

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
system_name="$(pwd | awk -F '/' '{print     $(NF-2)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-1)}')"
tds_folder="$(pwd | awk -F '/' '{print $(NF)}')"
tds_index="${tds_folder/tds-}"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_timeout="$(grep -m 1 "^md_timeout_${subsystem}=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_keep_logfiles="$(grep -m 1 "^md_keep_logfiles=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
run=$(grep "output.*ipi.out.run" ipi/ipi.in.main.xml | grep -o "run[0-9]*" | grep -o "[0-9]*")
sim_counter=0

# Running ipi
if [[ "${md_programs}" == *"ipi"* ]]; then

    # Preparing files and folder
    cd ipi
    echo " * Cleaning up the ipi folder"
    if [ ${md_continue^^} == "FALSE" ]; then
        rm ipi.out* > /dev/null 2>&1 || true
    fi
    rm ipi.out.run${run}* > /dev/null 2>&1 || true
    rm *RESTART* > /dev/null 2>&1 || true

    # Updating the input file (directly here before the simulation due to the timestamp in the socket address)
    sed -i "s|<address>.*iqi.*|<address>${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.iqi.${tds_folder//tds.}</address>|g" ipi.in.*
    sed -i "s|<address>.*cp2k.*|<address>${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.cp2k.${tds_folder//tds.}</address>|g" ipi.in.*

    # Removing the socket files if still existent from previous runs
    rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.*.${tds_folder//tds.} 1>/dev/null 2>&1 || true

    # Starting ipi
    echo " * Starting ipi"
    # We always keep the screen output file because we use it as an major indicator whether i-PI is still running or not. Therefore we also use the stdbuf command only for this program
    stdbuf -oL ipi ipi.in.main.xml > ipi.out.run${run}.screen 2> ipi.out.run${run}.err &
    pid_ipi=$!

    # Updating variables
    pids[${sim_counter}]=$pid_ipi
    sim_counter=$((sim_counter+1))
    cd ..
fi

# Running CP2K
if [[ "${md_programs}" == *"cp2k"* ]]; then

    # Variables
    ncpus_cp2k_md="$(grep -m 1 "^ncpus_cp2k_md_${subsystem}=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../input-files/config.txt | awk -F '[=#]' '{print $2}')"
    max_it=500
    iteration_no=0

    # Loop for waiting until the socket file exists
    while true; do
        if [ -e /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.cp2k.${tds_folder//tds.} ]; then
            for bead_folder in $(ls -v cp2k/); do

                # Preparing files and folder
                cd cp2k/${bead_folder}
                if [ ${md_continue^^} == "FALSE" ]; then
                    rm cp2k.out* > /dev/null 2>&1 || true
                fi
                rm cp2k.out.run${run}* > /dev/null 2>&1 || true

                # Updating the input file (directly here before the simulation due to the timestamp in the socket address)
                sed -i "s|HOST.*cp2k.*|HOST ${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.cp2k.${tds_folder//tds.}|g" cp2k.in.*

                # Checking the input file
                ${cp2k_command} -e cp2k.in.main > cp2k.out.run${run}.config 2>cp2k.out.run${run}.err

                # Starting cp2k
                echo " * Starting CP2K for ${bead_folder}..."
                if [ "${md_keep_logfiles^^}" == "TRUE" ]; then
                    OMP_NUM_THREADS=${ncpus_cp2k_md} ${cp2k_command} -i cp2k.in.main > cp2k.out.run${run}.screen 2>cp2k.out.run${run}.err &
                    pid=$!
                elif [ "${md_keep_logfiles^^}" == "FALSE" ]; then
                    sed -i "s|PRINT_LEVEL .*|PRINT_LEVEL silent|g" cp2k.in.*
                    OMP_NUM_THREADS=${ncpus_cp2k_md} ${cp2k_command} -i cp2k.in.main >/dev/null 2>cp2k.out.run${run}.err &
                    pid=$!
                fi

                # Updating variables
                pids[${sim_counter}]=$pid
                sim_counter=$((sim_counter+1))
                cd ../../
                i=$((i+1))
                sleep 1
            done
            break
        else

            # Checking if there is an reported error by ipi in the error output file if existent
            if [ -f ipi/ipi.out.run${run}.err ]; then

                # Variables
                error_count="$( { grep -i error ipi/ipi.out.run${run}.err  || true; } | wc -l)"

                # Checking the error_count
                if [ ${error_count} -ge "1" ]; then

                    # Printing some information
                    echo -e "Error detected in the ipi output files"
                    echo "Exiting..."
                    exit 1
                fi
            fi

            # Checking the iteration number
            if [ "$iteration_no" -lt "$max_it" ]; then
                echo " * The socket file for the MD simulation running in ${PWD} does not yet exist. Waiting 1 second (iteration $iteration_no)..."
                sleep 1
                iteration_no=$((iteration_no+1))
            else
                echo " * The socket file for MD simulation ${system_name} does not yet exist."
                echo " * The maximum number of iterations ($max_it) for the MD simulation of TDS ${tds_index} of MSP ${system_name} has been reached."
                echo " * Exiting..."
                exit 1
            fi
        fi
    done
fi

# Running i-QI
if [[ "${md_programs}" == *"iqi"* ]]; then

    # Preparing files and folder
    cd iqi
    echo " * Cleaning up the iqi folder"
    if [ ${md_continue^^} == "FALSE" ]; then
        rm iqi.out.* > /dev/null 2>&1 || true
    fi
    rm iqi.out.run${run}* > /dev/null 2>&1 || true

    # Updating the input file (directly here before the simulation due to the timestamp in the socket address)
    sed -i "s|<address>.*iqi.*|<address>${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.iqi.${tds_folder//tds.}</address>|g" iqi.in.*

    # Starting i-QI
    echo " * Starting iqi"
    if [ "${md_keep_logfiles^^}" == "TRUE" ]; then
        iqi iqi.in.main.xml > iqi.out.run${run}.screen 2> iqi.out.run${run}.err &
        pid=$!
    elif [ "${md_keep_logfiles^^}" == "FALSE" ]; then
        iqi ipi.in.main.xml 2> iqi.out.run${run}.err
        pid_ipi=$!
    else
        # Printing some information
        echo " * Error: The variables md_keep_logfiles has an unsupported value (${md_keep_logfiles}). Exiting..."

        # Exiting
        exit 1
    fi

    # Updating variables
    pids[${sim_counter}]=$pid
    sim_counter=$((sim_counter+1))
    cd ../
fi

# Running NAMD
if [[ "${md_programs}" == "namd" ]]; then
    cd namd
    # ncpus_namd_md="$(grep -m 1 "^ncpus_namd_md=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    namd_command="$(grep -m 1 "^namd_command=" ../../../../../input-files/config.txt | awk -F '[=#]' '{print $2}')"
    ${namd_command} namd.in.md > namd.out.run${run}.screen 2>namd.out.run${run}.err & # removed +idlepoll +p${ncpus_namd_md}
    pid=$!
    pids[${sim_counter}]=$pid
    sim_counter=$((sim_counter+1))
    cd ..
fi

# Checking the status of the simulation
stop_flag="false"
while true; do

    # Printing some information
    if [ "${HQ_VERBOSITY_RUNTIME}" == "debug" ]; then
        echo " * Checking if the simulation running in folder ${PWD} has completed or should be terminated."
    fi

    # Checking if the workflow is run by the BS module
    if [ -n "${HQ_BS_JOBNAME}" ]; then

        # Determining the control file responsible for us
        cd ../../../../
        controlfile="$(hqh_bs_controlfile_determine.sh ${HQ_BS_JTL} ${HQ_BS_JID})"

        # Getting the relevant value
        terminate_current_job="$(hqh_gen_inputfile_getvalue.sh ${controlfile} terminate_current_job true)"
        cd -

        # Checking the value
        if [ "${terminate_current_job^^}" == "TRUE" ]; then

            # Printing some information
            echo " * According to the controlfile ${controlfile} the current batchsystem job should be terminated immediately. Stopping this simulation and exiting..."

            # Exiting
            exit 0
        fi
    fi

    # Checking the condition of the output files
    if [ -f ipi/ipi.out.run${run}.screen ]; then

        # Variables
        time_diff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.run${run}.screen)))

        # Checking the time diff
        if [[ "${time_diff}" -ge "${md_timeout}" ]] && [[ "${time_diff}" -le "$((md_timeout+100))" ]]; then
            
            # Printing some information
            echo " * i-PI seems to have completed the MD simulation."
            break
        elif [[ "${time_diff}" -ge "$((md_timeout+100))" ]]; then
        
            # If the time diff is larger, then the workflow will most likely have been suspended and has now been resumed
            touch ipi/ipi.out.run${run}.screen
        fi
    fi
    if [ -f ipi/ipi.out.run${run}.err ]; then
        
        # Variables
        error_count="$( { grep -i error ipi/ipi.out.run${run}.err  || true; } | wc -l)"

        # Checking the error_count
        if [ ${error_count} -ge "1" ]; then

            # Printing some information
            echo -e "Error detected in the ipi output files"
            echo "Exiting..."
            exit 1
        fi
    fi
    # Checking the condition of the output files of cp2k
    for bead_folder in $(ls -v cp2k/); do

        # Checking if memory error - happens often at the end of runs it seems, thus we treat it as a successful run
        if [ -f cp2k/${bead_folder}/cp2k.out.run${run}.err ]; then

            # Variables
            pseudo_error_count="$( { grep -E "invalid memory reference | corrupted | Caught" cp2k/${bead_folder}/cp2k.out.run${run}.err || true; } | wc -l)"

            # Checking the pseudo_error_count
            if [ "${pseudo_error_count}" -ge "1" ]; then

                # Printing some message
                echo " * The MD simulation seems to have completed."

                # Termination
                break 2
            fi
        fi

        # Checking if an error file exists
        if [ -f cp2k/${bead_folder}/cp2k.out.run${run}.err ]; then

            # Variables
            error_count="$( { grep -i error cp2k/${bead_folder}/cp2k.out.run${run}.err || true; } | wc -l)"

            # Checking the error count
            if [ ${error_count} -ge "1" ]; then

                # Variables
                set +o pipefail
                backtrace_length="$(grep -A 100 Backtrace cp2k/${bead_folder}/cp2k.out.run${run}.err | grep -v Backtrace | wc -l)"
                socket_error_count="$(grep -A 100 socket cp2k/${bead_folder}/cp2k.out.run${run}.err | wc -l)"
                set -o pipefail

                # Checking the variables
                if [ "${backtrace_length}" -ge "1" ]; then

                    # Printing error message
                    echo -e "Error detected in the file cp2k/${bead_folder}/cp2k.out.run${run}.err."

                    # Termination
                    exit 1
                elif [ "${socket_error_count}" -ge "1" ]; then

                    # Printing error message
                    echo -e "Error detected in the file cp2k/${bead_folder}/cp2k.out.run${run}.err related to the socket."

                    # Termination
                    exit 1
                else

                    # Printing message
                    echo " * The MD simulation seems to have completed."

                    # Termination
                    break 2
                fi
            fi
        fi
    done

    # Checking if ipi has terminated (hopefully without error after the previous error checks)
    if [ ! -e /proc/${pid_ipi} ]; then

        # Checking the condition of the output files
        sleep 1 || true
        if [ -f ipi/ipi.out.run${run}.err ]; then

            # Variables
            error_count="$( { grep -i error ipi/ipi.out.run${run}.err || true; } | wc -l)"

            # Checking the error count
            if [ ${error_count} -ge "1" ]; then
                echo -e "Error detected in the ipi output files"
                echo "Exiting..."
                exit 1
            fi
        else

            # Variables
            time_diff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.run${run}.screen)))
            
            # Still waiting until we reach md_timeout, just in case the process check was erroneous 
            if [ "${time_diff}" -ge "${md_timeout}" ]; then
                
                # Printing message
                echo " * i-PI seems to have completed the MD simulation."
                break 2
            fi
        fi
    fi

    # Checking if there are new restart files and compressing them if there are some
    for restart_file in $(find ipi -iregex ".*ipi.out.run.*restart_[0-9]+$"); do
        bzip2 -f $restart_file || true # Very few times errors are occurring (e.g. "bzip2: I/O or other error, bailing out.  Possible reason follows. bzip2: No such file or directory. Input file = ipi/ipi.out.run1.restart_156, output file = ipi/ipi.out.run1.restart_156.bz2" even though the file existed already
    done

    # Sleeping before next round
    sleep 50 || true   # true because the script might be terminated while sleeping, which would result in an error
done
