#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_prepare_all_tasks.sh <first task index> <command> <output filename>

Has to be run in the root folder.
The <command> argument needs to be enclosed in quotes (single or double) because it will contain spaces.
The tasks will be appended to the file batch-system/task-lists/<output filename>. If this file does not exist yet, it will be created.
For each system in input-files/systems a task will be created.
One task consists of one command.
In the command the term 'system' has to be used as a placeholder for the actual system names."

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


# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Standard error response 
error_response_std() {
    # Printing some information
    echo
    echo "An error was trapped" 1>&2
    echo "The error occured in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occured on lin $1" 1>&2
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
first_index="${1}"
command="${2}"
output_filename="${3}"

# Printing some information
echo -e "\n *** Preparing the tasks for all systems in input-files/systems\n"

# Loop for each system
counter="${first_index}"
for system in $(ls input-files/systems); do
    echo -e " * Preparing the task for system ${system}"
    hq_bs_prepare_one_task.sh "${counter}" "${command/ system / ${system} }" "${output_filename}"
    counter=$((counter+1))
done

echo -e "\n * All tasks have been prepared.\n\n"
