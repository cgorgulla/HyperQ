#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_prepare_all_tasks.sh <MSP list file> <command> <output file>

Has to be run in the root folder.

<MSP list file>: Text file containing a list of molecular system pairs (MSP), one pair per line, in form of system1_system2.
                 For each MSP in the file <MSP list file> a task defined by <command> will be created.
<command>: This argument needs to be enclosed in quotes (single or double) if the command contain spaces.
           In the command the expression ' MSP ' has to be used as a placeholder for the specific MSPs in the list.
           The command primarily intended to be used is hqf_gen_run_one_pipe.sh
<output file>: The tasks will be appended to the specified file. If this file does not exist yet, it will be created."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "3" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 3"
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
trap 'error_response_nonstd $LINENO' ERR

# Bash options
set -o pipefail

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
msp_list_file="${1}"
command_general="${2}"
output_filename="${3}"

# Printing some information
echo -e "\n *** Preparing the tasks for all MSPs in ${msp_list_file} ***\n"

# Loop for each system
while IFS= read -r line || [[ -n "$line" ]]; do

    # Checking the input line
    if [[ "${line}" != *"_"* ]] || [[ -z "${line//_*}" ]] || [[ -z "${line//_*}" ]]; then
        echo -e "Error: The msp-list-file contains an invalid line: ${line}. Exiting...\n\n"
        exit 1
    else
        msp="${line}"
    fi

    # Preparing the corresponding task for this MSP
    echo -e " * Preparing the task for the MSP ${msp}"
    command_specific="${command_general/ MSP / ${msp} }"
    hq_bs_prepare_one_task.sh "${command_specific}" "${output_filename}"

done < ${msp_list_file}

echo -e "\n * All tasks have been prepared.\n\n"
