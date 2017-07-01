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
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    exit 1 
}
trap 'error_response_std $LINENO' ERR

clean_up() {
    for pid in "${pids[@]}"; do
        kill "${pid}" 1>/dev/null 2>&1 || true
    done
}
trap 'clean_up' EXIT

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n *** Starting the md simulations (hqf_md_run_one_msp.sh)"

# Variables
ncpus_cp2k_md=${1}
fes_md_parallel_max="$(grep -m 1 "^fes_md_parallel_max" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

# Running the md simulations
i=0
for folder in $(ls -d md*); do
    while [ "$(jobs | wc -l)" -ge "${fes_md_parallel_max}" ]; do
        sleep 0.$RANDOM
    done; 
    cd ${folder}/
    echo -e " * Starting the md simulation ${folder}"
    setsid hq_md_run_one_md.sh &
    pids[i]=$!
    cd ../
    i=$((i+1))
done

wait

echo -e " * All simulations have been completed."
