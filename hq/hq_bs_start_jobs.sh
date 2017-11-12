#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_start_jobs.sh <job-type-letter> <first job ID> <last job ID> <increase job serial number> <check for active jobs> <delay time>

Starts the job files in batchsystem/job-files/main/jtl-<jtl>.jid-<jid>.<batchsystem>
The variable <batchsystem> is determined by the corresponding setting in the file input-files/config.txt

Arguments:
    <increase job serial number>: Possible values: true or false

    <job-type-letter>: The job-type-letter corresponding to the jobs to be started (a lower case letter)

    <check for active jobs>: Checks if jobs of the same WFID, JTL and JID are already in the batchsystem and skips them.
                             Possible values: true, false

    <delay time>: Time in seconds between the submission of two consecutive jobs.

Has to be run in the root folder."

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "6" ]; then
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
trap 'error_response_nonstd $LINENO' ERR

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Checking the version of BASH, we need at least 4.3 (wait -n)
bash_version=${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}
if [ ${bash_version} -lt 43 ]; then
    # Printing some information
    echo
    echo "Error: BASH version seems to be too old. At least version 4.3 is required."
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

# Checking if the job type letter is valid
if ! [[ "${jtl}" =~ [abcdefghij] ]]; then
    echo -e "\n * Error: The input argument 'job type letter' has an unsupported value (${jtl}). Exiting...\n\n"
    exit 1
fi

# Removing old files if existent
if [ -f "batchsystem/tmp/jobs-to-start" ]; then
    rm batchsystem/tmp/jobs-to-start
fi
mkdir -p batchsystem/tmp

# Preparing files and folders
mkdir -p batchsystem/output-files
touch batchsystem/tmp/jobs-to-start


# Checking if we should check for already active jobs
jobs_started=0
jobs_omitted=0
if [ "${check_active_jobs^^}" == "TRUE" ]; then

    # Printing some information
    echo -e "\nChecking which jobs are already in the batchsystem"

    # Getting the active jobs
    touch batchsystem/tmp/jobs-all
    hqh_bs_sqs.sh > batchsystem/tmp/jobs-all 2>/dev/null || true

    # Determining which jobs which have to be restarted
    for jid in $(seq ${first_jid} ${last_jid}); do
        if ! grep -q "${workflow_id}:${jtl}\.${jid}" batchsystem/tmp/jobs-all; then

            # Printing some information
            echo "Adding job ${jid} to the list of jobs to be started."

            # Adding the JID
            echo ${jid} >> batchsystem/tmp/jobs-to-start

            # Increasing the counter
            jobs_started=$((jobs_started+1))
        else

            # Printing some information
            echo "Omitting the job ${jtl}.${jid} because it was found to be already in the batchsystem."

            # Increasing the counter
            jobs_omitted=$((jobs_omitted+1))
        fi
    done
elif [ "${check_active_jobs^^}" == "FALSE" ]; then

    # Loop for all JIDs
    for jid in $(seq ${first_jid} ${last_jid}); do

        # Printing some information
        echo "Adding job ${jid} to the list of jobs to be started."

        # Adding the JID
        echo ${jid} >> batchsystem/tmp/jobs-to-start

        # Increasing the counter
        jobs_started=$((jobs_started+1))
    done
else

    echo -e "\n * Error: The input argument 'check_active_jobs' has an unsupported value (${check_active_jobs}). Exiting...\n\n"
    exit 1
fi

# Setting file permissions
chmod u+x batchsystem/job-files/main/*
chmod u+x batchsystem/job-files/subjobs/*

# Updating and submitting the relevant jobs
if [ -f batchsystem/tmp/jobs-to-start ]; then
    for jid in $(cat batchsystem/tmp/jobs-to-start ); do

        # Preparing the new jobfile
        if [ "${increase_jsn^^}" == "TRUE" ]; then
            hqh_bs_jobfile_increase_jsn.sh ${jtl} ${jid}
        fi

        # Submitting the job
        echo -e "\n * Starting job ${jid}"
        hqh_bs_submit.sh batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}

        # Sleeping
        sleep ${delay_time}
    done
fi

# Removing the temporary files
if [ -f "batchsystem/tmp/jobs-all" ]; then
    rm batchsystem/tmp/jobs-all || true
fi
if [ -f "batchsystem/tmp/jobs-to-start" ]; then
    rm batchsystem/tmp/jobs-to-start
fi

# Displaying some information
echo -e " * The submission of the jobs has been completed"
echo -e " * Total number of jobs which have specified: $((last_jid-first_jid+1))"
echo -e " * Number of jobs which have been started: ${jobs_started}"
echo -e " * Number of jobs which have been omitted: ${jobs_omitted}"
echo
