#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_prepare_waterbox_LS.sh <ligand file basename> <output file basename>

Required ligand files: pdb and rtf file.

Has to be run in the folder where the files are present."

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

# Config file setup
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
waterbox_padding_size_LS="$(grep -m 1 "^waterbox_padding_size_LS="  ../../../../${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Body
vmdc "${script_dir}/hqh_sp_prepare_waterbox_LS.vmd" -args $ligand_basename $output_basename ${script_dir} ${waterbox_padding_size_LS}
sed -i "s/RCP   $/RCP  H/g" ${output_basename}_wb.pdb
mv ${output_basename}_wb.pdb ${output_basename}_complete.pdb
mv ${output_basename}_wb.psf system_complete.psf