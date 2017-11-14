#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_fes_prepare_one_fes_common.sh <nbeads> <tdw_count> <system 1 basename> <system 2 basename> <subsystem type> <simulation type> <simulation programs>

<tdw_count> is the number of TD windows (minimal value is 1).

<subsystem>: Possible values: L, LS, RLS

The <simulation type> Possible values: MM, QMMM

Has to be run in the system root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "7" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 7"
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
            touch runtime/${HQ_STARTDATE}/error.hq
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

# Variables
nbeads="${1}"
tdw_count="${2}"
tds_count="$((tdw_count + 1))"
system_1_basename="${3}"
system_2_basename="${4}"
subsystem=${5}
msp_name=${system_1_basename}_${system_2_basename}
sim_type=${6}
sim_programs=${7}

# Copying the kind files
cp ../../../input-files/cp2k/cp2k.in.sub.* ./

# Preparing the mapping files
echo -e " * Preparing the cp2k mapping files"
hqh_fes_prepare_jointsystem.py system1.pdb system2.pdb system.mcs.mapping
grep -v "&END MAPPING" cp2k.in.mapping.single > cp2k.in.mapping.double
grep  -A 100000 "FORCE_EVAL 1" cp2k.in.mapping.single | sed "s/FORCE_EVAL 1/FORCE_EVAL 3/g" | sed "s/FORCE_EVAL 2/FORCE_EVAL 4/g" >> cp2k.in.mapping.double
echo -e " * Preparing the human readable mapping file"
hqh_fes_prepare_human_mapping.py system1.pdb system2.pdb system.mcs.mapping

# Preparing the files for the dummy atoms
echo -e " * Preparing the cp2k dummy files"
hqh_fes_prepare_cp2k_dummies.py system1 system2
# Preparing the cp2k psf file for system 1
echo -e " * Preparing the cp2k psf file for system 1"
hqh_fes_prepare_cp2k_psf.py system1.vmd.psf system1.cp2k.psf
# Preparing the cp2k psf file for system 2
echo -e " * Preparing the cp2k psf file for system 2"
hqh_fes_prepare_cp2k_psf.py system2.vmd.psf system2.cp2k.psf
# Preparing the cp2k psf file for the dummy atoms of system 1
echo -e " * Preparing the cp2k psf file for the dummy atoms of system 1"
hqh_fes_prepare_cp2k_psf_dummy.py system1.vmd.psf system1.dummy.psf
# Preparing the cp2k psf file for the dummy atoms of system 2
echo -e " * Preparing the cp2k psf file for the dummy atoms of system 2"
hqh_fes_prepare_cp2k_psf_dummy.py system2.vmd.psf system2.dummy.psf


# System 1
echo -e " * Preparing the cp2k qm_kind file for system 1"
hqh_gen_prepare_cp2k_qm_kind.sh ../../../input-files/systems/${system_1_basename}/${subsystem}/system_complete.reduced.all.qatoms.elements.*
mv cp2k.in.qm_kinds cp2k.in.qm_kinds.system1
# System 2
echo -e " * Preparing the cp2k qm_kind file for system 2"
# Copying and adjusting the qatoms indices
echo -e " * Copying and adjusting the qatoms indices"
atom_count_ligand1=$(grep " LIG " system1.pdb | wc -l)
atom_count_ligand2=$(grep " LIG " system2.pdb | wc -l)
atom_count_difference1="$(( atom_count_ligand2 - atom_count_ligand1 ))"
atom_count_ligand_system=$(grep " LIG " system.a1c1.pdb | wc -l)
atom_count_difference2="$(( atom_count_ligand_system - atom_count_ligand1 ))"

# Copying the nonsolvent qatom indices of system 1
if [ -z "$(cat ../../../input-files/systems/${system_1_basename}/${subsystem}/system_complete.reduced.nonsolvent.qatoms.indices | tr -d "[:space:]" )" ]; then
    echo -e " * Info: No QM atoms (among nonsolvent atoms) in system ${system_1_basename}."
else
    for file in ../../../input-files/systems/${system_1_basename}/${subsystem}/system_complete.reduced.nonsolvent.qatoms.elements.*; do
        element=${file/.indices}
        element=${element/*.}
        cp $file system1.nonsolvent.qatoms.elements.${element}.indices
    done
fi

# Copying the nonsolvent qatom indices of system 2
if [ -z "$(cat ../../../input-files/systems/${system_2_basename}/${subsystem}/system_complete.reduced.nonsolvent.qatoms.indices | tr -d "[:space:]" )" ]; then
    echo -e " * Info: No QM atoms (among nonsolvent atoms) in system ${system_2_basename}."
else
    for file in ../../../input-files/systems/${system_2_basename}/${subsystem}/system_complete.reduced.nonsolvent.qatoms.elements.*; do
        element=${file/.indices}
        element=${element/*.}
        cp $file system2.nonsolvent.qatoms.elements.${element}.indices
    done
fi

# Copying the nonsolvent qatom indices of system 1 and generating the indices for system 2 from them
if [ -z "$(cat ../../../input-files/systems/${system_1_basename}/${subsystem}/system_complete.reduced.solvent.qatoms.indices | tr -d "[:space:]" )" ]; then
    echo -e " * Info: No QM atoms (among solvent atoms) in system ${system_1_basename}."
else
    for file in ../../../input-files/systems/${system_1_basename}/${subsystem}/system_complete.reduced.solvent.qatoms.elements.*; do
        element=${file/.indices}
        element=${element/*.}
        cp $file system1.solvent.qatoms.elements.${element}.indices
        cat system1.solvent.qatoms.elements.${element}.indices | tr " " "\n" | awk -v a="$atom_count_difference1" '{print $1 + a}' | tr "\n" " " > system2.solvent.qatoms.elements.${element}.indices
    done
fi

# Preparing the cp2k qm_kind input files
hqh_gen_prepare_cp2k_qm_kind.sh system2.nonsolvent.qatoms.elements.* system2.solvent.qatoms.elements.*.indices
mv cp2k.in.qm_kinds cp2k.in.qm_kinds.system2

# Preparing the QMMM files for CP2K
hqh_gen_prepare_cp2k_qmmm.py "system1"
hqh_gen_prepare_cp2k_qmmm.py "system2"

# Preparing the joint pdbx file (not just for iqi)
hqh_gen_prepare_pdbx.py system1.pdb system2.pdb system.mcs.mapping

# Preparing the special atom types (for analysis purposes only)
hqh_gen_prepare_special_atoms.sh system.a1c1.pdbx system.a1c1