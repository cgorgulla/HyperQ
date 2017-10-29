#!/usr/bin/env bash

# Usage infomation
usage="Usage: hq_gen_run_all_pipe.sh <subsystem> <pipeline_type> <maximum parallel pipes> [<sim_index_range>]

The script has to be run in the root folder.

The pipeline can be composed of:
  _pro_: prepare the optimization
  _rop_: run the optimization
  _ppo_: postprocess the optimization
  _prm_: prepare md simulation
  _rmd_: run md simulation
  _prc_: prepare the crossevaluation
  _rce_: run the crossevaluation
  _prf_: prepare the free energy calculation
  _rfe_: run the free energy calculation
  _ppf_: postprocess the free energy calculation

 Combined elements:
  _allopt_: equals _pro_rop_ppo_
  _allmd_ : equals _prd_rmd_
  _allce_ : equals _prc_rce_
  _allfec_: equals _prf_rfe_ppf_
  _all_   : equals _allopt_allmd_allce_allfec_ =  _pro_rop_ppo_prd_rmd_prc_rce_prf_rfe_ppf_

<sim_index_range>: Can be all (default if not set), or startiindex_endindex. The index starts at 1.
"

#Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [[ "$#" -ne "3" ]] && [[ "$#" -ne "4" ]]; then
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

user_abort() {

    echo "Info: User abort, cleaning up..."

    # Forwarding the signal to our child processess
    pkill -SIGINT -P $$ || true
    pkill -SIGTERM -P $$ || true
    pkill -SIGQUIT -P $$ || true

    # Giving the child processes enough time to exit gracefully
    sleep 10
    exit 1
}
trap 'user_abort' SIGINT SIGQUIT SIGTERM

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
    kill 0  1>/dev/null 2>&1 || true # Stops the proccesses of the same process group as the calling process
    #kill $(pgrep -f $DAEMON | grep -v ^$$\$)
}
trap "cleanup_exit" EXIT

# Bash options
set -o pipefail

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
subsystem=${1}
pipeline_type=${2}
maximum_parallel_pipes=${3}
if [ -z "${4}" ]; then
    sim_index_range="all"
else
    sim_index_range="${4}"
fi

# Printing information
echo -e "\n ***** Running one pipeline (${pipeline_type}) for each in input-folder/systems where the subsystem is ${subsystem} *****"

# Loop for each system
for msp in $(find input-files/mappings/ -type f -maxdepth 1 -name "*_*" | awk -F '/' '{print $3}'); do

    while [ "$(jobs | wc -l)" -ge "${maximum_parallel_pipes}" ]; do
        jobs
        sleep 1.$RANDOM
    done;
    hqf_gen_run_one_pipe.sh "${msp}" "${subsystem}" "${pipeline_type}" &
done