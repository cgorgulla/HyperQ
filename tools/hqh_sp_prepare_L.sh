#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_L.sh <ligand_basename>

Should be run in the root folder."

# Standard error response 
error_response_std() {
    # Printing some information
    echo
    echo "An error was trapped" 1>&2
    echo "The error occured in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occured on line $1" 1>&2
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
if [ "${verbosity}" = "debug" ]; then
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
if [ "$#" -ne "1" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 1"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Printing some information
echo
echo
echo "   Preparing the entire system for ligand ${1} (hqh_sp_prepare_L.sh)   "
echo "************************************************************************************"
set -x
# Variables
ligand_basename=${1}
dirname=$(dirname $0)
ligand_FFparameter_source="$(grep -m 1 "^ligand_FFparameter_source=" input-files/config.txt | awk -F '=' '{print $2}')"

# Copying files, creating folders
echo -e "\n * Copying files and folders"
if [ -d input-files/systems/${ligand_basename}/L ]; then
    rm -r input-files/systems/${ligand_basename}/L
fi
mkdir -p input-files/systems/${ligand_basename}/L
cd input-files/systems/${ligand_basename}/L
cp ../../../ligands/pdb/${ligand_basename}.pdb ./${ligand_basename}.pdb


if [ "${ligand_FFparameter_source}" == "MATCH" ]; then

    # Assigning unique atom names
    echo -e "\n *** Assigning unique atom names (uniqe_atom_names_pdb.py) ***"
    hqh_sp_prepare_unique_atom_names_pdb.py ${ligand_basename}.pdb ${ligand_basename}_unique.pdb

    # Atom typing with MATCH - and unique atom names (required also by us regarding cp2k and dummy atoms)
    echo -e "\n * Atom typing with MATCH\n"
    #MATCH.pl -ExitifNotInitiated 0 -ExitifNotTyped 0 -ExitifNotCharged 0 ${ligand_basename}_unique.pdb
    #obabel -ipdb ${ligand_basename}_unique.pdb -osdf -O ${ligand_basename}_unique.sdf   # because of the bond orders,but that was because of the missing hydrogens
    MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 ${ligand_basename}_unique.pdb

    # Patching the prm file of MATCH
    # MATCH does not add the END statement which is needed by CP2K (in particular when joining multiple parameter files)
    echo "END" >> ${ligand_basename}_unique.prm

    mv top_${ligand_basename}_unique.rtf protein_ligand.rtf
    mv ${ligand_basename}_unique.pdb ${ligand_basename}_unique_typed.pdb
    mv ${ligand_basename}_unique.prm ${ligand_basename}_unique_typed.prm
    mv ${ligand_basename}_unique.rtf ${ligand_basename}_unique_typed.rtf
elif [ "${ligand_FFparameter_source}" == "folder" ]; then
    cp ${ligand_basename}.pdb ${ligand_basename}_unique_typed.pdb
    cp ../../../ligands/FF/${ligand_basename}.rtf ${ligand_basename}_unique_typed.rtf
    cp ../../../ligands/FF/${ligand_basename}.prm ${ligand_basename}_unique_typed.prm
fi

echo

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
echo -e "\n *** Preparing the joint ligand system (prepare_waterbox_ligand.sh) ***"
hqh_sp_prepare_box_L.sh ${ligand_basename}_unique_typed system

cd ../../../
