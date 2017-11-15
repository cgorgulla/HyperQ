#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_prepare_waterbox_PLS.sh <protein basename> <ligand basename> <outputfile basename>

Required ligand files: pdb and rtf file.
Required protein files: pdb file."

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
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
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

# Variables
script_dir=$(dirname $0)
protein_basename=$1
ligand_basename=$2
output_basename=$3
waterbox_padding_size_RLS="$(grep -m 1 "^waterbox_padding_size_RLS=" ../../../config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Body
vmdc "${script_dir}/hqh_sp_prepare_waterbox_PLS.vmd" -args $protein_basename $ligand_basename $output_basename ${script_dir} $waterbox_padding_size_RLS
sed -i "s/RCP   $/RCP  H/g" system_complete.pdb
