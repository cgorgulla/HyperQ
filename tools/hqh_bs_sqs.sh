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
    echo "Reason: The wrong number of arguments were provided when calling the script."
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
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Determining the batchsystem
if [ "${batchsystem}" == "slurm" ]; then
    squeue -l | grep ${USER}
elif [ "${batchsystem}" == "mtp" ]; then
    qstat | grep ${USER}
elif [ "${batchsystem}" == "lsf" ]; then
    bjobs | grep ${USER}
elif [ "${batchsystem}" == "sge" ]; then
    qstat | grep ${USER}
else
    echo -e " * Unsupported batchsystem (${batchsystem}) specified in the file ../workflow/control/all.ctrl. Exiting... \n\n"
    exit 1
fi

