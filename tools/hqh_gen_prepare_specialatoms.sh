#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_gen_prepare_specialatoms.sh <pdbx file> <outputfile basename>

The indices in the output files are their position in the pdbx file starting at 1. This corresponds to the serial in VMD".

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

# Config file setup
if [[ -z "${HQ_CONFIGFILE_MSP}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_MSP was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_MSP=input-files/config/general.txt
    export HQ_CONFIGFILE_MSP
fi

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "2" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 2"
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

# Variables
pdbx_file="$1"
outputfile_basename="$2"
index=1  # is the serial in VMD (index+1)

# Creating empty files (wiping existing files)
echo -n "" > ${outputfile_basename}.matoms
echo -n "" > ${outputfile_basename}.qatoms
echo -n "" > ${outputfile_basename}.uatoms
echo -n "" > ${outputfile_basename}.catoms

# Loop for each atom
while IFS= read -r line; do
    if ! [ "${line:0:5}" == "ATOM " ]; then
        continue
    else
        qm_type=${line:80:1}
        if [ "${qm_type}" == "M" ]; then
            echo -n "${index} " >> ${outputfile_basename}.matoms
        elif [ "${qm_type}" == "Q" ]; then
            echo -n "${index} ">> ${outputfile_basename}.qatoms
        else
            echo -e "\nError in the pdbx file ${pdbx_file}, wrong MQ atom type."
            exit 1
        fi

        constraint_type=${line:81:1}
        if [ "${constraint_type}" == "U" ]; then
            echo -n "${index} " >> ${outputfile_basename}.uatoms
        elif [ "${constraint_type}" == "C" ]; then
            echo -n "${index} " >> ${outputfile_basename}.catoms
        else
            echo -e "\nError in the pdbx file ${pdbx_file}, wrong constraint (UC) atom type."
            exit 1
        fi

        index=$((index+1))
    fi
done < "${pdbx_file}"