#!/usr/bin/env bash 

usage="Usage: hqmd_opt_prepare_one_molecule.py <system basename> <subsystem type>

Has to be run in the root folder.\n
Possible subsystems are: L, LS, RLS.\n"

# Checking the input arguments
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
    touch runtime/${HQ_BS_STARTDATE}/error.hq
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
            touch runtime/${HQ_BS_STARTDATE}/error.hq
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

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity_runtime=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
system_basename="${1}"
subsystem=${2}
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Printing information
echo -e "\n *** Preparing the optimization folder for system ${system_basename} (hqmd_opt_prepare_one_ms.sh) *** "

# Creating required folders
echo -e " * Preparing the main folder"
mkdir -p opt/${system_basename}/${subsystem}
cd opt/${system_basename}/${subsystem}

# Copying the system files
echo -e " * Copying general simulation files"
system_ID=1
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.psf ./system${system_ID}.psf
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.pdb ./system${system_ID}.pdb
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${system_ID}.prm

# Getting the cell size for the opt program input files
line=$(grep CRYST1 system1.pdb)
IFS=' ' read -r -a line_array <<< "$line"
A=${line_array[1]}
B=${line_array[2]}
C=${line_array[3]}

# Preparation of the cp2k files
if [[ "${opt_programs}" == "cp2k" ]]; then
    echo -e " * Preparing the files and directories which are CP2K specific"
    if [ -d "opt/cp2k" ]; then
        rm -r opt/cp2k
    fi
    mkdir -p opt/cp2k
    inputfolder_cp2k_opt="$(grep -m 1 "^inputfolder_cp2k_opt_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt} opt/cp2k/cp2k.in.main
    sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" opt/cp2k/cp2k.in.main

    cp ../../../input-files/cp2k/cp2k.in.kind.* ./
fi

# Preparation of the NAMD files
if [[ "${opt_programs}" == *"namd"* ]]; then
    # Variables
    inputfile_namd_opt="$(grep -m 1 "^inputfile_namd_opt_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

    # Folders and files
    echo -e " * Preparing the files and directories which are NAMD specific"
    if [ -d "opt/namd" ]; then
        rm -r opt/namd
    fi
    mkdir -p opt/namd
    cp ../../../input-files/namd/${inputfile_namd_opt} opt/namd/namd.in.opt
    sed -i "s/cellBasisVector1 .*/cellBasisVector1 ${A} 0 0/g" opt/namd/namd.in.opt
    sed -i "s/cellBasisVector2 .*/cellBasisVector2 0 ${B} 0/g" opt/namd/namd.in.opt
    sed -i "s/cellBasisVector3 .*/cellBasisVector3 0 0 ${C}/g" opt/namd/namd.in.opt
fi



cd ../../../
