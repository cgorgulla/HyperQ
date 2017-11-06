#!/usr/bin/env bash 

# Usage information
usage="Usage: hqmdh_sp_prepare_system_2.sh <ligand_basename> <subsystem>

Should be run in the root folder."

# Checking the input parameters
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

# Bash options
set -o pipefail

# Verbosity
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Printing some information
echo
echo
echo
line_to_print="   Preparing the entire system for ligand ${1} (hqmdh_sp_prepare_system_2.sh)   "
echo "$line_to_print"
line_to_print_charno=$(echo -n "$line_to_print" | wc -m)
printf '%0.s*' $(seq 1 $line_to_print_charno)
echo

# Variables
dirname=$(dirname $0)
ligand_basename=${1}
subsystem=${2}
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"

# Adjusting the pdb and psf files
cd input-files/systems/${ligand_basename}/${subsystem}
echo -e "\n *** Patching the pdb and psf files (hqh_sp_patch_pdb_psf.sh) ***"
hqh_sp_patch_pdb_psf.sh system_complete

# Preparing the special atoms
echo -e "\n *** Preparing the uatom files (hqh_sp_prepare_uatom_files.vmd) ***"
vmdc ${dirname}/hqh_sp_prepare_uatom_files.vmd -args system_complete ${subsystem}
echo -e "\n *** Preparing the uatom files (hqh_sp_prepare_uatom_files.sh) ***"
hqh_sp_prepare_uatom_files.sh system_complete

echo -e "\n *** Preparing the qatom files (hqh_sp_prepare_qatom_files.vmd) ***"
vmdc ${dirname}/hqh_sp_prepare_qatom_files.vmd -args system_complete ${subsystem}
echo -e "\n *** Preparing the qatom indices (hqh_sp_prepare_qatom_files.sh) ***"
hqh_sp_prepare_qatom_files.sh system_complete


# Preparing the pdbx file
echo -e "\n *** Preparing the pdbx files for i-Qi (hqh_sp_prepare_pdbx.py) ***"
hqh_sp_prepare_pdbx.py system_complete.all.uatoms.indices system_complete.all.qatoms.indices system_complete.pdb

cd ../../../../

