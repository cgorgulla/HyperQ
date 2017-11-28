#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_ce_run_one_snapshot.sh

Has to be run in the simulation main folder."

# Checking the arguments
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
    echo "Expected arguments: 0"
    echo "Provided arguments: ${#}"
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
}
trap 'error_response_std $LINENO' ERR SIGINT SIGQUIT SIGTERM

# Exit cleanup
cleanup_exit() {

    echo
    echo " * Cleaning up..."

    # Removing CP2K output files to reduce total number of files
    if [ "${ce_verbosity}" != "debug" ]; then
        for bead_folder in $(ls -v cp2k/); do
            rm ${bead_folder}/cp2k.out.* >/dev/null 2>&1 || true
        done
    fi

    # Terminating all remaining processes
    echo " * Terminating all remaining processes..."
    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Terminating the main processes
        kill ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 5
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.*.${crosseval_folder//tds.}.r-${snapshot_id} >/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent (again because sometimes a few are still left)
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.*.${crosseval_folder//tds.}.r-${snapshot_id} >/dev/null 2>&1 || true

        # Terminating everything else which is still running and which was started by this script, which will include the current exit-code
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true
    " &> /dev/null || true
}
trap "cleanup_exit" EXIT

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
snapshot_name="$(pwd | awk -F '/' '{print $(NF)}')"
crosseval_folder="$(pwd | awk -F '/' '{print $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-2)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-3)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-2)}')"
snapshot_id=${snapshot_name/*-}
ce_type="$(grep -m 1 "^md_type_${subsystem}=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_timeout="$(grep -m 1 "^ce_timeout_${subsystem}=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_continue="$(grep -m 1 "^ce_continue=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_verbosity="$(grep -m 1 "^ce_verbosity=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
snapshot_time_start=$(date +%s)
sim_counter=0

# Checking if the snapshot was computed already
if [ "${ce_continue^^}" == "TRUE" ]; then
    if [ -f ipi/ipi.out.properties ]; then
        propertylines_word_count=$(grep "^ *[0-9]" ipi/ipi.out.properties | wc -w )
        if [ "${propertylines_word_count}" -ge "3" ]; then
             echo " * The snapshot ${snapshot_id} has been computed already, skipping."
             exit 0
        fi
    fi
fi

# Running ipi
if [[ "${md_programs^^}" == *"IPI"* ]]; then

    # Preparing files and folder
    cd ipi
    echo -e " * Starting ipi"
    rm ipi.out.* > /dev/null 2>&1 || true
    rm *RESTART* > /dev/null 2>&1 || true

    # Removing the socket files if still existent from previous runs
    rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.*.${crosseval_folder//tds.}.r-${snapshot_id} >/dev/null 2>&1 || true

    # Updating the input file (directly here before the simulation due to the timestamp in the socket address)
    sed -i "s|<address>.*cp2k.*|<address>${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.cp2k.${crosseval_folder//tds.}.r-${snapshot_id}</address>|g" ipi.in.*
    sed -i "s|<address>.*iqi.*|<address>${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce..iqi.${crosseval_folder//tds.}.r-${snapshot_id}</address>|g" ipi.in.*

    # Starting ipi
    if [ "${ce_verbosity}" == "debug" ]; then
        stdbuf -oL ipi ipi.in.main.xml > ipi.out.screen 2> ipi.out.err &
        pid_ipi=$!
    else
        stdbuf -oL ipi ipi.in.main.xml > /dev/null
        pid_ipi=$!
    fi

    # Updating variables
    pids[${sim_counter}]=${pid_ipi}
    sim_counter=$((sim_counter+1))
    cd ..
fi

# Running CP2K
if [[ "${md_programs^^}" == *"CP2K"* ]]; then

    #Variables
    ncpus_cp2k_ce="$(grep "^ncpus_cp2k_ce_${subsystem}=" ../../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    export OMP_NUM_THREADS=${ncpus_cp2k_ce}
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../../input-files/config.txt | awk -F '[=#]' '{print $2}')"
    max_it=60
    iteration_no=0

    # Loop for waiting until the socket file exists
    while true; do
        if [ -e "/tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.cp2k.${crosseval_folder//tds.}.r-${snapshot_id}" ]; then # -e for any fail, -f is only for regular files
            echo " * The socket file for snapshot ${snapshot_id} has been detected. Starting CP2K..."

            # Loop for each bead
            for bead_folder in $(ls -v cp2k/); do

                # Preparing files and folder
                cd cp2k/${bead_folder}/
                rm cp2k.out* > /dev/null 2>&1 || true

                # Updating the input file (directly here before the simulation due to the timestamp in the socket address)
                sed -i "s|HOST.*cp2k.*|HOST ${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.cp2k.${crosseval_folder//tds.}.r-${snapshot_id}|g" cp2k.in.*
                sed -i "s|PRINT_LEVEL .*|PRINT_LEVEL silent|g" cp2k.in.*

                # Checking the input file
                if [ "${ce_verbosity}" == "debug" ]; then
                    ${cp2k_command} -e cp2k.in.main > cp2k.out.config 2>cp2k.out.config.err
                else
                    ${cp2k_command} -e cp2k.in.main >/dev/null
                fi

                # Starting cp2k
                echo " * Starting CP2K for ${bead_folder}..."
                if [ "${ce_verbosity}" == "debug" ]; then
                    ${cp2k_command} -i cp2k.in.main -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
                    pid=$!
                else
                    ${cp2k_command} -i cp2k.in.main -o cp2k.out.general > /dev/null &
                    pid=$!
                fi


                # Updating variables
                pids[${sim_counter}]=$pid
                sim_counter=$((sim_counter+1))
                cd ../../
                sleep 1
            done
            break
        else
            if [ "$iteration_no" -lt "$max_it" ]; then
                echo " * The socket file for the CE running in ${PWD} does not yet exist. Waiting 1 second (iteration $iteration_no)..."
                sleep 1
                iteration_no=$((iteration_no+1))
            else
                echo " * The socket file for snapshot ${snapshot_id} does not yet exist."
                echo " * The maximum number of iterations ($max_it) for snapshot ${snapshot_id} has been reached. Skipping this snapshot..."
                exit 1
            fi
        fi
    done
fi

# i-QI
if [[ "${md_programs^^}" == *"IQI"* ]]; then

    # Preparing files and folder
    cd iqi

    # Updating the input file (directly here before the simulation due to the timestamp in the socket address)
    sed -i "s|<address>.*iqi.*|<address>${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.iqi.${crosseval_folder//tds.}.r-${snapshot_id}</address>|g" iqi.in.*

    # Starting iqi
    echo -e " * Starting iqi"
    rm iqi.out.* > /dev/null 2>&1 || true 
    if [ "${ce_verbosity}" == "debug" ]; then
        iqi iqi.in.main.xml > iqi.out.screen 2> iqi.out.err &
        pid=$!
    else
        iqi iqi.in.main.xml > /dev/null &
        pid=$!
    fi


    # Updating variables
    pids[${sim_counter}]=$pid
    sim_counter=$((sim_counter+1))
    cd ../
fi

# Checking the status of the simulation
waiting_time_start=$(date +%s)
while true; do

    # Checking verbosity status
    if [ "${HQ_VERBOSITY_RUNTIME}" == "debug" ]; then

        # Printing some information
        echo " * Checking if the computation running in folder ${PWD} has completed."
    fi

    # Checking the condition of the output files
    if [ -f ipi/ipi.out.properties ]; then

        # Variables
        propertylines_word_count="$(grep "^ *[0-9]" ipi/ipi.out.properties | wc -w)"

        # Checking the number of words
        if [ "${propertylines_word_count}" -ge "3" ]; then

             # Variables
             snapshot_time_total=$(($(date +%s) - ${snapshot_time_start}))

             # Printing some information
             echo " * Snapshot ${snapshot_id} completed after ${snapshot_time_total} seconds."
             break
        fi
    fi

    # Variables
    waiting_time_diff=$(($(date +%s) - ${waiting_time_start}))

    # Checking the time difference
    if [[ "${waiting_time_diff}" -ge "${ce_timeout}" ]] && [[ "${waiting_time_diff}" -le "$((ce_timeout+10))" ]]; then
        echo " * CE-Timeout for snapshot ${snapshot_id} reached. Skipping this snapshot..."
        exit 1

    elif [[ "${waiting_time_diff}" -ge "$((ce_timeout+10))" ]]; then

        # If the time diff is larger, then the workflow will most likely have been suspended and has now been resumed
        waiting_time_start=$(date +%s)
    fi
#    # Checking for cp2k errors
#    for bead_folder in $(ls -v cp2k/); do
#        # We are not interpreting pseudoerrors as successful runs, we rely only on the property file of ipi. But we would need to check for pseudo errors in order to be able to get the real errors
#        if [ -f cp2k/${bead_folder}/cp2k.out.err ]; then
#            error_count="$( { grep -i error cp2k/${bead_folder}/cp2k.out.err || true; } | wc -l)"
#            if [ ${error_count} -ge "1" ]; then
#                set +o pipefail
#                backtrace_length="$(grep -A 100 Backtrace cp2k/${bead_folder}/cp2k.out.err | grep -v Backtrace | wc -l)"
#                set -o pipefail
#                if [ "${backtrace_length}" -ge "1" ]; then
#                    echo -e "Error detected in the file cp2k/${bead_folder}/cp2k.out.err"
#                    exit 1
#                fi
#            fi
#        fi
#    done

    # Checking if ipi has terminated (most likely successfully after the previous error checks)
    if [ ! -e  /proc/${pid_ipi} ]; then

        # Printing some information
        echo " * i-PI seems to have terminated without error."
        break
    fi

    # Sleeping shortly before next round
    sleep 1 || true             # true because the script might be terminated while sleeoping, which would result in an error
done