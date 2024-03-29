#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_bs_prepare_jobfiles.sh <task-list> <job-template> <subjob template> <job-type-letter> <first job ID> <subjobs per job> <tasks per subjob> <parallelize subjobs> <parallelize tasks>

Arguments:
    <task list>: One task per line, one task is represented by one command. No empty lines should be present.

    <job-template>: A batchsystem jobfile template which needs to have a file ending matching the batchsystem type specified in the general hyperq config file.

    <subjob template>: Template filename for the subjobs.

    <job-type-letter>: Any lowercase letter between a and j.

    <first job ID>: Positive integer. The first job ID of the jobs which are created.

    <subjobs per job>: Positive integer

    <tasks per subjob>: Positive integer

    <parallelize subjobs>: Can be true or false. If true, the subjobs in the main jobs will be carried out in parallel.

    <parallelize tasks>: Can be true or false. If true, the tasks in the subjobs will be carried out in parallel.

Has to be run in the root folder."

# Checking the input paras
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "9" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 9"
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

# Bash options
set -o pipefail

# Config file setup
if [[ -z "${HQ_CONFIGFILE_GENERAL}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_GENERAL was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_GENERAL=input-files/config/general.txt
    export HQ_CONFIGFILE_GENERAL
fi

# Verbosity
# Checking if standalone mode (-> non-runtime)
if [[ -z "${HQ_VERBOSITY_RUNTIME}" && -z "${HQ_VERBOSITY_NONRUNTIME}" ]]; then

    # Variables
    export HQ_VERBOSITY_NONRUNTIME="$(grep -m 1 "^verbosity_nonruntime=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

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

# Printing some information
echo -e "\n\n                                   ***  Preparing the job-files (hq_bs_prepare_jobfiles.sh) ***\n"

# Variables
task_list=$1
job_template=$2
subjob_template=$3
jtl=$4
first_jid=$5
subjobs_per_job=$6
tasks_per_subjob=$7
parallelize_subjobs=$8
parallelize_tasks=$9
batchsystem=$(grep -m 1 "^batchsystem=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')
workflow_id=$(grep -m 1 "^workflow_id=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')
command_prefix_bs_subjob=$(grep -m 1 "^command_prefix_bs_subjob=" ${HQ_CONFIGFILE_GENERAL} | awk -F '[=#]' '{print $2}')
command_prefix_bs_task=$(grep -m 1 "^command_prefix_bs_task=" ${HQ_CONFIGFILE_GENERAL} | awk -F '[=#]' '{print $2}')
tasks_parallel_delay_time=$(grep -m 1 "^tasks_parallel_delay_time=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')
tasks_total="$(wc -l ${task_list} | awk '{print $1}')"

# Checking if the batchsystem types match
if [[ "${batchsystem}" != "${job_template/*.}" ]]; then

    # Printing an error message before exiting
    echo -e "\n * Error: The batchsystem type specified in the file ${HQ_CONFIGFILE_GENERAL} does not match the ending of the batchsystem template file. Exiting...\n\n"
    exit 1
fi 

# Checking if the job type letter is valid
if ! [[ "${jtl}" =~ ^[abcdefghij]$ ]]; then

    # Printing an error message before exiting
    echo -e "\n * Error: The input argument 'job type letter' has an unsupported value. Exiting...\n\n"
    exit 1
fi

# Checking if the variable first_jid is a positive integer
if ! [[ "${first_jid}" -ge "1" ]]; then

    # Printing an error message before exiting
    echo -e "\n * Error: The input argument 'first_jid' has an unsupported value. Exiting...\n\n"
    exit 1
fi

# Checking if the variable subjobs_per_job is a positive integer
if ! [[ "${subjobs_per_job}" -ge "1" ]]; then

    # Printing an error message before exiting
    echo -e "\n * Error: The input argument 'subjobs_per_job' has an unsupported value. Exiting...\n\n"
    exit 1
fi

# Checking if the variable tasks_per_subjob is a positive integer
if ! [[ "${tasks_per_subjob}" -ge "1" ]]; then

    # Printing an error message before exiting
    echo -e "\n * Error: The input argument 'tasks_per_subjob' has an unsupported value. Exiting...\n\n"
    exit 1
fi

# Preparing required folders
mkdir -p batchsystem/job-files/main/
mkdir -p batchsystem/job-files/subjob-lists/
mkdir -p batchsystem/job-files/subjobs/
mkdir -p batchsystem/output-files/

# Loop for each task
jid=$first_jid
sjid=1                                                                      # Subjob ID
task_ID=1                                                                   # Counting within subjobs
task_counter=1                                                              # Counting the total number of tasks processed
while IFS='' read -r command_task; do

    # Printing some information
    echo -e " * Preparing task ${task_ID} of subjob ${sjid} of job ${jid}"

    # Variables
    job_file="batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}"
    subjoblist_file="batchsystem/job-files/subjob-lists/jtl-${jtl}.jid-${jid}.sh"
    subjob_file="batchsystem/job-files/subjobs/jtl-${jtl}.jid-${jid}.sjid-${sjid}.sh"
    command_task="${command_task} \&>> batchsystem/output-files/jtl-${jtl}.jid-${jid}.jsn-\${HQ_BS_JSN}.sjid-${sjid}.task-${task_ID}.bid-\${HQ_BS_BID}.out"

    # Checking if this task is the first task of a new subjob
    if [ "${task_ID}" -eq "1" ]; then

        # Checking if a new job file has to be created
        if [ "${sjid}" -eq "1" ]; then

            # Copying the job file
            cp ${job_template} ${job_file}

            # Syncing the job file already, even though it can be synced again when starting it with hq_bs_start_jobs.sh
            hqh_bs_jobfile_sync_controlfile.sh ${jtl} ${jid}

            # Adjusting the job file
            sed -i "s/workflow_id_placeholder/${workflow_id}/g" ${job_file}
            sed -i "s/jtl_placeholder/${jtl}/g" ${job_file}
            sed -i "s/jid_placeholder/${jid}/g" ${job_file}
            sed -i "s/jsn_placeholder/0/g" ${job_file}                      # 0 because then we can always increase the jsn directly before starting new jobs manually

            # Creating the subjob-list file / clearing if already existent
            echo -n "" > ${subjoblist_file}
        fi

        # Preparing the initial subjob file
        cp ${subjob_template} ${subjob_file}

        # Preparing the subjob command for the subjob file
        if [ ${batchsystem^^} == "SLURM" ]; then
            command_subjob="${command_prefix_bs_subjob} ${subjob_file} &>> batchsystem/output-files/jtl-${jtl}.jid-${jid}.jsn-\${HQ_BS_JSN}.sjid-${sjid}.bid-\${HQ_BS_BID}.out"
        elif [ ${batchsystem^^} == "MTP" ]; then
            command_subjob="${command_prefix_bs_subjob} ${subjob_file} &>> batchsystem/output-files/jtl-${jtl}.jid-${jid}.jsn-\${HQ_BS_JSN}.sjid-${sjid}.bid-\${HQ_BS_BID}.out"
        elif [ ${batchsystem^^} == "LSF" ]; then
            command_subjob="${command_prefix_bs_subjob} ${subjob_file} &>> batchsystem/output-files/jtl-${jtl}.jid-${jid}.jsn-\${HQ_BS_JSN}.sjid-${sjid}.bid-\${HQ_BS_BID}.out"
        elif [ ${batchsystem^^} == "SGE" ]; then
            command_subjob="${command_prefix_bs_subjob} ${subjob_file} &>> batchsystem/output-files/jtl-${jtl}.jid-${jid}.jsn-\${HQ_BS_JSN}.sjid-${sjid}.bid-\${HQ_BS_BID}.out"
        else
            echo -e "\n * Error: The specified batchsystem (${batchsystem}) is not supported. Exiting...\n\n"
            exit 1
        fi

        # Adding the parallelization flag if specified
        if [ "${parallelize_subjobs}" == "true" ]; then
            command_subjob="${command_subjob} &"
        fi

        # Adding the subjob to the subjob file
        echo "${command_subjob}" >> ${subjoblist_file}
    fi

    # Checking the parallel flags
    if [ "${parallelize_tasks}" == "true" ]; then
        sed -i "s%#task_placeholder%${command_prefix_bs_task} ${command_task} \& \nsleep ${tasks_parallel_delay_time}\n#task_placeholder%g" ${subjob_file}
    elif [ "${parallelize_tasks}" == "false" ]; then
        sed -i "s%#task_placeholder%${command_prefix_bs_task} ${command_task} \& \nwait\n#task_placeholder%g" ${subjob_file}
    else
        # Printing an error message before exiting
        echo -e "\n * Error: The input argument 'parallelize_tasks' has an unsupported value (${parallelize_tasks}). Exiting...\n\n"
        exit 1
    fi

    # Increasing the waiting time
    sed -i "s|#task_placeholder|waiting_time=\$((waiting_time+${tasks_parallel_delay_time}))\n#task_placeholder|g" ${subjob_file}

    # Increasing the task_count
    sed -i "s|#task_placeholder|task_count=\$((task_count+1))\n\n#task_placeholder|g" ${subjob_file}

    # Checking if last task
    if [ "${task_counter}" == "${tasks_total}" ]; then

        # Finalizing the subjob file
        sed -i "/#task_placeholder/d" ${subjob_file}

    # Checking if this task is not the last one of this subjob
    elif [ "${task_ID}" -lt "${tasks_per_subjob}" ]; then

        # Increasing the task_ID
        task_ID="$((task_ID+1))"
    else

        # Resetting the task ID
        task_ID=1

        # Finalizing the subjob file
        sed -i "/#task_placeholder/d" ${subjob_file}

        # Checking if this subjob was not the last subjob of this job
        if [ "${sjid}" -lt "${subjobs_per_job}" ]; then

            # Increasing the subjob ID
            sjid="$((sjid+1))"
        else

            # Resetting the subjob ID
            sjid=1

            # Increasing the job ID
            jid="$((jid+1))"
        fi
    fi

    # Updating the task counter
    task_counter=$((task_counter+1))

done < "${task_list}"

# Setting file permissions
chmod u+x batchsystem/job-files/main/*
chmod u+x batchsystem/job-files/subjobs/*

# Printing final information
echo -e "\n * All job-files have been prepared.\n\n"
