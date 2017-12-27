#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_HLS.sh <receptor_basename> <ligand_basename>

Should be run in the root folder."

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

# Checking the input parameters
if [ "${2}" == "-h" ]; then
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

# Printing some information
echo
echo
line_to_print="   Preparing the entire system for ligand ${2} (hqh_sp_prepare_HLS.sh)   "
echo "$line_to_print"
line_to_print_charno=$(echo -n "$line_to_print" | wc -m)
printf '%0.s*' $(seq 1 $line_to_print_charno)
echo

# Variables
receptor_basename=${1}
ligand_basename=${2}
dirname=$(dirname $0)
ligand_FFparameter_source="$(grep -m 1 "^ligand_FFparameter_source=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Copying files, creating folders
echo -e "\n * Copying files and folders"
if [ -d input-files/systems/${ligand_basename}/RLS ]; then
    rm -r input-files/systems/${ligand_basename}/RLS
fi
mkdir -p input-files/systems/${ligand_basename}/RLS
cd input-files/systems/${ligand_basename}/RLS
cp ../../../ligands/pdb/${ligand_basename}.pdb ./${ligand_basename}.pdb

# Preparing the ligand
if [ "${ligand_FFparameter_source}" == "MATCH" ]; then

    # Assigning uniqe atom names
    echo -e "\n *** Assigning unique atom names (uniqe_atom_names_pdb.py) ***"
    hqh_sp_prepare_unique_atom_names_pdb.py ${ligand_basename}.pdb ${ligand_basename}_unique.pdb Q

    # Atom typing with MATCH - and unique atom names (required also by us regarding cp2k and dummy atoms)
    echo -e "\n * Atom typing with MATCH\n"
    #MATCH.pl -ExitifNotInitiated 0 -ExitifNotTyped 0 -ExitifNotCharged 0 ${ligand_basename}_unique.pdb
    obabel -ipdb ${ligand_basename}_unique.pdb -osdf -O ${ligand_basename}_unique.sdf #because of the bond orders (which can be caused by missing hydrogens, but not only) sdf does work for that, but obabel doesn't create the alias atom names in the sdf file (https://sourceforge.net/p/rdkit/mailman/message/35360754/)
    trap '' ERR

    timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${ligand_basename}_unique_match.pdb ${ligand_basename}_unique.sdf
    exit_code=${?}
    if [ "${exit_code}" == "124" ]; then
        echo " * MATCH seems to take too long. Aborting and trying again with the option UsingRefiningIncrements turned off"
        timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${ligand_basename}_unique_typed.pdb -UsingRefiningIncrements 0 ${ligand_basename}_unique.sdf;
        if [ "${exit_code}" == "124" ]; then
            echo " * MATCH still seems to take too long. Aborting and trying again with the option SubstituteIncrements turned off"
            timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${ligand_basename}_unique_typed.pdb -SubstituteIncrements 0 ${ligand_basename}_unique.sdf;
            if [ "${exit_code}" == "124" ]; then
                echo " * MATCH still seems to take too long. Giving up... "
            else
                echo -e "\n Failed to type atoms, skipping this ligand..."
                exit 0
            fi
        fi
    elif [ "${exit_code}" -ne "0" ]; then
        echo -e "\n Failed to type atoms (exit code was $exit_code, skipping this ligand..."
        exit 0
    fi
    trap 'error_response_std $LINENO' ERR

    #sed -i "s/RESI  LIG1/RESI  LIG /" ${ligand_basename}_unique.rtf # Required only if using mol2 ligand file for MATCH
    sed -i "s/RESI  UNK/RESI  LIG/" ${ligand_basename}_unique.rtf # Required only if using sdf ligand file for MATCH because it cannot store residue names

    # mv ${ligand_basename}_unique.pdb ${ligand_basename}_unique_typed.pdb # only needed when not using MATCH's pdb file
    cc_match_pp_pdb.sh ${ligand_basename}_unique.pdb ${ligand_basename}_unique_match.pdb ${ligand_basename}_unique_typed.pdb

    # Patching the prm file of MATCH
    # MATCH does not add the END statement which is needed by CP2K (in particular when joining multiple parameter files)
    echo "END" >> ${ligand_basename}_unique.prm

    # Renaming the output files
    mv ${ligand_basename}_unique.prm ${ligand_basename}_unique_typed.prm
    mv ${ligand_basename}_unique.rtf ${ligand_basename}_unique_typed.rtf
elif [ "${ligand_FFparameter_source}" == "folder" ]; then
    cp ${ligand_basename}.pdb ${ligand_basename}_unique_typed.pdb
    cp ../../../ligands/FF/${ligand_basename}.rtf ${ligand_basename}_unique_typed.rtf
    cp ../../../ligands/FF/${ligand_basename}.prm ${ligand_basename}_unique_typed.prm
fi
echo

# Preparing the receptor files
cp ../../../receptor/${receptor_basename}_unique_typed.pdb ./receptor_unique_typed.pdb
cp ../../../receptor/${receptor_basename}_unique_typed.rtf ./receptor_unique_typed.rtf
cp ../../../receptor/${receptor_basename}_unique_typed.prm ./receptor_unique_typed.prm

# Creating the joint parameter file for receptor+ligand
script_dir=$(dirname $0)
cp ${script_dir}/../common/charmm36/par_all36_cgenff.prm ./system_complete.prm
cat ${script_dir}/../common/charmm36/water-tip3p_ions.prm >> system_complete.prm
cat receptor_unique_typed.prm >> system_complete.prm
cat ${ligand_basename}_unique_typed.prm >> system_complete.prm

# Some parameter files seem to contain the section keyword IMPROPERS instead of IMPROPER, but CP2K only understands the latter)
sed -i "s/^IMPROPERS/IMPROPER/g" system_complete.prm
# Removing any return statements (from Charmm stream files)
sed -i "/return/d" system_complete.prm

# Waterbox generation
echo -e "\n *** Preparing the joint receptor-ligand-solvent system (hqh_sp_prepare_waterbox_HLS.sh) ***"
hqh_sp_prepare_waterbox_HLS.sh receptor_unique_typed ${ligand_basename}_unique_typed system

cd ../../..
