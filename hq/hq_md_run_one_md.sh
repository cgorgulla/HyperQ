#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_md_run_one_md.sh

Has to be run in the md main folder."

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
    echo "Reason: The wrong number of arguments were provided when calling the script."
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
    echo "The error occured in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occured on line $1" 1>&2
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then
            # Setting the error flag
            mkdir -p runtime
            echo "" > runtime/error
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

    # Terminating all processes
    echo " * Terminating remaining processes..."
    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Terminating the main processes
        kill ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 5 || true
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.*.${md_name//md.} 1>/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1 || true
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent (again because sometimes a few are still left)
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.*.${md_name//md.} 1>/dev/null 2>&1 || true

        # Terminating everything else which is still running and which was started by this script, which will include the current exit-code
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true
    " &> /dev/null || true
}
trap "cleanup_exit" EXIT



# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Bash options
set -o pipefail

# Variables
system_name="$(pwd | awk -F '/' '{print     $(NF-2)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-1)}')"
md_name="$(pwd | awk -F '/' '{print $(NF)}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
md_timeout="$(grep -m 1 "^md_timeout_${subsystem}=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
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
    sed -i "s|<address>.*cp2k.*|<address> ${runtimeletter}.${HQF_STARTDATE}.md.cp2k.${md_name//md.} </address>|g" ipi.in.main.xml
    sed -i "s|<address>.*iqi.*|<address> ${runtimeletter}.${HQF_STARTDATE}.md.iqi.${md_name//md.} </address>|g" ipi.in.main.xml

    # Starting ipi
    echo " * Starting ipi"
    stdbuf -oL ipi ipi.in.main.xml > ipi.out.run${run}.screen 2>> ipi.out.run${run}.err &
    pid_ipi=$!

    # Updating variables
    pids[${sim_counter}]=$pid_ipi
    echo "${pid_ipi} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/md
    sim_counter=$((sim_counter+1))
    cd ..
fi

# Running CP2K
if [[ "${md_programs}" == *"cp2k"* ]]; then

    # Variables
    ncpus_cp2k_md="$(grep -m 1 "^ncpus_cp2k_md_${subsystem}=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    max_it=60
    iteration_no=0

    # Loop for waiting until the socket file exists
    while true; do
        if [ -e /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.cp2k.${md_name//md.} ]; then
            for bead_folder in $(ls -v cp2k/); do

                # Preparing files and folder
                cd cp2k/${bead_folder}
                if [ ${md_continue^^} == "FALSE" ]; then
                    rm cp2k.out* > /dev/null 2>&1 || true
                fi
                rm cp2k.out.run${run}* > /dev/null 2>&1 || true
                rm system* > /dev/null 2>&1 || true
                sed -i "s|HOST.*cp2k.*|HOST ${runtimeletter}.${HQF_STARTDATE}.md.cp2k.${md_name//md.}|g" cp2k.in.main

                # Starting CP2k
                echo " * Starting cp2k (${bead_folder})"
                ${cp2k_command} -e cp2k.in.main > cp2k.out.run${run}.config 2>cp2k.out.run${run}.err
                OMP_NUM_THREADS=${ncpus_cp2k_md} ${cp2k_command} -i cp2k.in.main -o cp2k.out.run${run}.general > cp2k.out.run${run}.screen 2>cp2k.out.run${run}.err &
                pid=$!

                # Updating variables
                pids[${sim_counter}]=$pid
                echo "${pid} " >> ../../../../../../runtime/pids/${system_name}_${subsystem}/md
                sim_counter=$((sim_counter+1))
                cd ../../
                i=$((i+1))
                sleep 1
            done
            break
        else
            if [ "$iteration_no" -lt "$max_it" ]; then
                echo " * The socket file for MD simulation ${system_name} ${system_name} does not yet exist. Waiting 1 second (iteration $iteration_no)..."
                sleep 1
                iteration_no=$((iteration_no+1))
            else
                echo " * The socket file for MD simulation ${system_name} ${system_name} does not yet exist."
                echo " * The maxium number of iterations ($max_it) MD simulation ${system_name} ${system_name} has been reached."
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
    sed -i "s|<address>.*iqi.*|<address> ${runtimeletter}.${HQF_STARTDATE}.md.iqi.${md_name//md.} </address>|g" iqi.in.main.xml

    # Starting i-QI
    echo " * Starting iqi"
    stdbuf -oL iqi iqi.in.main.xml > iqi.out.run${run}.screen 2> iqi.out.run${run}.err &
    pid=$!

    # Updating variables
    pids[${sim_counter}]=$pid
    echo "${pid} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/md
    sim_counter=$((sim_counter+1))
    cd ../
fi

# Running NAMD
if [[ "${md_programs}" == "namd" ]]; then
    cd namd
    # ncpus_namd_md="$(grep -m 1 "^ncpus_namd_md=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    namd_command="$(grep -m 1 "^namd_command=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    ${namd_command} namd.in.md > namd.out.run${run}.screen 2>namd.out.run${run}.err & # removed +idlepoll +p${ncpus_namd_md}
    pid=$!
    pids[${sim_counter}]=$pid
    echo "${pid} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/md
    sim_counter=$((sim_counter+1))
    cd ..
fi

# Checking the status of the simulation
stop_flag="false"
while true; do

    # Checking the condition of the output files
    if [ -f ipi/ipi.out.run${run}.screen ]; then
        timeDiff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.run${run}.screen)))
        if [ "${timeDiff}" -ge "${md_timeout}" ]; then
            echo " * i-PI seems to have completed the MD simulation."
            break
        fi
    fi
    if [ -f ipi/ipi.out.run${run}.err ]; then
        error_count="$( { grep -i error ipi/ipi.out.run${run}.err  || true; } | wc -l)"
        if [ ${error_count} -ge "1" ]; then
            echo -e "Error detected in the ipi output files"
            echo "Exiting..."
            exit 1
        fi
    fi
    # Checking the condition of the output files of cp2k
    for bead_folder in $(ls -v cp2k/); do
        # Checking if memory error - happens often at the end of runs it seems, thus we treat it as a successful run
        if [ -f cp2k/${bead_folder}/cp2k.out.run${run}.err ]; then
            pseudo_error_count="$( { grep -E "invalid memory reference | corrupted | Caught" cp2k/${bead_folder}/cp2k.out.run${run}.err || true; } | wc -l)"
            if [ "${pseudo_error_count}" -ge "1" ]; then
                echo " * The MD simulation seems to have completed."
                break 2
            fi
        fi
        if [ -f cp2k/${bead_folder}/cp2k.out.run${run}.err ]; then
            error_count="$( { grep -i error cp2k/${bead_folder}/cp2k.out.run${run}.err || true; } | wc -l)"
            if [ ${error_count} -ge "1" ]; then
                set +o pipefail
                backtrace_length="$(grep -A 100 Backtrace cp2k/${bead_folder}/cp2k.out.run${run}.err | grep -v Backtrace | wc -l)"
                socket_error_count="$(grep -A 100 socket cp2k/${bead_folder}/cp2k.out.run${run}.err | wc -l)"
                set -o pipefail
                if [ "${backtrace_length}" -ge "1" ]; then
                    echo -e "Error detected in the file cp2k/${bead_folder}/cp2k.out.run${run}.err."
                    exit 1
                elif [ "${socket_error_count}" -ge "1" ]; then
                    echo -e "Error detected in the file cp2k/${bead_folder}/cp2k.out.run${run}.err related to the socket."
                    exit 1
                else
                    echo " * The MD simulation seems to have completed."
                    break 2
                fi
            fi
        fi
    done

    # Checking if ipi has terminated (hopefully wihtout error after the previous error checks)
    if [ ! -e /proc/${pid_ipi} ]; then

        # Checking the condition of the output files
        sleep 1 || true
        if [ -f ipi/ipi.out.run${run}.err ]; then
            error_count="$( { grep -i error ipi/ipi.out.run${run}.err || true; } | wc -l)"
            if [ ${error_count} -ge "1" ]; then
                echo -e "Error detected in the ipi output files"
                echo "Exiting..."
                exit 1
            fi
        else
            timeDiff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.run${run}.screen)))
            if [ "${timeDiff}" -ge "${md_timeout}" ]; then
                echo " * i-PI seems to have completed the MD simulation."
                break 2
            fi
        fi
    fi

    # Sleeping before next round
    sleep 1 || true   # true because the script might be terminated while sleeping, which would result in an error
done
