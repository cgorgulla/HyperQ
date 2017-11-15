#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_start_jobs.sh <job-type-letter> <first job ID> <last job ID> <increase job serial number> <check for active jobs> <delay time>

Starts the job files in batchsystem/job-files/main/jtl-<jtl>.jid-<jid>.<batchsystem>
The variable <batchsystem> is determined by the corresponding setting in the file input-files/config.txt

Arguments:
    <increase job serial number>: Possible values: true or false

    <job-type-letter>: The job-type-letter corresponding to the jobs to be started (a lower case letter)

    <check for active jobs>: Checks if jobs of the same WFID and JID and the specified JTLs are already in the batchsystem and skips them.
                             Possible values: false, true:JTLs (e.g. true:abc)

    <delay time>: Time in seconds between the submission of two consecutive jobs.

Has to be run in the root folder."

# Checking the input parameters
if [ "${1}" == "-h" ]; then

    # Printing some information
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "6" ]; then

    # Printing some information
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 6"
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

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Cleanup function before exiting
cleanup_exit() {

    # Removing the temp-folder
    rm -r ${temp_folder} &>/dev/null || true
}
trap 'cleanup_exit' EXIT

# Bash options
set -o pipefail

# Verbosity
verbosity_preparation="$(grep -m 1 "^verbosity_preparation=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
if [ "${verbosity_preparation}" = "debug" ]; then
    set -x
fi

# Checking the version of BASH, we need at least 4.3 (wait -n)
bash_version=${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}
if [ ${bash_version} -lt 43 ]; then
    # Printing some information
    echo
    echo "Error: The Bash version seems to be too old. At least version 4.3 is required."
    echo "Exiting..."
    echo
    echo
    exit 1
fi

# Variables
jtl=${1}
first_jid=${2}
last_jid=${3}
increase_jsn=${4}
check_active_jobs=${5}
delay_time=${6}
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print tolower($2)}')
workflow_id=$(grep -m 1 "^workflow_id=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')
time_nanoseconds="$(date +%Y%m%d%m%S-%N)"
temp_folder=/tmp/${USER}/hq_bs_start_jobs/${time_nanoseconds}

# Checking if the job type letter is valid
if ! [[ "${jtl}" =~ [abcdefghij] ]]; then

    # Printing some information
    echo -e "\n * Error: The input argument 'job type letter' has an unsupported value (${jtl}). Exiting...\n\n"
    exit 1
fi

# Printing some information
echo -e "\n\n *********************************************************    Starting the jobs    *********************************************************\n\n"

# Preparing files and folders
mkdir -p batchsystem/output-files
mkdir -p ${temp_folder}
touch ${temp_folder}/jobs-all
touch ${temp_folder}/jobs-to-start


# Printing some information
echo -e "\n\nChecking which jobs should be started...\n"

# Checking if we should check for already active jobs
jobs_started=0
jobs_omitted=0
if [[ "${check_active_jobs^^}" == *"TRUE"* ]]; then

    # Variables
    jtls_to_check=${check_active_jobs/*:}

    # Printing some information
    echo -e " *** Checking which jobs are already in the batchsystem\n"

    # Checking if there are jtls specified
    if [ -z "${jtls_to_check}" ]; then

        # Printing some information
        echo -e "\n * Error: The input argument 'job type letter' has an unsupported value (${jtl}). Exiting...\n\n"
        exit 1
    fi

    # Getting the active jobs
    hqh_bs_sqs.sh > ${temp_folder}/jobs-all 2>/dev/null || true

    # Determining which jobs which have to be restarted
    for jid in $(seq ${first_jid} ${last_jid}); do
        if ! grep -q "${workflow_id}:[${jtls_to_check}]\.${jid}\." ${temp_folder}/jobs-all; then

            # Printing some information
            echo "   * Adding job ${jid} to the list of jobs to be started."

            # Adding the JID
            echo ${jid} >> ${temp_folder}/jobs-to-start

            # Increasing the counter
            jobs_started=$((jobs_started+1))
        else

            # Printing some information
            echo "   * Omitting the job ${jtl}.${jid} because it was found to be already in the batchsystem."

            # Increasing the counter
            jobs_omitted=$((jobs_omitted+1))
        fi
    done
elif [ "${check_active_jobs^^}" == "FALSE" ]; then

    # Loop for all JIDs
    for jid in $(seq ${first_jid} ${last_jid}); do

        # Printing some information
        echo " * Adding job ${jid} to the list of jobs to be started."

        # Adding the JID
        echo ${jid} >> ${temp_folder}/jobs-to-start

        # Increasing the counter
        jobs_started=$((jobs_started+1))
    done
else

    # Printing some information before exiting
    echo -e "\n * Error: The input argument 'check_active_jobs' has an unsupported value (${check_active_jobs}). Exiting...\n\n"
    exit 1
fi

# Setting file permissions
chmod u+x batchsystem/job-files/main/*
chmod u+x batchsystem/job-files/subjobs/*

# Updating and submitting the relevant jobs
if [ -f ${temp_folder}/jobs-to-start ]; then
    for jid in $(cat ${temp_folder}/jobs-to-start ); do

        # Preparing the new jobfile
        if [ "${increase_jsn^^}" == "TRUE" ]; then
            hqh_bs_jobfile_increase_jsn.sh ${jtl} ${jid}
        else
            # Formatting screen output
            echo
        fi

        # Submitting the job
        echo -e " * Starting job ${jid}"
        hqh_bs_submit.sh batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}

        # Sleeping
        sleep ${delay_time}
    done
fi

# Removing the temporary files
if [ -f "${temp_folder}/jobs-all" ]; then
    rm ${temp_folder}/jobs-all || true
fi
if [ -f "${temp_folder}/jobs-to-start" ]; then
    rm ${temp_folder}/jobs-to-start
fi

# Displaying some information
echo -e "\n * The starting of the jobs has been completed"
echo -e "   * Number of jobs processed: $((last_jid-first_jid+1))"
echo -e "   * Number of jobs started: ${jobs_started}"
echo -e "   * Number of jobs omitted: ${jobs_omitted}\n\n"
