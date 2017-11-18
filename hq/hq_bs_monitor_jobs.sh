#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_monitor_jobs.sh <WFIDs> <refresh_time>

Shows basic information about the batchsystem jobs of the specified workflows.

Arguments:
    <WFIDs>: Colon-separated list of WFIDs, e.g. A:B:C

    <refresh_time>: Time in seconds between updates of the information."

# Checking the input parameters
if [ "${1}" == "-h" ]; then

    # Printing some information
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "2" ]; then

    # Printing some information
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 2"
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
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Cleanup function before exiting
cleanup_exit() {

    # Removing the temp-folder
    rm -r  /tmp/cgorgulla.sqs &>/dev/null || true
}
trap 'cleanup_exit' EXIT

# Bash options
shopt -s nullglob

# Verbosity
# Checking if standalone mode (-> non-runtime)
#if [[ -z "${HQ_VERBOSITY_RUNTIME}" && -z "${HQ_VERBOSITY_NONRUNTIME}" ]]; then
#
#    # Variables
#    export HQ_VERBOSITY_NONRUNTIME="$(grep -m 1 "^verbosity_nonruntime=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
#
#    # Checking the value
#    if [ "${HQ_VERBOSITY_NONRUNTIME}" = "debug" ]; then
#        set -x
#    fi
#
## It seems the script was called by another script (non-standalone mode)
#else
#    if [[ "${HQ_VERBOSITY_RUNTIME}" == "debug" || "${HQ_VERBOSITY_NONRUNTIME}" == "debug" ]]; then
#        set -x
#    fi
#fi

# Variables
wfids=${1}
update_time=${2}

# Body
while true; do
    echo; printf "*%.0s" {0..80}
    echo; sqs > /tmp/cgorgulla.sqs
    printf "%8s %20s %20s %20s\n" "  WFID  " "Jobs in batchsystem " "Jobs running    " "Jobs duplicate    "
    for letter in ${wfids//:/ }; do
        job_count="$(cat /tmp/cgorgulla.sqs | grep "${letter}:" | wc -l)"
        running_jobs_count="$(cat /tmp/cgorgulla.sqs | grep "${letter}:.*RUNNING" | wc -l)"
        duplicated_jobs_count="$(cat /tmp/cgorgulla.sqs | grep "${letter}:" | awk -F '[:. ]+' '{print $5, $6}' | sort -k 2 -V | uniq -c | grep -v " 1 " | wc -l)"
        printf "%10s %20s %20s %20s\n" "${letter}   " "${job_count}          " "${running_jobs_count}         " "${duplicated_jobs_count}         "
    done
    sleep ${update_time}
done