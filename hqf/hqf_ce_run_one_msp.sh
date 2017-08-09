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
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    exit 1 
}
trap 'error_response_std $LINENO' ERR

clean_up() {
    for pid in "${pids[@]}"; do
        kill -9 "${pid}"  1>/dev/null 2>&1 || true
    done
    #kill -9 0  1>/dev/null 2>&1  || true
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
            echo -e " * Waiting for a free slot to star cross evaluation of snapshot ${snapshot_folder/*-} (hqf_ce_run_one_msp.sh)"
            sleep 1.$RANDOM
            echo
        done;
        sleep 0.$RANDOM
        cd ${snapshot_folder}/
        echo -e "\n * Running the cross evaluation of snaphot ${snapshot_folder/*-}"
        setsid hqf_ce_run_one_snapshot.sh ${ncpus_cp2k_md} &
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
