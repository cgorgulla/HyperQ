#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_start_jobs.sh <first task_no> <last task_no>

Has to be run in the root folder.
Use the job file batchsystem/job-files/<task-id>.<batchsystem> where <batchsystem> is determined by the configuratino file input-files/config.txt."

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
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Standard error response 
error_response_std() {
    # Printing some information
    echo
    echo "An error was trapped" 1>&2
    echo "The error occured in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occured on lin $1" 1>&2
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

# Variables
first_job_no=${1}
last_job_no=${2}
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print $2}')
line=$(grep -m 1 "^runtimeletter" input-files/config.txt | awk -F '=' '{print $2}')
runtimeletter=${line/"runtimeletter="}

# Formatting screen output
echo "" 

# Removing old files if existens
if [ -f "batchsystem/tmp/tasks-to-start" ]; then
    rm batchsystem/tmp/tasks-to-start
fi
mkdir -p batchsystem/tmp

# Storing all the jobs which are currently running
touch batchsystem/tmp/jobs-all
touch batchsystem/tmp/tasks-to-start
hqh_bs_sqs.sh > batchsystem/tmp/jobs-all 2>/dev/null || true

# Storing all tasks which have to be restarted
echo "Checking which tasks are already in the batchsystem"
for job_no in $(seq ${first_job_no} ${last_job_no}); do
    if ! grep -q "${runtimeletter}\-${job_no}"  batchsystem/tmp/jobs-all; then
        echo "Adding task ${job_no} to the list of tasks to be started."
        echo ${job_no} >> batchsystem/tmp/tasks-to-start
    else
        echo "Omitting task ${job_no} because it was found in the batchsystem."
    fi
done

# Variables
k=0
delay_time="${4}"
# Resetting the collections and continuing the jobs if existent
if [ -f batchsystem/tmp/tasks-to-start ]; then
    k_max="$(cat batchsystem/tmp/tasks-to-start | wc -l)"
    for job_no in $(cat batchsystem/tmp/tasks-to-start ); do
        k=$(( k + 1 ))
        echo "Starting task ${job_no}"
        hqh_bs_submit.sh batchsystem/job-files/task-${job_no}.${batchsystem}
    done
fi

# Removing the temporary files
if [ -f "batchsystem/tmp/jobs-all" ]; then
    rm batchsystem/tmp/jobs-all
fi
if [ -f "batchsystem/tmp/tasks-to-start" ]; then
    rm batchsystem/tmp/tasks-to-start
fi

# Displaying some information
if [[ ! "$*" = *"quiet"* ]]; then
    echo "Number of jobs which were started: ${k}"
    echo
fi

