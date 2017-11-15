#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_prepare_box_L.sh <ligand file basename> <output file basename>

Required ligand files: pdb and rtf file."

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
padding_size="$(grep -m 1 "^box_edge_length_L="  ../../../config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Preparing the box
vmdc "${script_dir}/hqh_sp_prepare_box_L.vmd" -args $ligand_basename $output_basename ${script_dir}

# Patching the output files
cp system_nosolv.pdb system_complete.pdb
cp system_nosolv.psf system_complete.psf
sed -i "s/RCP   $/RCP  H/g" system_complete.pdb
line_cryst="$(printf "CRYST1%9.3f%9.3f%9.3f%7.2f%7.2f%7.2f P 1           1" ${padding_size} ${padding_size} ${padding_size} 90 90 90)"
sed -i "s/REMARK.*/${line_cryst}/" system_complete.pdb 
sed -i "s/LIG     1/LIG L   1/g" system_complete.pdb
