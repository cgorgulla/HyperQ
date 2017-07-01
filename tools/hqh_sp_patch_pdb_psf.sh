#!/usr/bin/env bash 

usage="Usage: hqh_sp_patch_pdb_psf.sh <file_basename>

This script patches the pdb and psf files corresponding to the basename.

Has to be run in the folder of the system in input-files/systems/..."

# Checking input arguments
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

# Patching the pdb file
echo "TITLE positions{angstrom} cell{angstrom}" > ${1}_new.pdb
cat ${1}.pdb >> ${1}_new.pdb
mv ${1}_new.pdb ${1}.pdb

# Patching the psf file
sed -i "s/CMAP//g" ${1}.psf
