#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_bs_prepare_jobfiles.sh <task-list> <job-template> <first job ID> <subjobs per job> <tasks per subjob> <parallelize subjobs> <parallelize tasks>

<task list>: One task per line, one task is represented by one command. No empty lines should be present.
<first job ID>: Positive integer. The first job ID of the jobs which are created.
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
if [ "$#" -ne "7" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
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
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n ***  Preparing the job-files (hq_bs_prepare_jobfiles.sh) ***\n"

# Variables
task_list=$1
job_template=$2
first_jid=$3
subjobs_per_job=$4
tasks_per_subjob=$5
parallelize_subjobs=$6
parallelize_tasks=$7
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print $2}')
runtimeletter=$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')
command_prefix_bs_subjob=$(grep -m 1 "^command_prefix_bs_subjob=" input-files/config.txt | awk -F '=' '{print $2}')
command_prefix_bs_task=$(grep -m 1 "^command_prefix_bs_task=" input-files/config.txt | awk -F '=' '{print $2}')
no_of_tasks="$(wc -l ${task_list} | awk '{print $1}')"

# Checking if the batchsystem types match
if [[ "${batchsystem}" != "${job_template/*.}" ]]; then
    echo -e "\n * Error: The batchsystem type specified in the file input-files/config.txt does not match the ending of the batchsysetm template file. Exiting...\n\n"
    exit 1
fi 

# Preparing required folders
mkdir -p batchsystem/job-files/main/
mkdir -p batchsystem/job-files/subjobs/
mkdir -p batchsystem/job-files/tasks/
mkdir -p batchsystem/job-files/common/
mkdir -p batchsystem/output-files/

# Copying the common main job file
cp batchsystem/templates/jobfiles.common.main.sh batchsystem/job-files/common/main.sh

# Loop for each task
jid=$first_jid
sjid=1                                                                      # Subjob ID
task_ID=1
task_counter=1                                                              # Counting within subjobs
while IFS='' read -r command_task; do

    # Printing some information
    echo -e " * Preparing task ${task_ID} of job ${jid}, subjob ${sjid}"

    # Variables
    job_file="batchsystem/job-files/main/jid-${jid}.${batchsystem}"
    subjob_file="batchsystem/job-files/subjobs/jid-${jid}.sh"
    task_file="batchsystem/job-files/tasks/jid-${jid}.sjid-${sjid}.sh"
    command_task="${command_task} &> batchsystem/output-files/jid-${jid}.jsn-\${HQ_JSN}.sjid-${sjid}.task-${task_ID}.out"
    # Checking the parallel flags
    if [ "${parallelize_tasks}" == "true" ]; then
        command_task="${command_task} &"
    fi

    # Checking if this is the first task of a new subjob
    if [ "${task_ID}" -eq "1" ]; then

        # Checking if a new job file has to be created
        if [ "${sjid}" -eq "1" ]; then

            # Copying the job file
            cp ${job_template} ${job_file}

            # Adjusting the job file
            sed -i "s/runtimeletter_placeholder/${runtimeletter}/g" ${job_file}
            sed -i "s/jid_placeholder/${jid}/g" ${job_file}
            sed -i "s/jsn_placeholder/1/g" ${job_file}
        fi

        # Preparing the initial subjob file
        echo -e "#!/usr/bin/env bash" > ${task_file}
        echo >> ${task_file}
        echo >> ${task_file}
        echo "# Body" >> ${task_file}

        # Preparing the subjob command for the subjob file
        if [ ${batchsystem^^} == "SLURM" ]; then
            command_subjob="${command_prefix_bs_subjob} ${task_file} &> batchsystem/output-files/jid-${jid}.jsn-\${HQ_JSN}.sjid-${sjid}.out"
        elif [ ${batchsystem^^} == "MTP" ]; then
            command_subjob="${command_prefix_bs_subjob} ${task_file} &> batchsystem/output-files/jid-${jid}.jsn-\${HQ_JSN}.sjid-${sjid}.out"
        elif [ ${batchsystem^^} == "LSF" ]; then
            command_subjob="${command_prefix_bs_subjob} ${task_file} &> batchsystem/output-files/jid-${jid}.jsn-\${HQ_JSN}.sjid-${sjid}.out"
        elif [ ${batchsystem^^} == "SGE" ]; then
            command_subjob="${command_prefix_bs_subjob} ${task_file} &> batchsystem/output-files/jid-${jid}.jsn-\${HQ_JSN}.sjid-${sjid}.out"
        else
            echo -e "\n * Error: The specified batchsystem (${batchsystem}) is not supported. Exiting...\n\n"
            exit 1
        fi

        # Adding the parallelization flag if specified
        if [ "${parallelize_subjobs}" == "true" ]; then
            command_subjob="${command_subjob} &"
        fi

        # Adding the subjob to the subjob file
        echo "${command_subjob}" >> ${subjob_file}
    fi

    # Adding the task to the task file
    echo "${command_prefix_bs_task} ${command_task}" >> ${task_file}

    # Checking if this task is not the last one of this subjob
    if [ "${task_ID}" -lt "${tasks_per_subjob}" ]; then
        task_ID="$((task_ID+1))"
    else
        # Resetting the task ID
        task_ID=1

        # Finalizing the task file
        echo -e "\nwait" >> "${task_file}"

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

# Setting the permissions
chmod u+x batchsystem/job-files/main/*
chmod u+x batchsystem/job-files/subjobs/*

# Printing final information
echo -e "\n * All job-files have been prepared.\n\n"
