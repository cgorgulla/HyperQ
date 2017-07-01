#!/usr/bin/env bash 

usage="Usage: hqmd_opt_prepare_one_molecule.py <system basename> <subsystem type>

Has to be run in the root folder.\n
Possible subsystems are: L, LS, PLS.\n"

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
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
system_basename="${1}"
subsystem=${2}
opt_programs="$(grep -m 1 "^opt_programs=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type=" input-files/config.txt | awk -F '=' '{print $2}')"

# Printing information
echo -e "\n *** Preparing the optimization folder for system ${system_basename} (hqmd_opt_prepare_one_ms.sh) *** "

# Creating required folders
echo -e " * Preparing the main folder"
mkdir -p opt/${system_basename}/${subsystem}
cd opt/${system_basename}/${subsystem}

# Copying the system files
echo -e " * Copying general simulation files"
systemID=1
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.psf ./system${systemID}.psf
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.pdb ./system${systemID}.pdb
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${systemID}.prm

# Getting the cell size for the opt program input files
line=$(grep CRYST1 system1.pdb)
IFS=' ' read -r -a lineArray <<< "$line"
A=${lineArray[1]}
B=${lineArray[2]}
C=${lineArray[3]}

# Preparation of the cp2k files
if [[ "${opt_programs}" == "cp2k" ]]; then
    echo -e " * Preparing the files and directories which are CP2K specific"
    if [ -d "opt/cp2k" ]; then
        rm -r opt/cp2k
    fi
    mkdir -p opt/cp2k
    inputfile_cp2k_opt="$(grep -m 1 "^inputfile_cp2k_opt_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp ../../../input-files/cp2k/${inputfile_cp2k_opt} opt/cp2k/cp2k.in.opt
    sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" opt/cp2k/cp2k.in.opt

    cp ../../../input-files/cp2k/cp2k.in.kind.* ./
fi

# Preparation of the NAMD files
if [[ "${opt_programs}" == *"namd"* ]]; then
    # Variables
    inputfile_namd_opt="$(grep -m 1 "^inputfile_namd_opt_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

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
