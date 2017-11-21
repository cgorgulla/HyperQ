#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_LS.sh <ligand_basename>

Has to be run in the root folder."

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

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
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

# Variables
ligand_basename=${1}
dirname=$(dirname $0)
ligand_FFparameter_source="$(grep -m 1 "^ligand_FFparameter_source=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Printing some information
echo
echo
echo "   Preparing the entire system for ligand ${ligand_basename} (hqh_sp_prepare_LS.sh)   "
echo "************************************************************************************"

# Copying files, creating folders
echo -e "\n * Copying files and folders"
if [ -d input-files/systems/${ligand_basename}/LS ]; then
    rm -r input-files/systems/${ligand_basename}/LS
fi
mkdir -p input-files/systems/${ligand_basename}/LS
cd input-files/systems/${ligand_basename}/LS
cp ../../../ligands/pdb/${ligand_basename}.pdb ./${ligand_basename}.pdb


if [ "${ligand_FFparameter_source^^}" == "MATCH" ]; then

    # Assigning uniqe atom names
    echo -e "\n *** Assigning unique atom names (uniqe_atom_names_pdb.py) ***"
    hqh_sp_prepare_unique_atom_names_pdb.py ${ligand_basename}.pdb ${ligand_basename}_unique.pdb

    # Atom typing with MATCH - and unique atom names (required also by us regarding cp2k and dummy atoms)
    echo -e "\n * Atom typing with MATCH\n"
    #MATCH.pl -ExitifNotInitiated 0 -ExitifNotTyped 0 -ExitifNotCharged 0 ${ligand_basename}_unique.pdb
    #obabel -ipdb ${ligand_basename}_unique.pdb -osdf -O ${ligand_basename}_unique.sdf    # because of the bond orders,but that was because of the missing hydrogens
    MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 ${ligand_basename}_unique.pdb

    # Patching the prm file of MATCH
    # MATCH does not add the END statement which is needed by CP2K (in particular when joining multiple parameter files)
    echo "END" >> ${ligand_basename}_unique.prm

    mv top_${ligand_basename}_unique.rtf protein_ligand.rtf
    mv ${ligand_basename}_unique.pdb ${ligand_basename}_unique_typed.pdb
    mv ${ligand_basename}_unique.prm ${ligand_basename}_unique_typed.prm
    mv ${ligand_basename}_unique.rtf ${ligand_basename}_unique_typed.rtf
    echo
elif [ "${ligand_FFparameter_source^^}" == "FOLDER" ]; then
    cp ${ligand_basename}.pdb ${ligand_basename}_unique_typed.pdb
    cp ../../../ligands/FF/${ligand_basename}.rtf ${ligand_basename}_unique_typed.rtf
    cp ../../../ligands/FF/${ligand_basename}.prm ${ligand_basename}_unique_typed.prm
fi

# Creating the joint parameter file ligand
script_dir=$(dirname $0)
cp ${script_dir}/../common/charmm36/par_all36_prot_solvent.prm ./system_complete.prm
cat ${script_dir}/../common/charmm36/par_all36_cgenff.prm >> system_complete.prm
cat ${ligand_basename}_unique_typed.prm >> system_complete.prm

# Some parameter files seem to contain the section keyword IMPROPERS instead of IMPROPER, but CP2K only understands the latter)
sed -i "s/^IMPROPERS/IMPROPER/g" system_complete.prm
# Removing any return statements (from Charmm stream files)
sed -i "/return/d" system_complete.prm

# Waterbox generation
echo -e "\n *** Preparing the joint ligand-solvent system (prepare_waterbox_ligand.sh) ***"
hqh_sp_prepare_waterbox_LS.sh ${ligand_basename}_unique_typed system

cd ../../../../
