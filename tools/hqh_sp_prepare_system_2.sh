#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_system_2.sh <ligand_basename> <subsystem>

Should be run in the root folder."

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

# Config file setup
if [[ -z "${HQ_CONFIGFILE_GENERAL}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_GENERAL was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_GENERAL=input-files/config/general.txt
    export HQ_CONFIGFILE_GENERAL
fi

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
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
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Adjusting the pdb and psf files
cd input-files/systems/${ligand_basename}/${subsystem}
echo -e "\n *** Patching the pdb and psf files (hqh_sp_patch_pdb_psf.sh) ***"
hqh_sp_patch_pdb_psf.sh system_complete.reduced

# Preparing the special atoms
# uatoms
echo -e "\n *** Determining the uatoms indices (prepare_uatoms_files.vmd) ***"
vmdc ${dirname}/hqh_sp_prepare_uatoms_files.vmd -args system_complete.reduced ${subsystem}
echo -e "\n *** Preparing the uatoms indices (hqh_sp_prepare_uatoms_files.sh) ***"
hqh_sp_prepare_uatoms_files.sh system_complete.reduced

# qatoms
echo -e "\n *** Determining the qatom indices (hqh_sp_prepare_qatom_files.vmd) ***"
vmdc ${dirname}/hqh_sp_prepare_qatom_files.vmd -args system_complete.reduced ${subsystem}
echo -e "\n *** Preparing the qatom indices (hqh_sp_prepare_qatom_files.sh) ***"
hqh_sp_prepare_qatom_files.sh system_complete.reduced

# Preparing the pdbx file
echo -e "\n *** Preparing the pdbx files for i-Qi (hqh_sp_prepare_pdbx.py) ***"
hqh_sp_prepare_pdbx.py system_complete.reduced.all.uatoms.indices system_complete.reduced.all.qatoms.indices system_complete.reduced.pdb

cd ../../../../

