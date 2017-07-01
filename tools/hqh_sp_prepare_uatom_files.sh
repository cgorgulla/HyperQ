#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_prepare_uatom_files.sh <system basename>"

# Standard error response 
error_response_std() {
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Verbosity
if [ "${verbosity}" = "debug" ]; then
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
if [ "$#" -ne "1" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 1"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Variables
system_basename=${1}

# Preparing the uatoms
# Checking if number of indices > 0
if [ -z "$(cat ${system_basename}.all.uatoms.indices.0 2>/dev/null  | tr -d "[:space:]")" ]; then
    echo -e " * Info: No QM atoms (uatoms) in system ${system_basename}." 
    touch ${system_basename}.all.uatoms.indices 
    exit 0
else
    cat ${system_basename}.all.uatoms.indices.0 | tr " " "\n" | awk '{print ($1 + 1)}' | tr "\n" " " > ${system_basename}.all.uatoms.indices
fi

