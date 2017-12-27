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

# Variables
line=$(grep -m 1 "^batchsystem=" ${HQ_CONFIGFILE_GENERAL})
batchsystem="${line/batchsystem=}"

# Determining the batchsystem
if [ "${batchsystem}" == "slurm" ]; then
    sacct -ojobid%15,ncpus,jobname%70,partition,state 2>&1 | grep  "^ \+[0-9]\+" | grep -v "^ \+[0-9]\+\."          # On Odyssey this is needed to filter out all the associated job steps (internal and regular job steps, because we only want infos about the main jobs)
    #squeue -o "%.18i %.9P %.70j %.8u %.8T %.10M %.9l %.6D %R" | grep ${USER:0:8}
elif [ "${batchsystem}" == "mtp" ]; then
    qstat | grep ${USER:0:8} | grep -v " C "
elif [ "${batchsystem}" == "lsf" ]; then
    bjobs | grep ${USER:0:8}
elif [ "${batchsystem}" == "sge" ]; then
    qstat | grep ${USER:0:8}
else
    echo -e " * Unsupported batchsystem (${batchsystem}) specified in the file ${HQ_CONFIGFILE_GENERAL}. Exiting... \n\n"
    exit 1
fi
