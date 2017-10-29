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
    echo "The error occured in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occured on line $1" 1>&2
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
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n ***  Preparing the job-files (hq_bs_prepare_jobfiles.sh) ***\n"

# Variables
task_list=$1
job_template=$2
first_job_ID=$3
subjobs_per_job=$4
tasks_per_subjob=$5
parallelize_subjobs=$6
parallelize_tasks=$7
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print $2}')
runtimeletter=$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')
command_prefix_bs_subjob=$(grep -m 1 "^command_prefix_bs_subjob=" input-files/config.txt | awk -F '=' '{print $2}')
command_prefix_bs_task=$(grep -m 1 "^command_prefix_bs_task=" input-files/config.txt | awk -F '=' '{print $2}')
no_of_tasks="$(wc -l ${task_list} | awk '{print $1}')"

# Loop for each task
job_ID=$first_job_ID
subjob_ID=1
task_ID=1           # Counting within subjobs only
task_counter=1

# Preparing required folders
mkdir -p batchsystem/job-files/main/
mkdir -p batchsystem/job-files/sub/
mkdir -p batchsystem/output-files/

while IFS='' read -r command_task; do

    # Printing some information
    echo -e " * Preparing task ${task_ID} of job ${job_ID}, subjob ${subjob_ID}"

    # Variables
    job_file_main="batchsystem/job-files/main/${job_ID}.${batchsystem}"
    job_file_sub="batchsystem/job-files/sub/${job_ID}.${subjob_ID}.sh"

    # Checking the parallel flags
    if [ "${parallelize_tasks}" == "true" ]; then
        command_task="${command_task} &"
    fi

    # Checking if this is the first task of a new subjob
    if [ "${task_ID}" -eq "1" ]; then

        # Checking if a new job file has to be created
        if [ "${subjob_ID}" -eq "1" ]; then

            # Copying the job file
            cp ${job_template} ${job_file_main}

            # Adjusting the job file
            sed -i "s/runtimeletter/${runtimeletter}/g" ${job_file_main}
            sed -i "s/mainjob_id_placeholder/${job_ID}/g" ${job_file_main}
        fi

        # Preparing the initial sub job file
        echo -e "#!/usr/bin/env bash" > ${job_file_sub}
        echo >> ${job_file_sub}
        echo >> ${job_file_sub}
        echo "# Body" >> ${job_file_sub}

        # Preparing the command of the subjob for the jobfile
        if [ ${batchsystem^^} == "SLURM" ]; then
            command_subjob="${command_prefix_bs_subjob} ${job_file_sub} \&> batchsystem/output-files/job-${job_ID}.${subjob_ID}.%j.out"
        elif [ ${batchsystem^^} == "MTP" ]; then
            command_subjob="${command_prefix_bs_subjob} ${job_file_sub} \&> batchsystem/output-files/job-${job_ID}.${subjob_ID}.\${PBS_JOBID}.out"
        elif [ ${batchsystem^^} == "LSF" ]; then
            command_subjob="${command_prefix_bs_subjob} ${job_file_sub} \&> batchsystem/output-files/job-${job_ID}.${subjob_ID}.%J.out"
        elif [ ${batchsystem^^} == "SGE" ]; then
            command_subjob="${command_prefix_bs_subjob} ${job_file_sub} \&> batchsystem/output-files/job-${job_ID}.${subjob_ID}.\${JOB_ID}.out"
        else
            echo -e "\n * Error: The specified batchsystem (${batchsystem}) is not supported. Exiting...\n\n"
            exit 1
        fi

        # Adding the parallization flag if specified
        if [ "${parallelize_subjobs}" == "true" ]; then
            command_subjob="${command_subjob} \&"
        fi

        # Adding the sub job to the job file
        sed -i "s|#main_code_placeholder|${command_subjob}\n#main_code_placeholder|g" ${job_file_main}
    fi

    # Adding the task to the sub job file
    echo "${command_prefix_bs_task} ${command_task}" >> ${job_file_sub}

    # Checking if this task is the last task of all
    if [[ "${task_counter}" -eq "${no_of_tasks}" ]] ; then
        # Finalizing the subjob file
        echo -e "\nwait" >> "${job_file_sub}"

        # Finalizing the main job file
        sed -i "/#main_code_placeholder/d" ${job_file_main}

    else
        # Checking if this task was not the last one of this subjob
        if [ "${task_ID}" -lt "${tasks_per_subjob}" ]; then
            task_ID="$((task_ID+1))"
        else
            # Resetting the task ID
            task_ID=1

            # Finalizing the subjob file
            echo -e "\nwait" >> "${job_file_sub}"

            # Checking if this subjob was not the last subjob of this job
            if [ "${subjob_ID}" -lt "${subjobs_per_job}" ]; then
                # Increasing the subjob ID
                subjob_ID="$((subjob_ID+1))"

            else
                # Finalizing the main job file
                sed -i "/#main_code_placeholder/d" ${job_file_main}

                # Resetting the subjob ID
                subjob_ID=1

                # Increasing the job ID
                job_ID="$((job_ID+1))"
            fi
        fi

        # Updating the task counter
        task_counter=$((task_counter+1))
    fi
done < "${task_list}"

# Final information
echo -e "\n * All job-files have been prepared.\n\n"
