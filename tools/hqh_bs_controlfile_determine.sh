#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_bs_controlfile_determine.sh <job-type-letter> <job ID>

Determines which controlfile is responsible for the given JTL and JID, and prints the filename.

Arguments:
    <job-type-letter>: The job-type-letter corresponding to the jobs to be started (a lower case letter from a-j)

    <job ID>: The job ID, a natural number

Has to be run in the root folder."

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "2" ]; then
    echo 1>&2
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Reason: The wrong number of arguments was provided when calling the script." 1>&2
    echo "Number of expected arguments: 2" 1>&2
    echo "Number of provided arguments: ${#}" 1>&2
    echo "Provided arguments: $@" 1>&2
    echo 1>&2
    echo -e "$usage" 1>&2
    echo 1>&2
    echo 1>&2
    exit 1
fi

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

# Standard error response 
error_response_std() {
    # Printing some information
    echo 1>&2
    echo "An error was trapped" 1>&2
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
    echo "Exiting..." 1>&2
    echo 1>&2
    echo 1>&2

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail
shopt -s nullglob

# Variables
jtl=${1}
jid=${2}
controlfile=""

# Checking if the job type letter is valid
if ! [[ "${jtl}" =~ ^[abcdefghij]$ ]]; then

    # Printing some information
    echo -e "\n * Error: The input argument 'job type letter' has an unsupported value. Exiting...\n\n" 1>&2
    exit 1
fi

# Checking if the batchsystem/control folder is present
if ! [ -d batchsystem/control ]; then

    # Printing some information
    echo -e "\n * Error: The script has to be run in the root folder and the batchsystem folder has to be prepared already. Exiting...\n\n" 1>&2
    exit 1
fi

### Determining the control file

# Loop for each file of priority 1 (highest priority)
for file in batchsystem/control/*-*:*-*.ctrl; do

    # Variables
    file_basename=$(basename $file)
    jtl_range=$(echo ${file_basename} | awk -F '[:.]' '{print $1}')
    jtl_range_start=${jtl_range/-*}
    jtl_range_end=${jtl_range/*-}
    jid_range=$(echo ${file_basename} | awk -F '[:.]' '{print $2}')
    jid_range_start=${jid_range/-*}
    jid_range_end=${jid_range/*-}

    # Checking if the jtl range values are valid using Base36 to compare the characters
    if ! [ "$((36#${jtl_range_start}))" -le "$((36#${jtl_range_end}))" ] &>/dev/null; then

        # The filename seems to be of an invalid format
        echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..." 1>&2
        continue
    fi

    # Checking if the jid range values are valid
    if ! [ "${jid_range_start}" -le "${jid_range_end}" ]; then

        # The file seems to be of an invalid format
        echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..." 1>&2
        continue
    fi

    # Checking if our jid is contained in the specified jid range of the file
    if [[ "${jid_range_start}" -le "${jid}" && "${jid}" -le "${jid_range_end}" ]]; then

        # Checking if our jtl is contained in the specified jtl range of the file
        if [[ "$((36#${jtl_range_start}))" -le "$((36#${jtl}))" && "$((36#${jtl}))" -le "$((36#${jtl_range_end}))" ]]; then

            # Setting the control file
            controlfile=${file}

            # We are all set
            echo -n "${controlfile}"
            exit 0
        fi
    fi
done

# Loop for each file of priority 2
for file in batchsystem/control/all:*-*.ctrl; do

    # Variables
    file_basename=$(basename $file)
    jid_range=$(echo ${file_basename} | awk -F '[:.]' '{print $2}')
    jid_range_start=${jid_range/-*}
    jid_range_end=${jid_range/*-}

    # Checking if the jid range values are valid
    if ! [ "${jid_range_start}" -le "${jid_range_end}" ] 2>/dev/null; then

        # The file seems to be of an invalid format
        echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..." 1>&2
        continue
    fi

    # Checking if our jid is contained in the specified jid range of the file
    if [[ "${jid_range_start}" -le "${jid}" && "${jid}" -le "${jid_range_end}" ]]; then

        # Setting the control file
        controlfile=${file}

        # We are all set
        echo -n "${controlfile}"
        exit 0
    fi
done

# Loop for each file of priority 3
for file in batchsystem/control/*-*:all.ctrl; do

    # Variables
    file_basename=$(basename $file)
    jtl_range=$(echo ${file_basename} | awk -F '[:.]' '{print $1}')
    jtl_range_start=${jtl_range/-*}
    jtl_range_end=${jtl_range/*-}

    # Checking if the jtl range values are valid using Base36 to compare the characters
    if ! [ "$((36#${jtl_range_start}))" -le "$((36#${jtl_range_end}))" ] 2>/dev/null; then

        # The filename seems to be of an invalid format
        echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..." 1>&2
        continue
    fi

    # Checking if our jtl is contained in the specified jtl range of the file
    if [[ "$((36#${jtl_range_start}))" -le "$((36#${jtl}))" && "$((36#${jtl}))" -le "$((36#${jtl_range_end}))" ]]; then

        # Setting the control file
        controlfile=${file}

        # We are all set
        echo -n "${controlfile}"
        exit 0
    fi
done

# If we have still not found any control file, then the general all:all.ctrl file is responsible for us
# Checking if it is there
if [ -f batchsystem/control/all:all.ctrl ]; then
    controlfile="batchsystem/control/all:all.ctrl"
else

    # Printing some information before exiting...
    echo -e "Error: No control file could be found. Exiting...\n\n" 1>&2
    exit 1
fi

# Returning the determined controlfile
echo -n "${controlfile}"
