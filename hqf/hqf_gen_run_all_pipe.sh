#!/usr/bin/env bash

# Usage information
usage="Usage: hq_gen_run_all_pipe.sh <MSP list file> <subsystem> <pipeline_type> <maximum parallel pipes> [<tds_range>]

Arguments:

    <MSP list file>: Text file containing a list of molecular system pairs (MSP), one pair per line, in form of system1_system2.
                     For each MSP in the file <MSP list file> a task defined by <command> will be created.

    <subsystem>: Possible values: L, LS, RLS

    The pipeline can be composed of:
     Elementary components:
      _pro_: preparing the optimizations
      _rop_: running the optimizations
      _ppo_: postprocessing the optimizations
      _pre_: preparing the equilibrations
      _req_: running the equilibrations
      _ppe_: postprocessing the equilibrations
      _prm_: preparing MD simulation
      _rmd_: postprocessing MD simulation
      _prc_: preparing the crossevaluation
      _rce_: postprocessing the crossevaluation
      _prf_: preparing the free energy calculation
      _rfe_: postprocessing the free energy calculation
      _ppf_: postprocessing the free energy calculation

     Macro components:
      _allopt_: equals _pro_rop_ppo_
      _alleq_: equals _pre_req_ppe_
      _allmd_ : equals _prd_rmd_
      _allce_ : equals _prc_rce_
      _allfec_: equals _prf_rfe_ppf_
      _all_   : equals _allopt_alleq_allmd_allce_allfec_

    <tds_range>:
      * Format: startindex:endindex
      * The index starts at 1
      * The capital letter K can be used to indicate the end state of the thermodynamic path
      * Currently only relevant for opt, eq, md
      * If unset, 1:K will be used for the commands which need a range argument

The script has to be run in the root folder."

#Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [[ "$#" -ne "4" ]] && [[ "$#" -ne "5" ]]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 4-5"
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
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE_BS}/error.pipeline
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
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
msp_list_filename=${1}
subsystem=${2}
pipeline_type=${3}
maximum_parallel_pipes=${4}

# TDS Range
if [ "${#}" == "5" ]; then
    tds_range="${5}"
else
    tds_range=1:K
fi

# Printing information
echo -e "\n ***** Running one pipeline (${pipeline_type}) for each in input-folder/systems where the subsystem is ${subsystem} *****"

# Loop for each msp
while IFS='' read -r msp; do

    # Parallelizing the jobs
    while [ "$(jobs | wc -l)" -ge "${maximum_parallel_pipes}" ]; do
        jobs
        sleep 1.$RANDOM
    done;

    # Running the individual pipe
    hqf_gen_run_one_pipe.sh "${msp}" "${subsystem}" "${pipeline_type}" &

done < ${msp_list_filename}

# Waiting for the jobs to finish
wait