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
}
trap 'error_response_std $LINENO' ERR

clean_exit() {
    # Terminating all child processes
    for pid in "${pids[@]}"; do
        kill "${pid}"  1>/dev/null 2>&1 || true
    done
    pkill -P $$ || true
    sleep 3
    for pid in "${pids[@]}"; do
        kill -9 "${pid}"  1>/dev/null 2>&1 || true
    done
    pkill -9 -P $$ || true
}
trap 'clean_exit' EXIT

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
fes_md_parallel_max="$(grep -m 1 "^fes_md_parallel_max" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"

# Running the md simulations
i=0
for folder in $(ls -d md*); do
    while [ "$(jobs | grep -v Done | wc -l)" -ge "${fes_md_parallel_max}" ]; do
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
    wait $pid
done

echo -e " * All simulations have been completed."
