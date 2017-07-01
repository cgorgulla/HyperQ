#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_prepare_waterbox_L.sh <ligand file basename> <output file basename>

Required ligand files: pdb and rtf file."

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

# Variables
script_dir=$(dirname $0)
ligand_basename=$1
output_basename=$2
padding_size="$(grep -m 1 "^box_padding_size_L="  ../../../config.txt | awk -F '=' '{print $2}')"

# This is done with solvent because of box size which is needed. We later use only the nonsolvated structure
vmdc "${script_dir}/hqh_sp_prepare_waterbox_LS.vmd" -args $ligand_basename $output_basename ${script_dir} ${padding_size}

# Patching the output files
cp system_nosolv.pdb system_complete.pdb
cp system_nosolv.psf system_complete.psf
sed -i "s/PRT   $/PRT  H/g" system_complete.pdb
line_cryst=$(grep CRYST1 system_wb.pdb)
sed -i "s/REMARK.*/${line_cryst}/" system_complete.pdb 
sed -i "s/LIG     1/LIG L   1/g" system_complete.pdb
