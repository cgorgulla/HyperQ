#!/usr/bin/env bash 

usage="Usage: hqh_gen_prepare_cp2k_qm_kind.sh <element indices file 1> <element indices file 2> ...

Has to be run in the simulation root folder."

if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -le "0" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: > 0"
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

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE_BS}/error.pipeline
            exit 1
        else
            cd ..
        fi
    done

    # Printing some information
    echo "Error: Cannot find the input-files directory..."
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Config file setup
if [[ -z "${HQ_CONFIGFILE_MSP}" ]]; then
    HQ_CONFIGFILE_MSP=input-files/config/general.txt
    export HQ_CONFIGFILE_MSP
fi

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Checking if the file already exists
outputfile="cp2k.in.qm_kinds"
if [ -f "${outputfile}" ]; then

    # If we cannot remove the file, some other process has already removed it in the meantime (on clusters there can be a delay of seconds)
    # In this case most likely a parallel running instance of this script of another single-TDS pipe
    if ! rm ${outputfile}; then

        # Sleeping sometime to disperse the possible parallel running processes
        sleep "$(shuf -i 1-120 -n 1)"
    fi
fi

# Creating/wiping the output file
echo -n "" > ${outputfile}

# Loop for each element index file
for file in $@; do
    element="$(echo $file | awk -F '.' '{print $(NF -1)}')"
    echo "&QM_KIND ${element}" >> ${outputfile}
    i=0
    for mm_index in $(cat ${file}); do 
        if [ "${i}" -eq "0" ]; then
            echo -n "  MM_INDEX " >> ${outputfile}
        fi
        echo -n "${mm_index} " >> ${outputfile}
        i=$((i+1))
        if [ "${i}" -eq "10" ]; then
            echo >> ${outputfile}
            i=0
        fi
    done
    if [ "${i}" -ne "0" ]; then
        echo >> ${outputfile}
        i=0
    fi
    echo "&END QM_KIND" >> ${outputfile}
done