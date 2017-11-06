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

# Bash options
set -o pipefail

# Verbosity
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

# Variables
jobfile=${1}
batchsystem=$(grep -m 1 "^batchsystem=" input-files/config.txt | awk -F '=' '{print tolower($2)}')

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
