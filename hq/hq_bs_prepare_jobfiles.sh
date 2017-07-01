#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_bs_prepare_jobfiles.sh <task-list> <job-template>

Has to be run in the root folder."

# Checking the input paras
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "2" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 2"
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
    echo
    echo -e "Error: Wrong number of arguments. Exiting...
"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
}
trap 'error_response_std $LINENO' ERR

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
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print $2}')
runtimeletter=$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')

# Loop for each task
while IFS='' read -r line; do
    line_array=($line)
    task_id="${line_array[0]}"
    task_command="${line_array[@]:1}"
    job_file="batchsystem/job-files/task-${task_id}.${batchsystem}"
    echo -e " * Preparing the jobfile for task ${task_id}"
    cp ${job_template} ${job_file}
    sed -i "s/job_id_placeholder/${task_id}/g" ${job_file}
    sed -i "s/command_placeholder/${task_command}/g" ${job_file}
    sed -i "s/runtimeletter/${runtimeletter}/g" ${job_file}
done < "${task_list}"

# Final information
echo -e "\n * All job-files have been prepared.\n\n"
