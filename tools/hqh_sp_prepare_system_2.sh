#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_system_2.sh <ligand_basename> <subsystem>

Should be run in the root folder."

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
if [ "${2}" == "-h" ]; then
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

# Printing some information
echo
echo
echo "   Preparing the entire system for ligand ${1} (hqh_sp_prepare_system_2.sh)   "
echo "************************************************************************************"

# Variables
dirname=$(dirname $0)
ligand_basename=${1}
subsystem=${2}
opt_programs="$(grep -m 1 "^opt_programs=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type=" input-files/config.txt | awk -F '=' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"

# Adjusting the pdb and psf files
cd input-files/systems/${ligand_basename}/${subsystem}
echo -e "\n *** Patching the pdb and psf files (hqh_sp_patch_pdb_psf.sh) ***"
hqh_sp_patch_pdb_psf.sh system_complete.reduced

# Preparing the special atoms
# qatoms
if [[ "${opt_type}" == *"QMMM"* || "${md_type}" == *"QMMM"* ]]; then
    echo -e "\n *** Determining the qatom indices (hqh_sp_prepare_qatom_files.vmd) ***"
    vmdc ${dirname}/hqh_sp_prepare_qatom_files.vmd -args system_complete.reduced ${subsystem}
    echo -e "\n *** Preparing the qatom indices (hqh_sp_prepare_qatom_files.sh) ***"
    hqh_sp_prepare_qatom_files.sh system_complete.reduced

    echo -e "\n *** Determining the uatom indices (prepare_uatom_files.vmd) ***"
    vmdc ${dirname}/hqh_sp_prepare_qatom_files.vmd -args system_complete.reduced ${subsystem}then

    echo -e "\n *** Preparing the uatom indices (hqh_sp_prepare_uatom_files.sh) ***"
    hqh_sp_prepare_uatom_files.sh system_complete.reduced

    echo -e "\n *** Preparing the pdbx files for i-Qi (hqh_sp_prepare_pdbx.py) ***"
    hqh_sp_prepare_pdbx.py system_complete.reduced.all.uatoms.indices system_complete.reduced.all.qatoms.indices system_complete.reduced.pdb
fi

cd ../../../../

