#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_prepare_waterbox_LS.sh <ligand file basename> <output file basename>

Required ligand files: pdb and rtf file."

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
if [ "${HQ_VERBOSITY}" = "debug" ]; then
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

# Variables
script_dir=$(dirname $0)
ligand_basename=$1
output_basename=$2
waterbox_padding_size_LS="$(grep -m 1 "^waterbox_padding_size_LS="  ../../../config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Body
vmdc "${script_dir}/hqh_sp_prepare_waterbox_LS.vmd" -args $ligand_basename $output_basename ${script_dir} ${waterbox_padding_size_LS}
sed -i "s/RCP   $/RCP  H/g" system_wb.pdb
mv system_wb.pdb system_complete.pdb
mv system_wb.psf system_complete.psf