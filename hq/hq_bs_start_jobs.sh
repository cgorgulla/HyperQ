#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_start_jobs.sh <first job ID> <last job ID> <increase job serial number>

Starts the job files in batchsystem/job-files/main/jid-<jid>.<batchsystem>
<batchsystem> : Is determined by the corresponding setting in the file input-files/config.txt.
<increase job serial number> : Possible values: true or false

Has to be run in the root folder."

# Checking the input parameters
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

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
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

# Variables
first_jid=${1}
last_jid=${2}
increase_jsn=${3}
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print tolower($2)}')
runtimeletter=$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')

# Formatting screen output
echo "" 

# Removing old files if existent
if [ -f "batchsystem/tmp/jobs-to-start" ]; then
    rm batchsystem/tmp/jobs-to-start
fi
mkdir -p batchsystem/tmp

# Storing all the jobs which are currently running
touch batchsystem/tmp/jobs-all
touch batchsystem/tmp/jobs-to-start
hqh_bs_sqs.sh > batchsystem/tmp/jobs-all 2>/dev/null || true

# Storing all jobs which have to be restarted
echo "Checking which jobs are already in the batchsystem"
for jid in $(seq ${first_jid} ${last_jid}); do
    if ! grep -q "${runtimeletter}\-${jid}" batchsystem/tmp/jobs-all; then
        echo "Adding job ${jid} to the list of jobs to be started."
        echo ${jid} >> batchsystem/tmp/jobs-to-start
    else
        echo "Omitting job ${jid} because it was found in the batchsystem."
    fi
done

# Updating and submitting the relevant jobss
k=0
if [ -f batchsystem/tmp/jobs-to-start ]; then
    for jid in $(cat batchsystem/tmp/jobs-to-start ); do

        # Preparing the new jobfile
        if [ "${increase_jsn^^}" == "TRUE" ]; then
            hqh_bs_jobfile_increase_jsn.sh ${jid}
        fi

        # Submitting the job
        echo "Starting job ${jid}"
        hqh_bs_submit.sh batchsystem/job-files/main/${jid}.${batchsystem}

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
