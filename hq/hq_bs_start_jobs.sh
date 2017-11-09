#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_start_jobs.sh <job-type-letter> <first job ID> <last job ID> <increase job serial number> <check for active jobs>

Starts the job files in batchsystem/job-files/main/jid-<jid>.<batchsystem>
The variable <batchsystem> is determined by the corresponding setting in the file input-files/config.txt

Arguments:
    <increase job serial number>: Possible values: true or false

    <job-type-letter>: The job-type-letter corresponding to the jobs to be started (a lower case letter)

    <check for active jobs>: Checks if jobs of the same WFID, JTL and JID are already in the batchsystem and skips them.
                             Possible values: true, false

Has to be run in the root folder."

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "5" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 5"
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
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
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
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print tolower($2)}')
workflow_id=$(grep -m 1 "^workflow_id=" input-files/config.txt | awk -F '=' '{print $2}')

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

# Storing all the jobs which are currently running
touch batchsystem/tmp/jobs-all
touch batchsystem/tmp/jobs-to-start
hqh_bs_sqs.sh > batchsystem/tmp/jobs-all 2>/dev/null || true

# Checking if we should check for already active jobs
if [ "${check_active_jobs^^}" == "TRUE" ]; then

    # Printing some information
    echo -e "\nChecking which jobs are already in the batchsystem"

    # Determining which jobs which have to be restarted
    for jid in $(seq ${first_jid} ${last_jid}); do
        if ! grep -q "${workflow_id}:${jtl}\.${jid}" batchsystem/tmp/jobs-all; then
            echo "Adding job ${jid} to the list of jobs to be started."
            echo ${jid} >> batchsystem/tmp/jobs-to-start
        else
            echo "Omitting the job ${jtl}.${jid} because it was found to be already in the batchsystem."
        fi
    done
elif [ "${check_active_jobs^^}" == "FALSE" ]; then

    # Loop for all JIDs
    for jid in $(seq ${first_jid} ${last_jid}); do
        echo ${jid} >> batchsystem/tmp/jobs-to-start
    done
else

    echo -e "\n * Error: The input argument 'check_active_jobs' has an unsupported value (${check_active_jobs}). Exiting...\n\n"
    exit 1
fi

# Updating and submitting the relevant jobs
k=0
if [ -f batchsystem/tmp/jobs-to-start ]; then
    for jid in $(cat batchsystem/tmp/jobs-to-start ); do

        # Preparing the new jobfile
        if [ "${increase_jsn^^}" == "TRUE" ]; then
            hqh_bs_jobfile_increase_jsn.sh ${jtl} ${jid}
        fi

        # Submitting the job
        echo "Starting job ${jid}"
        hqh_bs_submit.sh batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}

        # Increasing the counter
        k=$((k + 1))
    done
fi

# Removing the temporary files
if [ -f "batchsystem/tmp/jobs-all" ]; then
    rm batchsystem/tmp/jobs-all
fi
if [ -f "batchsystem/tmp/jobs-to-start" ]; then
    rm batchsystem/tmp/jobs-to-start
fi

# Displaying some information
if [[ ! "$*" = *"quiet"* ]]; then
    echo "Number of jobs which have been started: ${k}"
    echo
fi
