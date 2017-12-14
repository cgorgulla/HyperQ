#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_start_jobs.sh <job-type-letter> <JID ranges> <increase job serial number> <check for active jobs> <sync with controlfile> <delay time>

Starts the job files in batchsystem/job-files/main/jtl-<jtl>.jid-<jid>.<batchsystem>
The variable <batchsystem> is determined by the corresponding setting in the file input-files/config.txt

Arguments:
    <increase job serial number>: Possible values: true or false

    <JID ranges>: Can either
            * be set to 'all', which refers to all jobs in the batchsystem/job-files/main folder of the specified JTL
            * or specify a colon separated list of JID ranges in the form <range 1 first JID>-<range 1 last JID>:<range 2 first JID>-<range 2 last JID>:...

    <job-type-letter>: The job-type-letter corresponding to the jobs to be started (a lower case letter)

    <check for active jobs>: Checks if jobs of the same WFID and JID and the specified JTLs are already in the batchsystem and skips them.
                             Possible values: false, true:JTLs (e.g. true:abc)

    <delay time>: Time in seconds between the submission of two consecutive jobs.

    <sync with control file>: Possible values: true, false. Will determine the responsible control file and sync the job file with it before starting the job.

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
    echo "Number of expected arguments: 7"
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
    rm -r ${temp_folder} &>/dev/null || true
}
trap 'cleanup_exit' EXIT

# Bash options
set -o pipefail

# Verbosity
# Checking if standalone mode (-> non-runtime)
if [[ -z "${HQ_VERBOSITY_RUNTIME}" && -z "${HQ_VERBOSITY_NONRUNTIME}" ]]; then

    # Variables
    export HQ_VERBOSITY_NONRUNTIME="$(grep -m 1 "^verbosity_nonruntime=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

    # Checking the value
    if [ "${HQ_VERBOSITY_NONRUNTIME}" = "debug" ]; then
        set -x
    fi

# It seems the script was called by another script (non-standalone mode)
else
    if [[ "${HQ_VERBOSITY_RUNTIME}" == "debug" || "${HQ_VERBOSITY_NONRUNTIME}" == "debug" ]]; then
        set -x
    fi
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
jid_ranges=${2}
increase_jsn=${3}
check_active_jobs=${4}
sync_job_file=${5}
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

# Determining which jobs have to be checked/started
JIDs_to_check=""
# Checking the value type of the jid_ranges variable
if [[ "${jid_ranges}" == "all" ]] ; then
    for jobfile in batchsystem/job-files/main/jtl-${jtl}.* ; do

        # Variables
        jid=${jobfile//[^0-9]}
        JIDs_to_check="${JIDs_to_check} ${jid}"
    done
else
    # Loop for each JID range
    for jid_range in ${jid_ranges/:/ }; do

        # Variables
        first_jid=${jid_range/-*}
        last_jid=${jid_range/*-}

        # Checking the variables
        if ! ( [ "${first_jid}" -eq "${first_jid}" ] && [ "${last_jid}" -eq "${last_jid}" ] ) ; then

            # Printing some information
            echo -e "\n * Error: The <JID ranges> variable has an unsupported format. Exiting...\n\n"
            exit 1
        fi

        # Loop for each jid in the current JID range
        for jid in $(seq ${first_jid} ${last_jid}); do
            JIDs_to_check="${JIDs_to_check} ${jid}"
        done
    done
fi

# Checking if we should check for already active jobs
job_count=0
JIDs_to_start=""
if [[ "${check_active_jobs^^}" == *"TRUE"* ]]; then

    # Variables
    jtls_to_check=${check_active_jobs/*:}

    # Printing some information
    echo -e " *** Checking which jobs are already in the batchsystem\n"

    # Checking if there are JTLs specified
    if [[ ! "${check_active_jobs}" == *":"* || -z "${jtls_to_check}" ]] ; then

        # Printing some information
        echo -e "\n * Error: Checking for active compounds was requested, but no JTLs for the cross checks have been supplied.  Exiting...\n\n"
        exit 1
    fi

    # Getting the active jobs
    hqh_bs_sqs.sh > ${temp_folder}/jobs-all 2>/dev/null || true

    for jid in ${JIDs_to_check}; do
        if ! grep -q "${workflow_id}:[${jtls_to_check}]\.${jid}\." ${temp_folder}/jobs-all; then

            # Printing some information
            echo "   * Adding job ${jtl}.${jid} to the list of jobs to be started."

            # Adding the JID
            JIDs_to_start="${JIDs_to_start} ${jid}"

            # Increasing the counter
            job_count=$((job_count+1))
        else

            # Printing some information
            echo "   * Omitting the job ${jtl}.${jid} because it was found to be already in the batchsystem."

            # Increasing the counter
            jobs_omitted=$((jobs_omitted+1))
        fi
    done
elif [ "${check_active_jobs^^}" == "FALSE" ]; then

    # Loop for all JIDs
    for jid in ${JIDs_to_check}; do

        # Printing some information
        echo " * Adding job ${jtl}.${jid} to the list of jobs to be started."

        # Adding the JID
        JIDs_to_start="${JIDs_to_start} ${jid}"

        # Increasing the counter
        job_count=$((job_count+1))
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
    for jid in ${JIDs_to_start}; do

        # Preparing the new jobfile
        if [ "${increase_jsn^^}" == "TRUE" ]; then
            hqh_bs_jobfile_increase_jsn.sh ${jtl} ${jid}
        else
            # Formatting screen output
            echo
        fi

        # Syncing the job file
        if [ "${sync_job_file^^}" == "TRUE" ]; then
            hqh_bs_jobfile_sync_controlfile.sh ${jtl} ${jid}
        fi

        # Submitting the job
        echo -e " * Starting job ${jid}"
        hqh_bs_submit.sh batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}

        # Sleeping
        sleep ${delay_time}
    done
fi

# Displaying some information
echo -e "\n * The starting of the jobs has been completed"
echo -e "   * Number of jobs processed: $((last_jid-first_jid+1))"
echo -e "   * Number of jobs started: ${job_count}"
echo -e "   * Number of jobs omitted: ${jobs_omitted}\n\n"
