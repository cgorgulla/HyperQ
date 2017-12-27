#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_monitor_jobs.sh <WFIDs> <JTLs> <refresh_time>

Shows basic information about the batchsystem jobs of the specified workflows. Only works well with Slurm at the moment.

Arguments:
    <WFIDs>: Colon-separated list of WFIDs, e.g. A:B:C

    <JTL>: Colon-separated list of JTLs, e.g. a:b:c

    <refresh_time>: Time in seconds between updates of the information.

Can be run in any folder."

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
    rm ${temp_file_sqs} &>/dev/null || true
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

# Variables
wfids=${1}
jtls=${2//:/}
refresh_time=${3}
temp_file_sqs="/tmp/$USER/hq_bs_sqs.$(date +%Y%m%d%m%S-%N)"

# Creating required directories
mkdir -p /tmp/$USER/

# Body
while true; do
    hqh_bs_sqs.sh > ${temp_file_sqs}
    echo -e "\n\n                               *** Job information (JTLs: ${jtls//:/,}) ***"
    echo -n "   "
    printf "*%.0s" {0..82}
    echo -e "\n"
    printf " %20s %20s %20s %20s\n" "$(center_text WFID 20)" "$(center_text "Jobs in BS" 20)" "$(center_text "Jobs running" 20)" "$(center_text "Jobs duplicate" 20)" # Intentionally one whitespace at the beginning
    for wfid in ${wfids//:/ }; do

        # Variables Todo: Fix to work for all batchsystems
        job_count="$(cat ${temp_file_sqs} | grep "${wfid}:[${jtls}]" | grep -v "COMPL" | wc -l)"
        #job_count_completing="$(cat ${temp_file_sqs} | grep "${wfid}:[${jtls}]" | grep "COMPL" | wc -l)"
        running_jobs_count="$(cat ${temp_file_sqs} | grep "${wfid}:[${jtls}].*RUNNING" | wc -l)"
        duplicated_jobs_count="$(cat ${temp_file_sqs} | grep "${wfid}:[${jtls}]" | grep -v "COMPL" | awk -F '[:. ]+' '{print $5, $6}' | sort -k 2 -V | uniq -c | grep -v " 1 " | wc -l)"

        # Printing status information
        printf "%20s %20s %20s %20s\n" "$(center_text ${wfid} 20)" "$(center_text "${job_count}" 20)" "$(center_text "${running_jobs_count}" 20)" "$(center_text "${duplicated_jobs_count}" 20)"
    done

    # Sleeping
    sleep ${refresh_time}
done