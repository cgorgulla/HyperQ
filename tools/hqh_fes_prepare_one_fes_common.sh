#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_fes_prepare_one_fes_common.sh

Has to be run in the subsystem folder of the MSP."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "0" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 0"
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

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE_BS}/error.pipeline
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

# Config file setup
if [[ -z "${HQ_CONFIGFILE_MSP}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_MSP was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_MSP=input-files/config/general.txt
    export HQ_CONFIGFILE_MSP
fi

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
runtype="$(pwd | awk -F '/' '{print $(NF-2)}')"
sim_type="$(grep -m 1 "^${runtype}_type_${subsystem}=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$((tdw_count_total + 1))"
system_1_basename="${msp_name/_*}"
system_2_basename="${msp_name/*_}"

# Copying the kind files
cp ../../../input-files/cp2k/cp2k.in.sub.* ./ || true    # Parallel robustness

# Preparing the mapping files
echo -e " * Preparing the cp2k mapping files"

## Preparing the elementary mapping files
hqh_fes_prepare_jointsystem.py system1.pdb system2.pdb system.mcs.mapping

## Assembling the full mapping files
### Assembling the mapping file cp2k.in.mapping.m112toJoint
echo "&MAPPING" > cp2k.in.mapping.m112toJoint
echo "  &FORCE_EVAL_MIXED" >> cp2k.in.mapping.m112toJoint
cat cp2k.in.mapping.mixed >> cp2k.in.mapping.m112toJoint
echo "  &END FORCE_EVAL_MIXED" >> cp2k.in.mapping.m112toJoint
echo "  &FORCE_EVAL 1" >> cp2k.in.mapping.m112toJoint
cat cp2k.in.mapping.1toJoint >> cp2k.in.mapping.m112toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112toJoint
echo "  &FORCE_EVAL 2" >> cp2k.in.mapping.m112toJoint
cat cp2k.in.mapping.1toJoint >> cp2k.in.mapping.m112toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112toJoint
echo "  &FORCE_EVAL 3" >> cp2k.in.mapping.m112toJoint
cat cp2k.in.mapping.2toJoint >> cp2k.in.mapping.m112toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112toJoint
echo "&END MAPPING" >> cp2k.in.mapping.m112toJoint

## Assembling the full mapping files
### Assembling the mapping file cp2k.in.mapping.m122toJoint
echo "&MAPPING" > cp2k.in.mapping.m122toJoint
echo "  &FORCE_EVAL_MIXED" >> cp2k.in.mapping.m122toJoint
cat cp2k.in.mapping.mixed >> cp2k.in.mapping.m122toJoint
echo "  &END FORCE_EVAL_MIXED" >> cp2k.in.mapping.m122toJoint
echo "  &FORCE_EVAL 1" >> cp2k.in.mapping.m122toJoint
cat cp2k.in.mapping.1toJoint >> cp2k.in.mapping.m122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m122toJoint
echo "  &FORCE_EVAL 2" >> cp2k.in.mapping.m122toJoint
cat cp2k.in.mapping.2toJoint >> cp2k.in.mapping.m122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m122toJoint
echo "  &FORCE_EVAL 3" >> cp2k.in.mapping.m122toJoint
cat cp2k.in.mapping.2toJoint >> cp2k.in.mapping.m122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m122toJoint
echo "&END MAPPING" >> cp2k.in.mapping.m122toJoint

## Assembling the full mapping files
### Assembling the mapping file cp2k.in.mapping.m112122toJoint
echo "&MAPPING" > cp2k.in.mapping.m112122toJoint
echo "  &FORCE_EVAL_MIXED" >> cp2k.in.mapping.m112122toJoint
cat cp2k.in.mapping.mixed >> cp2k.in.mapping.m112122toJoint
echo "  &END FORCE_EVAL_MIXED" >> cp2k.in.mapping.m112122toJoint
echo "  &FORCE_EVAL 1" >> cp2k.in.mapping.m112122toJoint
cat cp2k.in.mapping.1toJoint >> cp2k.in.mapping.m112122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112122toJoint
echo "  &FORCE_EVAL 2" >> cp2k.in.mapping.m112122toJoint
cat cp2k.in.mapping.1toJoint >> cp2k.in.mapping.m112122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112122toJoint
echo "  &FORCE_EVAL 3" >> cp2k.in.mapping.m112122toJoint
cat cp2k.in.mapping.2toJoint >> cp2k.in.mapping.m112122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112122toJoint
echo "  &FORCE_EVAL 4" >> cp2k.in.mapping.m112122toJoint
cat cp2k.in.mapping.1toJoint >> cp2k.in.mapping.m112122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112122toJoint
echo "  &FORCE_EVAL 5" >> cp2k.in.mapping.m112122toJoint
cat cp2k.in.mapping.2toJoint >> cp2k.in.mapping.m112122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112122toJoint
echo "  &FORCE_EVAL 6" >> cp2k.in.mapping.m112122toJoint
cat cp2k.in.mapping.2toJoint >> cp2k.in.mapping.m112122toJoint
echo "  &END FORCE_EVAL" >> cp2k.in.mapping.m112122toJoint
echo "&END MAPPING" >> cp2k.in.mapping.m112122toJoint


# Preparing the CP2K dummy atom files
echo -e " * Preparing the cp2k dummy files"
hqh_fes_prepare_cp2k_dummies.py system1 system1.vmd.psf system1.prm system1.dummy.indices
hqh_fes_prepare_cp2k_dummies.py system2 system2.vmd.psf system2.prm system2.dummy.indices
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
mv cp2k.in.qm_kinds cp2k.in.qm_kinds.system1 || true    # Parallel robustness
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
        cp $file system1.nonsolvent.qatoms.elements.${element}.indices || true    # Parallel robustness
    done
fi

# Copying the nonsolvent qatom indices of system 2
if [ -z "$(cat ../../../input-files/systems/${system_2_basename}/${subsystem}/system_complete.reduced.nonsolvent.qatoms.indices | tr -d "[:space:]" )" ]; then
    echo -e " * Info: No QM atoms (among nonsolvent atoms) in system ${system_2_basename}."
else
    for file in ../../../input-files/systems/${system_2_basename}/${subsystem}/system_complete.reduced.nonsolvent.qatoms.elements.*; do
        element=${file/.indices}
        element=${element/*.}
        cp $file system2.nonsolvent.qatoms.elements.${element}.indices || true    # Parallel robustness
    done
fi

# Copying the nonsolvent qatom indices of system 1 and generating the indices for system 2 from them
if [ -z "$(cat ../../../input-files/systems/${system_1_basename}/${subsystem}/system_complete.reduced.solvent.qatoms.indices | tr -d "[:space:]" )" ]; then
    echo -e " * Info: No QM atoms (among solvent atoms) in system ${system_1_basename}."
else
    for file in ../../../input-files/systems/${system_1_basename}/${subsystem}/system_complete.reduced.solvent.qatoms.elements.*; do
        element=${file/.indices}
        element=${element/*.}
        cp $file system1.solvent.qatoms.elements.${element}.indices || true    # Parallel robustness
        cat system1.solvent.qatoms.elements.${element}.indices | tr " " "\n" | awk -v a="$atom_count_difference1" '{print $1 + a}' | tr "\n" " " > system2.solvent.qatoms.elements.${element}.indices
    done
fi

# Preparing the CP2k qm_kind input files
hqh_gen_prepare_cp2k_qm_kind.sh system2.nonsolvent.qatoms.elements.* system2.solvent.qatoms.elements.*.indices
mv cp2k.in.qm_kinds cp2k.in.qm_kinds.system2 || true    # Parallel robustness

# Preparing the QMMM files for CP2K
hqh_gen_prepare_cp2k_qmmm.py "system1" "system1.vmd.psf" "system1.prm" "system1.pdbx"
hqh_gen_prepare_cp2k_qmmm.py "system2" "system2.vmd.psf" "system2.prm" "system2.pdbx"

# Preparing the joint pdbx file (not only for iqi)
hqh_fes_prepare_jointpdbx.py system1.pdb system2.pdb system.mcs.mapping

# Preparing the TDS structure files
hqh_fes_prepare_tds_structure_files.sh

# Preparing the special atom types (for analysis purposes only)
hqh_gen_prepare_specialatoms.sh system.a1c1.pdbx system.a1c1