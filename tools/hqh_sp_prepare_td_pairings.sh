#!/usr/bin/env bash  

# Usage information
usage="Usage: hqh_sp_prepare_td_pairings.sh\nShould be run in the root folder."

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

# Printing some information
echo
echo
echo "   Preparing the thermodynamic cycles (hqh_sp_prepare_td_pairings.sh)   "
echo "***********************************************************************"

# Checking the input arguments.
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

# Variables
lomap_output_basename="lomap"
lomap_ncpus="$(grep -m 1 "^lomap_ncpus" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
mcs_time="$(grep -m 1 "^mcs_time" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
draw_pairwise_mcs="$(grep -m 1 "^draw_pairwise_mcs" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
lomap_mol2_folder="$(grep -m 1 "^lomap_mol2_folder" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Creating required folders
if [ -d "input-files/mappings" ]; then
    rm -r "input-files/mappings"
fi
mkdir -p input-files/mappings/raw
mkdir -p input-files/mappings/curated
mkdir -p input-files/mappings/hr
cd input-files/mappings/raw

# Running Lomap
echo "hqh_sp_prepare_td_pairings_lomap.py "../../ligands/${lomap_mol2_folder}" "${lomap_output_basename}" "${lomap_ncpus}" "${mcs_time}" "${draw_pairwise_mcs}""
hqh_sp_prepare_td_pairings_lomap.py "../../ligands/${lomap_mol2_folder}" "${lomap_output_basename}" "${lomap_ncpus}" "${mcs_time}" "${draw_pairwise_mcs}"

# Processing the Lomap output
cat ${lomap_output_basename}.dot | sed -e ':a' -e 'N' -e '$!ba' -e 's/,\n\s*/,/g' | sed "s/^\s//g" | grep -v [}{] > ${lomap_output_basename}.dot.2
hqh_sp_prepare_td_pairings.py ${lomap_output_basename}.dot.2

# Copying the mapping files
cp td.pairings ../
IFS=' ' read -r -a td_pairings <<< "td.pairings"
while IFS='' read -r line || [[ -n "$line" ]]; do
    IFS=' ' read -r -a array <<< "$line"
    cp mcs_mapping_${array[0]}_${array[1]} ../curated/${array[2]}_${array[3]}

    # Preparing the human readable mapping files
    hqh_fes_prepare_human_mapping.py ../../ligands/pdb/${array[2]}.pdb ../../ligands/pdb/${array[3]}.pdb ../curated/${array[2]}_${array[3]}  ../hr/${array[2]}_${array[3]}
done < td.pairings

cd ../../../

echo -e "\n * The preparation of the TD cycles has been completed.\n\n"
