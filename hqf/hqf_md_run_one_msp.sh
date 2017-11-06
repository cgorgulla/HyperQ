#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_md_run_one_msp.sh <md_index_range>

<md_index_range>: Possible values:
                      * all : Will cover all simulations of the MSP
                      * startindex:endindex : The index starts at 1 (w.r.t. to the MD folders present)

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
    echo "Number of expected arguments: 1"
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
trap 'error_response_std $LINENO' ERR SIGINT SIGTERM SIGQUIT

clean_exit() {

    echo
    echo " * Cleaning up..."

    # Terminating all processes
    echo " * Terminating remaining processes..."
    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Removing the socket files if still existent
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.* 1>/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 6
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent (again because sometimes a few are still left)
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.* 1>/dev/null 2>&1 || true

        # Terminating the main processes
        kill ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true


        # Removing the socket files if still existent (again because sometimes a few are still left)
        rm /tmp/ipi_${runtimeletter}.${HQF_STARTDATE}.md.* 1>/dev/null 2>&1 || true

        # Terminating everything else which is still running and which was started by this script, which will include the current exit-code
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true
    " &> /dev/null || true
}
trap 'clean_exit' EXIT

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n *** Starting the MD simulations (hqf_md_run_one_msp.sh)"

# Variables
md_index_range="${1}"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
fes_md_parallel_max="$(grep -m 1 "^fes_md_parallel_max_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
command_prefix_md_run_one_md="$(grep -m 1 "^command_prefix_md_run_one_md=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

# Getting the MD folders
if [ "${TD_cycle_type}" == "hq" ]; then
    md_folders="$(ls -vrd md*)"
elif [ "${TD_cycle_type}" == "lambda" ]; then
    md_folders="$(ls -vd md*)"
fi

# Setting the MD indices
if [ "${md_index_range}" == "all" ]; then
    md_index_first=1
    md_index_last=$(echo ${md_folders[@]} | wc -w)
else
    md_index_first=${md_index_range/:*}
    md_index_last=${md_index_range/*:}
    if ! [ "${md_index_first}" -eq "${md_index_first}" ]; then
        echo " * Error: The variable md_index_first is not set correctly. Exiting..."
        exit 1
    fi
    if ! [ "${md_index_last}" -eq "${md_index_last}" ]; then
        echo " * Error: The variable md_index_last is not set correctly. Exiting..."
        exit 1
    fi
fi

# Running the MDs
i=1
for folder in ${md_folders}; do

    # Checking if this MD simulation should be skipped
    if [[ "${i}" -lt "${md_index_first}" ]] ||  [[ "${i}" -gt "${md_index_last}" ]]; then
        echo -e " * Skipping the MD simulation ${folder} because the md_index is not in the specified range."
        i=$((i+1))
        continue
    fi

    while [ "$(jobs | { grep -v Done || true; } | wc -l)" -ge "${fes_md_parallel_max}" ]; do
        sleep 0.$RANDOM
    done;
    cd ${folder}/
    echo -e " * Starting the MD simulation ${folder}"
    ${command_prefix_md_run_one_md} hq_md_run_one_md.sh &
    pid=$!
    pids[i]=$pid
    echo "${pid} " >> ../../../../runtime/pids/${system_name}_${subsystem}/md
    cd ../
    i=$((i+1))
done

# Waiting for each process separately to capture all the exit codes
for pid in ${pids[@]}; do
    wait -n
done

echo -e " * All simulations have been completed."
