#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_prepare_uatom_files.sh <system basename>"

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
if [ "$#" -ne "1" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
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
#if [ -z "$(cat ${system_basename}.all.uatoms.indices 2>/dev/null  | tr -d "[:space:]")" ]; then
if [ ! -f "${system_basename}.all.uatoms.indices" ]; then
    echo -e " * Info: No QM atoms (uatoms) in system ${system_basename}."
    touch "${system_basename}.all.uatoms.indices"
fi