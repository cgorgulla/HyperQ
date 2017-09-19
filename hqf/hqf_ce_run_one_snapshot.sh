#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_md_run_one_md.sh

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
    echo "Reason: The wrong number of arguments were provided when calling the script."
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
trap 'error_response_std $LINENO' ERR

# Exit cleanup
cleanup_exit() {

    echo
    echo " * Cleaning up..."
    echo " * Removing socket files if still existent..."
    rm /tmp/ipi_ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.*.${crosseval_folder}.restart-${snapshotID} > /dev/null 2>&1 || true

    # Terminating all processes
    echo " * Terminating remaining processes..."
    # Terminating the child processes of the main processes
    for pid in "${pids[@]}"; do
        pkill -P "${pid}" 1>/dev/null 2>&1 || true
    done
    sleep 3
    for pid in "${pids[@]}"; do
        pkill -9 -P "${pid}"  1>/dev/null 2>&1 || true
    done
    # Terminating the main processes
    for pid in "${pids[@]}"; do
        kill "${pid}" 1>/dev/null 2>&1 || true
    done
    sleep 3
    for pid in "${pids[@]}"; do
        kill -9 "${pid}"  1>/dev/null 2>&1 || true
    done
    sleep 1
    # Terminating everything elese which is still running and which was started by this script
    pkill -P $$ || true
    sleep 3
    pkill -9 -P $$ || true
}
trap "cleanup_exit" EXIT

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
snapshot_name="$(pwd | awk -F '/' '{print $(NF)}')"
crosseval_folder="$(pwd | awk -F '/' '{print $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-2)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-3)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-2)}')"
snapshotID=${snapshot_name/*-}
ce_type="$(grep -m 1 "^md_type_${subsystem}=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
ce_timeout="$(grep -m 1 "^ce_timeout_${subsystem}=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
ce_continue="$(grep -m 1 "^ce_continue=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
snapshot_time_start=$(date +%s)
sim_counter=0

# Checking if the snapshot was computed already
if [ "${ce_continue^^}" == "TRUE" ]; then
    if [ -f ipi/ipi.out.properties ]; then
        propertylines_word_count=$(grep "^ *[0-9]" ipi/ipi.out.properties | wc -w )
        if [ "${propertylines_word_count}" -ge "3" ]; then
             echo " * The snapshot ${snapshotID} has been computed already, skipping."
             exit 0
        fi
    fi
fi

# Running ipi
if [[ "${md_programs^^}" == *"IPI"* ]]; then
    cd ipi
    echo -e " * Starting ipi"
    rm ipi.out.* > /dev/null 2>&1 || true
    rm *RESTART* > /dev/null 2>&1 || true
    msp_name="$(pwd | awk -F '/' '{print $(NF-4)}')"
    rm /tmp/ipi_ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.*.${crosseval_folder}.restart-${snapshotID} > /dev/null 2>&1 || true
    ipi ipi.in.ce.xml > ipi.out.screen 2> ipi.out.err &
    pid_ipi=$!
    #ps -o pid,pgid,ppid $pid_ipi
    echo "${pid_ipi} " >> ../../../../../../runtime/pids/${msp_name}_${subsystem}/ce
    pids[${sim_counter}]=${pid_ipi}
    sim_counter=$((sim_counter+1))
    cd ..
fi

# Running CP2K
if [[ "${md_programs^^}" == *"CP2K"* ]]; then
    ncpus_cp2k_ce="$(grep "^ncpus_cp2k_ce_${subsystem}=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    max_it=60
    iteration_no=0
    while true; do
        if [ -e "/tmp/ipi_ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.cp2k.${crosseval_folder}.restart-${snapshotID}" ]; then # -e for any fail, -f is only for regular files
            for bead_folder in $(ls cp2k/); do
                echo -e " * Starting CP2K in folder (${bead_folder})"
                cd cp2k/${bead_folder}/
                rm cp2k.out* > /dev/null 2>&1 || true
                rm system* > /dev/null 2>&1 || true
                ${cp2k_command} -e cp2k.in.ce > cp2k.out.config 2>cp2k.out.config.err
                export OMP_NUM_THREADS=${ncpus_cp2k_ce}
                # timeout -s SIGTERM ${ce_timeout} cp2k -i cp2k.in.md -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
                echo " * The socket file for snapshot ${snapshotID} has been detected. Starting CP2K..."
                ${cp2k_command} -i cp2k.in.ce -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
                pid=$!
                pids[${sim_counter}]=$pid
                echo "${pid} " >> ../../../../../../../runtime/pids/${msp_name}_${subsystem}/ce
                sim_counter=$((sim_counter+1))
                cd ../../
                sleep 1
            done
            break
        else
            if [ "$iteration_no" -lt "$max_it" ]; then
                echo " * The socket file for snapshot ${snapshotID} does not yet exist. Waiting 1 second (iteration $iteration_no)..."
                sleep 1
                iteration_no=$((iteration_no+1))
            else
                echo " * The socket file for snapshot ${snapshotID} does not yet exist."
                echo " * The maxium number of iterations ($max_it) for snapshot ${snapshotID} has been reached. Skipping this snapshot..."
                exit 1
            fi
        fi
    done
fi

# i-QI
if [[ "${md_programs^^}" == *"IQI"* ]]; then
    cd iqi
    echo -e " * Starting iqi"
    rm iqi.out.* > /dev/null 2>&1 || true 
    iqi iqi.in.xml > iqi.out.screen 2> iqi.out.err &
    pid=$!
    pids[${sim_counter}]=$pid
    echo "${pids[${sim_counter}]} " >> ../../../../../../runtime/pids/${msp_name}_${subsystem}/ce
    sim_counter=$((sim_counter+1))
    cd ../
fi

waiting_time_start=$(date +%s)
while true; do
    if [ -f ipi/ipi.out.properties ]; then
        propertylines_word_count="$(grep "^ *[0-9]" ipi/ipi.out.properties | wc -w)"
        if [ "${propertylines_word_count}" -ge "3" ]; then
             snapshot_time_total=$(($(date +%s) - ${snapshot_time_start}))
             echo " * Snapshot ${snapshotID} completed after ${snapshot_time_total} seconds."
             break
        fi
    fi
    waiting_time_diff=$(($(date +%s) - ${waiting_time_start}))
    if [ "${waiting_time_diff}" -ge "${ce_timeout}" ]; then
        echo " * CE-Timeout for snapshot ${snapshotID} reached. Skipping this snapshot..."
        false
    fi
    # Checking for cp2k errors
    for bead_folder in $(ls cp2k/); do
        # We are not interpreting pseudoerrors as successful runs, we rely only on the property file of ipi
        if [ -f cp2k/${bead_folder}/cp2k.out.err ]; then
            error_count="$( ( grep -i error cp2k/${bead_folder}/cp2k.out.err || true ) | wc -l)"
            if [ ${error_count} -ge "1" ]; then
                set +o pipefail
                backtrace_length="$(grep -A 100 Backtrace cp2k/${bead_folder}/cp2k.out.err | grep -v Backtrace | wc -l)"
                set -o pipefail
                if [ "${backtrace_length}" -ge "1" ]; then
                    echo -e "Error detected in the file cp2k/${bead_folder}/cp2k.out.err"
                    false
                fi
            fi
        fi
    done

    # Sleeping shortly before next round
    sleep 1 || true             # true because the script might be terminated while sleeoping, which would result in an error
done