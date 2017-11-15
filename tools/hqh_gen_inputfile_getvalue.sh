#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_gen_inputfile_getvalue.sh <input file> <keyword> <remove whitespaces>

Determines the value of the keyword in the given input file.
Examples of input files:
    * input-files/config.txt
    * batchsystem/control/all:all.ctrl

Arguments:
    <remove whitespaces>: possible values: false, true

Has to be run in the root folder."

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "3" ]; then
    echo 1>&2
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Reason: The wrong number of arguments was provided when calling the script." 1>&2
    echo "Number of expected arguments: 3" 1>&2
    echo "Number of provided arguments: ${#}" 1>&2
    echo "Provided arguments: $@" 1>&2
    echo 1>&2
    echo -e "$usage" 1>&2
    echo 1>&2
    echo 1>&2
    exit 1
fi

# Verbosity
# Checking if standalone mode (-> non-runtime)
if [[ -z "${HQ_VERBOSITY_RUNTIME}" && -z "${HQ_VERBOSITY_NONRUNTIME}" ]]; then

    # Variables
    export HQ_VERBOSITY_NONRUNTIME="$(grep -m 1 "^verbosity_nonruntime=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

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

# Standard error response 
error_response_std() {

    # Printing some information
    echo 1>&2
    echo "An error was trapped" 1>&2
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
    echo "Working directory: $PWD"
    echo "Exiting..." 1>&2
    echo 1>&2
    echo 1>&2

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Keyword not found error
keyword_not_found() {

    # Printing some information
    echo -e "\n * Error: The given keyword (${keyword}) does not seem to be contained or specified properly in the input file. Exiting...\n\n" 1>&2
    exit 1

    # Exiting
    exit 1
}

# Bash options
set -o pipefail
shopt -s nullglob

# Variables
input_file=${1}
keyword=${2}
remove_whitespaces=${3}

# Checking if the input file is present
if ! [ -s ${input_file} ]; then

    # Printing some information
    echo -e "\n * Error: The specified input file does either not exist or is empty. Exiting...\n\n" 1>&2
    exit 1
fi

# Checking if whitespaces should be removed
if [ "${remove_whitespaces^^}" == "TRUE" ]; then

    # Getting the value
    trap '' ERR
    value="$(grep -m 1 "^${keyword}=" ${input_file} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

    # Checking the exit code
    if [ "$?" != "0" ]; then
        keyword_not_found
    fi

    # Restoring the standard error trap
    trap 'error_response_std $LINENO' ERR

elif [ "${remove_whitespaces^^}" == "FALSE" ]; then

    # Getting the value
    trap '' ERR
    value=$(grep -m 1 "^${keyword}=" input-files/config.txt | awk -F '[=#]' '{print $2}')

    # Checking the exit code
    if [ "$?" != "0" ]; then
        keyword_not_found
    fi

    # Restoring the standard error trap
    trap 'error_response_std $LINENO' ERR
else

    # Printing some information
    echo -e "\n * Error: The input argument 'remove_whitespaces' has an unsupported value. Exiting...\n\n" 1>&2
    exit 1
fi

# Returning the determined value
echo -n "${value}"
