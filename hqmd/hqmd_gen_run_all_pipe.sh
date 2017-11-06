#!/usr/bin/env bash

usage="Usage: hqmd_gen_run_all_pipe.sh <subsystem> <pipeline_type> <maximum parallel pipes>

The script has to be run in the root folder.\n\nThe pipeline can be composed of:
Elementy elements:
   _pro_: prepare the optimization
   _rop_: run the optimization
   _ppo_: postprocess the optimization
   _prm_: prepare md simulation
   _rmd_: run md simulation

Combined elements:
   _allopt_: equals _pro_rop_ppo_
   _allmd_ : equals _prd_rmd_
   _all_   : equals _allopt_allmd_ = _pro_rop_ppo_prd_rmd_"

#Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "3" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 3"
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
trap 'error_response_std $LINENO' ERR

# Exit cleanup
cleanup_exit() {
    kill 0  1>/dev/null 2>&1 || true # Stops the proccesses of the same process group as the calling process
    #kill $(pgrep -f $DAEMON | grep -v ^$$\$)
}
trap "cleanup_exit" EXIT

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
subsystem=${1}
pipeline_type=${2}
maximum_parallel_pipes=${3}

# Printing information
echo -e "\n ***** Running one pipeline (${pipeline_type}) for each in input-folder/systems where the subsystem is ${subsystem} *****"

# Loop for each system
for system in $(ls -v input-files/systems); do

    while [ "$(jobs | wc -l)" -ge "${maximum_parallel_pipes}" ]; do
        jobs
        sleep 1.$RANDOM
    done;
    hqmd_gen_run_one_pipe.sh "${system}" "${subsystem}" "${pipeline_type}" &
done