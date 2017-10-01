#!/usr/bin/env bash

# Usage infomation
usage="Usage: hqf_opt_run_one_msp.sh

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
    # Terminating everything else which is still running and which was started by this script
    pkill -P $$ || true
    sleep 3
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
echo -e "\n *** Running the geometry optimizations (hq_opt_run_one_opt.sh)"

# Variables
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
fes_opt_parallel_max="$(grep -m 1 "^fes_opt_parallel_max_${subsystem}" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"

# Running the geopts
i=0
for folder in $(ls -dv opt.* | tr -d "/"); do
    while [ "$(jobs | wc -l)" -ge "${fes_opt_parallel_max}" ]; do 
        sleep 1; 
    done;
    if [ "${opt_programs}" == "cp2k" ]; then
        cd ${folder}/cp2k
    fi
    echo -e " * Starting the optimization ${folder}"
    hqf_opt_run_one_opt.sh &
    pids[i]=$!
    echo "${pids[i]}" >> ../../../../../runtime/pids/${system_name}_${subsystem}/opt
    i=$((i+1))
    cd ../..
done

# Waiting for the processes
for pid in $pids; do        # just the number of arguments matters
    wait -n
done

echo -e " * All optimizations have been completed."
