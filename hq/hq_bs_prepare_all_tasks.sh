#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_prepare_all_tasks.sh <MSP list file> <command> <output file>

Has to be run in the root folder.

<MSP list file>: Text file containing a list of molecular system pairs (MSP), one pair per line, in form of system1_system2.
                 For each MSP in the file <MSP list file> a task defined by <command> will be created.

<command>: This argument needs to be enclosed in quotes (single or double) if the command contain spaces.
           In the command the expression ' MSP ' has to be used as a placeholder for the specific MSPs in the list. (The embedding whitespaces are required.)
           In addition the variable 'TDS' (thermodynamic state) can be used. If present, the command will be spread out over all TD states (end states and alchemical intermediate states) for each MSP,
           i.e. the variable 'TDS' is replaced by 'i:i', where i runs over all TDSs.
           The command is primarily intended to be used in combination with hqf_gen_run_one_pipe.sh.

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
    echo "Reason: The wrong number of arguments was provided when calling the script."
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

# Verbosity
verbosity_preparation="$(grep -m 1 "^verbosity_preparation=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
if [ "${verbosity_preparation}" = "debug" ]; then
    set -x
fi

# Checking the version of BASH, we need at least 4.3 (wait -n)
bash_version=${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}
if [ ${bash_version} -lt 43 ]; then
    # Printing some information
    echo
    echo "Error: The Bash version seems to be too old. At least version 4.3 is required."
    echo "Exiting..."
    echo
    echo
    exit 1
fi

# Variables
msp_list_file="${1}"
command_general="${2}"
output_filename="${3}"
tdw_count="$(grep -m 1 "^tdw_count=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
tds_count="$((tdw_count+1))"

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

    # Preparing the corresponding tasks for this MSP
    echo -e " * Preparing the tasks for MSP ${msp}..."
    if [[ "${command_general}" == *"TDS"* ]]; then
        echo "   * Preparing one task for each TDS..."
        for i in $(seq 1 ${tds_count}); do
            echo "     * Preparing the task for TDS ${i}/${tds_count}"
            command_specific="${command_general// MSP / ${msp} }"
            command_specific="${command_specific//TDS/${i}:${i}}"
            hq_bs_prepare_one_task.sh "${command_specific}" "${output_filename}"
        done
    else
        command_specific="${command_general// MSP / ${msp} }"
        hq_bs_prepare_one_task.sh "${command_specific}" "${output_filename}"
    fi

done < ${msp_list_file}

echo -e "\n * All tasks have been prepared.\n\n"
