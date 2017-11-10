#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_H.sh <receptor basename>

Should be run in the inpput-files/receptor/ folder."

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

# Bash options
set -o pipefail

# Verbosity
if [ "${HQ_VERBOSITY}" = "debug" ]; then
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

# Printing some information
echo
echo
line_to_print="   Preparing the entire system for receptor ${1} (hqh_sp_prepare_H.sh)   "
echo "$line_to_print"
line_to_print_charno=$(echo -n "$line_to_print" | wc -m)
printf '%0.s*' $(seq 1 $line_to_print_charno)
echo

# Variables
receptor_basename=${1}
dirname=$(dirname $0)
receptor_FFparameter_source="$(grep -m 1 "^receptor_FFparameter_source=" ../config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Preparing the receptor
if [ "${receptor_FFparameter_source}" == "MATCH" ]; then

    # Assigning uniqe atom names
    echo -e "\n *** Assigning unique atom names (uniqe_atom_names_pdb.py) ***"
    hqh_sp_prepare_unique_atom_names_pdb.py ${receptor_basename}.pdb ${receptor_basename}_unique.pdb Y

    # Atom typing with MATCH - and unique atom names (required also by us regarding cp2k and dummy atoms)
    echo -e "\n * Atom typing with MATCH\n"
    timeout 5m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${receptor_basename}_unique_match.pdb ${receptor_basename}_unique.pdb
    trap '' ERR

    exit_code=${?}
    if [ "${exit_code}" == "124" ]; then
        echo " * MATCH seems to take too long. Aborting and trying again with the option UsingRefiningIncrements turned off"
        timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${receptor_basename}_unique_match.pdb -UsingRefiningIncrements 0 ${receptor_basename}_unique.pdb
        if [ "${exit_code}" == "124" ]; then
            echo " * MATCH still seems to take too long. Aborting and trying again with the option SubstituteIncrements turned off"
            timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${receptor_basename}_unique_match.pdb -SubstituteIncrements 0 ${receptor_basename}_unique.pdb
            if [ "${exit_code}" == "124" ]; then
                echo " * MATCH still seems to take too long. Giving up... "
            else
                echo -e "\n Failed to type atoms, skipping this receptor..."
                exit 0
            fi
        fi
    elif [ "${exit_code}" -ne "0" ]; then
        echo -e "\n Failed to type atoms (exit code was $exit_code, skipping this receptor..."
        exit 1
    fi
    trap 'error_response_std $LINENO' ERR

    #sed -i "s/RESI  LIG1/RESI  LIG /" ${receptor_basename}_unique.rtf # Required only if using mol2 receptor file for MATCH
    sed -i "s/RESI  UNK/RESI  LIG/" ${receptor_basename}_unique.rtf # Required only if using sdf receptor file for MATCH because it cannot store residue names

    # mv ${receptor_basename}_unique.pdb ${receptor_basename}_unique_typed.pdb # only needed when not using MATCH's pdb file
    cc_match_pp_pdb.sh ${receptor_basename}_unique.pdb ${receptor_basename}_unique_match.pdb ${receptor_basename}_unique_typed.pdb
    rm top* 2>/dev/null || true

    # Renaming the output files
    mv ${receptor_basename}_unique.prm ${receptor_basename}_unique_typed.prm
    mv ${receptor_basename}_unique.rtf ${receptor_basename}_unique_typed.rtf

elif [ "${receptor_FFparameter_source}" == "folder" ]; then
    cp ${receptor_basename}.pdb ${receptor_basename}_unique_typed.pdb
    cp ${receptor_basename}.rtf ${receptor_basename}_unique_typed.rtf
    cp ${receptor_basename}.prm ${receptor_basename}_unique_typed.prm
fi