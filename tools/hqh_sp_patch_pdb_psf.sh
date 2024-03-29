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

# Patching the pdb file
echo "TITLE positions{angstrom} cell{angstrom}" > ${1}_new.pdb
cat ${1}.pdb >> ${1}_new.pdb
mv ${1}_new.pdb ${1}.pdb

# Ceiling the box size to the next 0.1 Angstrom unit (CP2K made problems one time when the box was too tight)
cryst_line="$(grep "^CRYST" ${1}.pdb)"
size_x_old=$(echo ${cryst_line:6:9} | tr -d "[[:space:]]")
size_y_old=$(echo ${cryst_line:15:9} | tr -d "[[:space:]]")
size_z_old=$(echo ${cryst_line:24:9} | tr -d "[[:space:]]")
# size_x_new=$(awk -v x="${size_x_old}" 'BEGIN{printf("%.f", x+0.5)}')
# size_y_new=$(awk -v y="${size_y_old}" 'BEGIN{printf("%.f", y+0.5)}')
# size_z_new=$(awk -v z="${size_z_old}" 'BEGIN{printf("%.f", z+0.5)}')
size_x_new=$(awk -v x="${size_x_old}" 'BEGIN{printf("%9.1f", x+0.1)}')
size_y_new=$(awk -v y="${size_y_old}" 'BEGIN{printf("%9.1f", y+0.1)}')
size_z_new=$(awk -v z="${size_z_old}" 'BEGIN{printf("%9.1f", z+0.1)}')
cryst_line_new="$(printf "CRYST1%9.3f%9.3f%9.3f%7.2f%7.2f%7.2f P 1           1" ${size_x_new} ${size_y_new} ${size_z_new} 90 90 90)"
sed -i "s/CRYST.*/${cryst_line_new}/" ${1}.pdb
echo "size_x: ${size_x_new}" > cell.dimensions
echo "size_y: ${size_y_new}" >> cell.dimensions
echo "size_z: ${size_z_new}" >> cell.dimensions

# Patching the psf file
sed -i "s/CMAP//g" ${1}.psf
#sed -i "s/^PSF EXT/PSF/g" ${1}.psf