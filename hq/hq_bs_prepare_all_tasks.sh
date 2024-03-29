#!/usr/bin/env bash

# Usage information
usage="Usage: hq_bs_prepare_all_tasks.sh <MSP list file> <command> <output file>

<MSP list file>: Text file containing a list of molecular system pairs (MSP), one pair per line, in form of system1_system2.
                 For each MSP in the file <MSP list file> a task defined by <command> will be created.

<command>: This argument needs to be enclosed in quotes (single or double) if the command contain spaces.
           In the command the expression ' MSP ' has to be used as a placeholder for the specific MSPs in the list. (The embedding whitespaces are required.)
           In addition the variable 'TDS' (thermodynamic state) can be used. If present, the command will be spread out over all TD states (end states and alchemical intermediate states) for each MSP,
           i.e. the variable 'TDS' is replaced by 'i:i', where i runs over all TDSs.
           The command is primarily intended to be used in combination with hqf_gen_run_one_pipe.sh.

<output file>: The tasks will be appended to the specified file. If this file does not exist yet, it will be created.

Has to be run in the root folder."

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
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Config file setup
if [[ -z "${HQ_CONFIGFILE_GENERAL}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_GENERAL was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_GENERAL=input-files/config/general.txt
    export HQ_CONFIGFILE_GENERAL
fi

# Verbosity
# Checking if standalone mode (-> non-runtime)
if [[ -z "${HQ_VERBOSITY_RUNTIME}" && -z "${HQ_VERBOSITY_NONRUNTIME}" ]]; then

    # Variables
    export HQ_VERBOSITY_NONRUNTIME="$(grep -m 1 "^verbosity_nonruntime=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

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

# Printing some information
echo -e "\n *** Preparing the tasks for all MSPs in ${msp_list_file} ***\n"

# Preparing required folders
mkdir -p batchsystem/task-lists

# Loop for each system
while IFS= read -r line || [[ -n "$line" ]]; do

    # Checking the input line
    if [[ "${line}" != *"_"* ]] || [[ -z "${line//_*}" ]] || [[ -z "${line//_*}" ]]; then
        echo -e "Error: The msp-list-file contains an invalid line: ${line}. Exiting...\n\n"
        exit 1
    else
        msp_name="${line}"
    fi

    # Config file
    if [ -f input-files/config/${msp_name}.txt ]; then
        # Printing some information
        echo -e "\n * Info: For MSP ${msp_name} an individual configuration file has been found. Using this configuration file...\n"

        # Setting the variable
        HQ_CONFIGFILE_MSP=input-files/config/${msp_name}.txt
        export HQ_CONFIGFILE_MSP
    else
        # Printing some information
        echo -e "\n * Info: For MSP ${msp_name} no individual configuration file has been found. Using the general configuration file...\n"

        # Setting the variable
        HQ_CONFIGFILE_MSP=${HQ_CONFIGFILE_GENERAL}
        export HQ_CONFIGFILE_MSP
    fi

    # Variables
    tdw_count_total="$(grep -m 1 "^tdw_count_total=" ${HQ_CONFIGFILE_MSP} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
    tds_count_total="$((tdw_count_total+1))" # Config file setup

    # Preparing the corresponding tasks for this MSP
    echo -e " * Preparing the tasks for MSP ${msp_name}..."
    if [[ "${command_general}" == *"TDS"* ]]; then
        echo "   * Preparing one task for each TDS..."
        for tds_id in $(seq 1 ${tds_count_total}); do
            echo "     * Preparing the task for TDS ${tds_id}/${tds_count_total}..."
            command_specific="${command_general// MSP / ${msp_name} }"
            command_specific="${command_specific//TDS/${tds_id}:${tds_id}}"
            hq_bs_prepare_one_task.sh "${command_specific}" "${output_filename}"
        done
    else
        command_specific="${command_general// MSP / ${msp_name} }"
        hq_bs_prepare_one_task.sh "${command_specific}" "${output_filename}"
    fi

    # Formatting screen output
    echo
done < ${msp_list_file}

echo -e "\n * All tasks have been prepared.\n\n"
