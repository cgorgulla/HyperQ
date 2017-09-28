#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_md_run_one_msp.sh

Has to be run in the simulation main folder."

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

# Checking the version of BASH, we need at least 4.3 (wait -n)
bash_version=${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}
if [ ${bash_version} -lt 43 ]; then
    # Printing some information
    echo
    echo "Error: BASH version seems to be too old. At least version 4.3 is required."
    echo "Exiting..."
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

clean_exit() {

    echo
    echo " * Cleaning up..."

    # Terminating all processes
    echo " * Terminating remaining processes..."
    # Runniing the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid bash -c "

        # Removing the socket files if still existent
        echo " * Removing socket files if still existent..."
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.* 1>/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[@]} 1>/dev/null 2>&1 || true
        sleep 6
        pkill -9 -P ${pids[@]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent (again because sometimes a few are still left)
        echo " * Removing socket files if still existent..."
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.* 1>/dev/null 2>&1 || true

        # Terminating the main processes
        kill ${pids[@]} 1>/dev/null 2>&1 || true
        sleep 1
        kill -9 ${pids[@]} 1>/dev/null 2>&1 || true


        # Removing the socket files if still existent (again because sometimes a few are still left)
        echo " * Removing socket files if still existent..."
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.* 1>/dev/null 2>&1 || true

        # Terminating everything else which is still running and which was started by this script
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true

        # Removing the socket files if still existent (again because sometimes a few are still left)
        echo " * Removing socket files if still existent..."
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.* 1>/dev/null 2>&1 || true
    "
}
trap 'clean_exit' SIGINT SIGTERM SIGQUIT EXIT

# Bash options
set -o pipefail

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n *** Starting the md simulations (hqf_md_run_one_msp.sh)"

# Variables
ncpus_cp2k_md="${1}"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
fes_md_parallel_max="$(grep -m 1 "^fes_md_parallel_max_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

# Getting the MD folders
if [ "${TD_cycle_type}" == "hq" ]; then
    md_folders="$(ls -vrd md*)"
elif [ "${TD_cycle_type}" == "lambda" ]; then
    md_folders="$(ls -vd md*)"
fi

# Running the MDs
i=0
for folder in ${md_folders}; do
    while [ "$(jobs | { grep -v Done || true; } | wc -l)" -ge "${fes_md_parallel_max}" ]; do
        sleep 0.$RANDOM
    done;
    cd ${folder}/
    echo -e " * Starting the md simulation ${folder}"
    hq_md_run_one_md.sh &
    pid=$!
    pids[i]=$pid
    echo "${pid} " >> ../../../../runtime/pids/${system_name}_${subsystem}/md
    cd ../
    i=$((i+1))
done

# Waiting for each process separately to capture all the exit codes
for pid in $pids; do
    wait -n
done

echo -e " * All simulations have been completed."
