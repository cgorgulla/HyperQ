#!/usr/bin/env bash 

usage="Usage: hqmd_md_prepare_one_molecule.py <system basename> <subsystem type>

Has to be run in the root folder.

Possible subsystems are: L, LS, RLS."

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

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
system_basename="${1}"
subsystem="${2}"
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')"
md_folder="md"

# Printing information
echo -e "\n *** Preparing the MD simulation ${system_basename} (hqmd_md_prepare_one_ms.sh) "

# Creating required folders
echo -e " * Preparing the main folder"
mkdir -p md/${system_basename}/${subsystem}
cd md/${system_basename}/${subsystem}
mkdir -p ${md_folder}

# Copying the system files
echo -e " * Copying general simulation files"
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.psf ./system1.psf
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.pdb ./system1.pdb
cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system1.prm
#if [ ${md_type^^} == "QMMM" ]; then
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.pdbx ./system1.pdbx
#fi

# Getting the cell size in the cp2k input files
line=$(grep CRYST1 system1.pdb)
IFS=' ' read -r -a lineArray <<< "$line"
A=${lineArray[1]}
B=${lineArray[2]}
C=${lineArray[3]}  

# Copying the geo-opt coordinate file
cp ../../../opt/${system_basename}/${subsystem}/system1.opt.out.pdb ./

# Preparation of the CP2K files
if [[ "${md_programs}" == *"cp2k"* ]]; then
    # Variables
    inputfolder_cp2k_opt="$(grep -m 1 "^inputfolder_cp2k_opt_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
    inputfolder_cp2k_md="$(grep -m 1 "^inputfolder_cp2k_md_${subsystem}="  ../../../input-files/config.txt | awk -F '=' '{print $2}')"
    nbeads="$(grep -m 1 "^nbeads"  ../../../input-files/config.txt | awk -F '=' '{print $2}')"

    # Folders
    echo -e " * Preparing the files and directories which are cp2k specific"
    if [ -d "${md_folder}/cp2k" ]; then
        rm -r ${md_folder}/cp2k
    fi
    mkdir ${md_folder}/cp2k
    for bead in $(seq 1 ${nbeads}); do
        mkdir ${md_folder}/cp2k/bead-${bead}
    done
    # Preparing the bead folders
    for bead in $(seq 1 ${nbeads}); do
        cp ../../../input-files/cp2k/${inputfolder_cp2k_md} ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
        sed -i "s/system_basename/${system_basename}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
        sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
        sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
    done

    # Copying the kind files
    cp ../../../input-files/cp2k/cp2k.in.kind.* ./

    # Preparing the QM/MM files
    # QM/MM qm_kind files
    echo -e " * Preparing the cp2k QM/MM qm_kind file for system 1"
    hqh_gen_prepare_cp2k_qm_kind.sh ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.all.qatoms.elements.*
    mv cp2k.in.qm_kinds cp2k.in.qm_kinds.system1

    # Preparing the remaining QMMM files for CP2K
    hqh_gen_prepare_cp2k_qmmm.py "system1"
fi

# Preparation of the ipi files
if [[ "${md_programs}" == *"ipi"* ]]; then
    # Variables
    inputfile_ipi_md="$(grep -m 1 "^inputfile_ipi_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

    # Folders ans files
    echo -e " * Preparing the files and directories which are i-PI specific"
    if [ -d "${md_folder}/ipi" ]; then
        rm -r ${md_folder}/ipi
    fi
    mkdir ${md_folder}/ipi
    cp ../../../input-files/ipi/${inputfile_ipi_md} ${md_folder}/ipi/ipi.in.main.xml
    sed -i "s/system_basename/${system_basename}/g" ${md_folder}/ipi/ipi.in.main.xml
    sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/ipi/ipi.in.main.xml
fi

# Preparation of the iqi files
if [[ "${md_programs}" == *"iqi"* ]]; then
    # Variables
    inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
    inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

    # Folders and files
    echo -e " * Preparing the files and directories which are i-QI specific"
    if [ -d "${md_folder}/iqi" ]; then
        rm -r ${md_folder}/iqi
    fi

    mkdir ${md_folder}/iqi
    cp ../../../input-files/iqi/${inputfile_iqi_md} ${md_folder}/iqi/iqi.in.xml
    sed -i "s/system_basename/${system_basename}/g" ${md_folder}/iqi/iqi.in.xml
    sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/iqi/iqi.in.xml
    cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${md_folder}/iqi/
fi

# Preparation of the NAMD files
if [[ "${md_programs}" == *"namd"* ]]; then
    # Variables
    inputfile_namd_md="$(grep -m 1 "^inputfile_namd_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

    # Folders and files
    echo -e " * Preparing the files and directories which are NAMD specific"
    if [ -d "${md_folder}/namd" ]; then
        rm -r ${md_folder}/namd
    fi
    mkdir ${md_folder}/namd
    cp ../../../input-files/namd/${inputfile_namd_md} ${md_folder}/namd/namd.in.md
    sed -i "s/cellBasisVector1 .*/cellBasisVector1 ${A} 0 0/g" ${md_folder}/namd/namd.in.md
    sed -i "s/cellBasisVector2 .*/cellBasisVector2 0 ${B} 0/g" ${md_folder}/namd/namd.in.md
    sed -i "s/cellBasisVector3 .*/cellBasisVector3 0 0 ${C}/g" ${md_folder}/namd/namd.in.md
fi

cd ../../../