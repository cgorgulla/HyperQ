#!/usr/bin/env bash

# Usage information
usage="# Usage: hqh_bs_sqs.sh

Has to be run in the root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "0" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 0"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Bash options
set -o pipefail

# Variables
line=$(grep -m 1 "^batchsystem=" input-files/config.txt)
batchsystem="${line/batchsystem=}"

# Verbosity
verbosity_preparation="$(grep -m 1 "^verbosity_preparation=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
if [ "${verbosity_preparation}" = "debug" ]; then
    set -x
fi

# Determining the batchsystem
if [ "${batchsystem}" == "slurm" ]; then
    squeue -o "%.18i %.9P %.15j %.8u %.8T %.10M %.9l %.6D %R" | grep ${USER:0:8}
elif [ "${batchsystem}" == "mtp" ]; then
    qstat | grep ${USER:0:8} | grep -v " C "
elif [ "${batchsystem}" == "lsf" ]; then
    bjobs | grep ${USER:0:8}
elif [ "${batchsystem}" == "sge" ]; then
    qstat | grep ${USER:0:8}
else
    echo -e " * Unsupported batchsystem (${batchsystem}) specified in the file input-files/config.txt. Exiting... \n\n"
    exit 1
fi
