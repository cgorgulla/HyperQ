#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_monitor_jobs.sh <WFIDs> <JTL> <refresh_time>

Shows basic information about the batchsystem jobs of the specified workflows.

Arguments:
    <WFIDs>: Colon-separated list of WFIDs, e.g. A:B:C

    <JTL>: Colon-separated list of JTLs, e.g. a:b:c

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
if [ "$#" -ne "3" ]; then

    # Printing some information
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
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

center_text(){

    # Variables
    text_to_center="$1"
    length_total="$2"

    # Centering the text
    text_centered="$(printf "%*s" $(( (${#text_to_center}+length_total) / 2)) "$text_to_center")"

    # Returning the centered text
    echo -n "${text_centered}"
}

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
jtls=${2//:/}
refresh_time=${3}

# Body
while true; do
    echo; printf "*%.0s" {0..80}
    echo; hqh_bs_sqs.sh > /tmp/cgorgulla.sqs
    print "                                    *** Job information for JTLs ${jtls//:/,} ***
    printf "%20s %20s %20s %20s\n" "$(center_text WFID 20)" "$(center_text "Jobs in batchsystem" 20)" "$(center_text "Jobs running" 20)" "$(center_text "Jobs duplicate" 20)"
    for wfid in ${wfids//:/ }; do

        # Variables
        job_count="$(cat /tmp/cgorgulla.sqs | grep "${wfid}:[${jtls}]" | wc -l)"
        running_jobs_count="$(cat /tmp/cgorgulla.sqs | grep "${wfid}:.*RUNNING" | wc -l)" # Todo: Fix to work for all batchsystems
        duplicated_jobs_count="$(cat /tmp/cgorgulla.sqs | grep "${wfid}:" | awk -F '[:. ]+' '{print $5, $6}' | sort -k 2 -V | uniq -c | grep -v " 1 " | wc -l)"

        # Printing status information
        printf "%20s %20s %20s %20s\n" "$(center_text ${wfid} 20)" "$(center_text "${job_count}" 20)" "$(center_text "${running_jobs_count}" 20)" "$(center_text "${duplicated_jobs_count}" 20)"
    done

    # Sleeping
    sleep ${refresh_time}
done