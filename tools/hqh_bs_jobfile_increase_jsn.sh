#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_bs_jobfile_increase_jsn.sh <job-type-letter> <job ID>

Increases the job serial number of a the jobfile batchsystem/job-files/main/<job-id>.<batch-system>
The variable <batchsystem> is determined by the corresponding setting in the file input-files/config.txt

Arguments:
    <job-type-letter>: The job-type-letter corresponding to the jobs to be started (a lower case letter)

    <job ID>: Natural number


Has to be run in the root folder."

# Checking the input parameters
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
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 2"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity_runtime=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
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

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Variables
jtl=${1}
jid=${2}
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print tolower($2)}')
workflow_id=$(grep -m 1 "^workflow_id=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')
jsn=$(grep -m 1 "^HQ_JSN=" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')

# Checking if the job type letter is valid
if [[ "${jtl}" != [[:lower:]] ]]; then
    echo -e "\n * Error: The input argument 'job type letter' has an unsupported value. Exiting...\n\n"
    exit 1
fi

# Adjusting the batchsystem job names
if [ "${batchsystem}" = "slurm" ]; then
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name=${workflow_id}:${jtl}.${jid}.$((jsn+1))/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "mtp" ]; then
    sed -i "s/^#PBS -N .*/#PBS -N ${workflow_id}:${jtl}.${jid}.$((jsn+1))/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "lsf" ]; then
    sed -i "s/^#BSUB -J .*/#BSUB -J ${workflow_id}:${jtl}.${jid}.$((jsn+1))/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "sge" ]; then
    sed -i "s/^#\\$ -N .*/#\$ -N ${workflow_id}:${jtl}.${jid}.$((jsn+1))/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
fi

# Adjusting the output file names and possible other occurrences of jsn-${jsn}
sed -i "s/jsn\-${jsn}/jsn-$((jsn+1))/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}

# Adjusting the HyperQ variables
sed -i "s/^HQ_JSN=.*/HQ_JSN=$((jsn+1))/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
sed -i "s/^HQ_JOBNAME=.*/HQ_JOBNAME=${workflow_id}:${jtl}.${jid}.$((jsn+1))/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}

# Printing final job information
echo -e "\n * The JSN (job serial number) of the file batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem} has been updated.\n\n"
