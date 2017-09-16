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
    echo "Reason: The wrong number of arguments were provided when calling the script."
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
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Checking if the file already exists
outputfile="cp2k.in.qm_kinds"
if [ -f "${outputfile}" ]; then
    rm ${outputfile}
fi

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