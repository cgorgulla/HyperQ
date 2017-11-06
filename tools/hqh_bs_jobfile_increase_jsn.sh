#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_bs_jobfile_increase_jsn.sh <job ID>

Increases the job serial number of a the jobfile batchsystem/job-files/main/<job-id>.<batch-system>
<job ID>: Natural number
<batchsystem> : Is determined by the corresponding setting in the file input-files/config.txt

Has to be run in the root folder."

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "1" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 1"
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
jid=${1}
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print tolower($2)}')
runtimeletter=$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')
jsn=$(grep -m 1 "^HQ_JSN=" batchsystem/job-files/main/${jid}.${batchsystem} | awk -F '=' '{print $2}' | tr -d '[:space:]')

# Adjusting the batchsystem job names
if [ "${batchsystem}" = "slurm" ]; then
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name=${runtimeletter}-${jid}.$((jsn+1))/g" batchsystem/job-files/main/${jid}.${batchsystem}
elif [ "${batchsystem}" = "mtp" ]; then
    sed -i "s/^#PBS -N .*/#PBS -N ${runtimeletter}-${jid}.$((jsn+1))/g" batchsystem/job-files/main/${jid}.${batchsystem}
elif [ "${batchsystem}" = "lsf" ]; then
    sed -i "s/^#BSUB -J .*/#BSUB -J ${runtimeletter}-${jid}.$((jsn+1))/g" batchsystem/job-files/main/${jid}.${batchsystem}
elif [ "${batchsystem}" = "sge" ]; then
    sed -i "s/^#\\$ -N .*/#\$ -N ${runtimeletter}-${jid}.$((jsn+1))/g" batchsystem/job-files/main/${jid}.${batchsystem}
fi

# Adjusting the HyperQ variables
sed -i "s/^HQ_JSN=.*/HQ_JSN=$((jsn+1))"
sed -i "s/^HQ_JOBNAME=.*/HQ_JOBNAME=${runtimeletter}-${jid}.$((jsn+1))"

# Printing final job information
echo -e "\n * The job file  batchsystem/job-files/main/${jid}.${batchsystem} has been updated.\n\n"