#!/usr/bin/env bash

# Usage infomation
usage="Usage: hqf_opt_run_one_msp.sh <opt_index_range>

<opt_index_range>: Possible values:
                      * all : Will cover all simulations of the MSP
                      * startindex:endindex : The index starts at 1

Has to be run in the simulation main folder."

if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "1" ]; then
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
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
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
        sleep 6 || true
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1 || true
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

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
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
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

# Printing some information
echo -e "\n *** Running the geometry optimizations ${1}(hq_opt_run_one_msp.sh)"

# Variables
opt_index_range="${1}"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
fes_opt_parallel_max="$(grep -m 1 "^fes_opt_parallel_max_${subsystem}" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
command_prefix_opt_run_one_opt="$(grep -m 1 "^command_prefix_opt_run_one_opt=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"

# Getting the MD folders
if [ "${TD_cycle_type}" == "hq" ]; then
    opt_folders="$(ls -vrd opt.*)"
elif [ "${TD_cycle_type}" == "lambda" ]; then
    opt_folders="$(ls -vd opt.*)"
fi

# Setting the md indeces
if [ "${opt_index_range}" == "all" ]; then
    opt_index_first=1
    opt_index_last=$(echo ${opt_folders[@]} | wc -w)
else
    opt_index_first=${opt_index_range/:*}
    opt_index_last=${opt_index_range/*:}
    if ! [ "${opt_index_first}" -eq "${opt_index_first}" ]; then
        echo " * Error: The variable md_index_first is not set correctly. Exiting..."
        exit 1
    fi
    if ! [ "${opt_index_last}" -eq "${opt_index_last}" ]; then
        echo " * Error: The variable md_index_last is not set correctly. Exiting..."
        exit 1
    fi
fi

# Running the geopts
i=1
for folder in ${opt_folders}; do

    # Checking if this opt should be skipped
    if [[ "${i}" -lt "${opt_index_first}" ]] ||  [[ "${i}" -gt "${opt_index_last}" ]]; then
        echo -e " * Skipping the md simulation ${folder} because the md_index is not in the accepted range."
        i=$((i+1))
        continue
    fi

    while [ "$(jobs | wc -l)" -ge "${fes_opt_parallel_max}" ]; do 
        sleep 1; 
    done;
    if [ "${opt_programs}" == "cp2k" ]; then
        cd ${folder}/cp2k
    fi
    echo -e " * Starting the optimization ${folder}"
    ${command_prefix_opt_run_one_opt} hqf_opt_run_one_opt.sh &
    pids[i]=$!
    echo "${pids[i]}" >> ../../../../../runtime/pids/${system_name}_${subsystem}/opt
    i=$((i+1))
    cd ../..
done

# Waiting for the processes
for pid in ${pids[@]}; do        # just the number of arguments matters
    wait -n
done

echo -e " * All optimizations have been completed."
