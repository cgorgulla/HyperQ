#!/usr/bin/env bash

# Usage information
usage="# Usage: hqh_bs_submit.sh <jobfile>

Has to be run in the root folder."

# Checking the input arguments
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
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Standard error response
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
# Getting the batchsystem type
line=$(grep -m 1 "^batchsystem=" input-files/config.txt)
batchsystem="${line/batchsystem=}"
jobfile=${1}

# Submitting the job
if [ "${batchsystem}" == "slurm" ]; then
    sbatch ${jobfile}
elif [ "${batchsystem}" == "mtp" ]; then
    msub ${jobfile}
elif [ "${batchsystem}" == "sge" ]; then
    qsub ${jobfile}
elif [ "${batchsystem}" == "lsf" ]; then
    bsub < ${jobfile}
fi

# Printing some information
if [ ! "$*" = *"quiet"* ]; then
    echo "The job with the jobfile ${jobfile} has been submitted at $(date)."
    echo
fi
