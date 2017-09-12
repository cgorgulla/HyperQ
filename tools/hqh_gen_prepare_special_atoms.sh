#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_gen_prepare_special_atoms.sh <pdbx file> <outputfile basename>

The indeces in the output files are their position in the pdbx file starting at 1. This corresponds to the the serial in VMD".



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
trap 'error_response_std $LINENO' ERR

# Verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Checking the input paramters
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
    echo "Reason: The wrong number of arguments were provided when calling the script."
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

# Body
index=1  # is the serial in VMD (index+1)
while IFS= read -r line; do
    if ! [ "${line:0:5}" == "ATOM " ]; then
        continue
    else
        qm_type=${line:80:1}
        if [ "${qm_type}" == "M" ]; then
            echo -n "${index} " >> ${outputfile_basename}.m_atoms
        elif [ "${qm_type}" == "Q" ]; then
            echo -n "${index} ">> ${outputfile_basename}.q_atoms
        else
            echo -e "\nError in the pdbx file ${pdbx_file}, wrong MQ atom type."
            false
        fi

        constraint_type=${line:81:1}
        if [ "${constraint_type}" == "U" ]; then
            echo -n "${index} " >> ${outputfile_basename}.u_atoms
        elif [ "${constraint_type}" == "C" ]; then
            echo -n "${index} " >> ${outputfile_basename}.c_atoms
        else
            echo -e "\nError in the pdbx file ${pdbx_file}, wrong constraint (UC) atom type."
            false
        fi

        index=$((index+1))
    fi
done < "${pdbx_file}"