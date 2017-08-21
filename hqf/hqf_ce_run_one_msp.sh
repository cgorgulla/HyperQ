#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_ce_run_one_msp.sh

Has to be run in the simulation main folder."

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
    echo "The error occured on lin $1" 1>&2
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

clean_up() {
    # Terminating all child processes
    for pid in "${pids[@]}"; do
        kill "${pid}"  1>/dev/null 2>&1 || true
    done
    pkill -P $$ || true                     # https://stackoverflow.com/questions/2618403/how-to-kill-all-subprocesses-of-shell
}
trap 'clean_up' EXIT

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n *** Starting the cross evalutations (hqf_ce_run_one_msp.sh) ***"

# Variables
ncpus_cp2k_md="${1}"
fes_ce_parallel_max="$(grep -m 1 "^fes_ce_parallel_max" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"

# Running the md simulations
i=0
for TDwindow_folder in $(ls -d */); do
    TDwindow_folder=${TDwindow_folder/\/}
    cd ${TDwindow_folder}
    echo -e "\n ** Running the cross evaluations of folder ${TDwindow_folder}"
    for snapshot_folder in snapshot*; do
        while [ "$(jobs | wc -l)" -ge "${fes_ce_parallel_max}" ]; do
            echo -e " * Waiting for a free slot to start cross evaluation of snapshot ${snapshot_folder/*-} (hqf_ce_run_one_msp.sh)"
            sleep 1.$RANDOM
            echo
        done;
        sleep 0.$RANDOM
        cd ${snapshot_folder}/
        echo -e "\n * Running the cross evaluation of snaphot ${snapshot_folder/*-}"
        bash hqf_ce_run_one_snapshot.sh ${ncpus_cp2k_md} || true &
        pid=$!
        pids[i]=$pid
        echo "${pid} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/ce
        i=$((i+1))
        cd ..
    done
    cd ../
done

wait

echo -e " * All cross evaluations have been completed"
