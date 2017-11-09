#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_md_prepare_one_msp.sh <system 1 basename> <system 2 basename> <subsystem type> <tds_range>

Arguments:
    <subsystem>: Possible values: L, LS, RLS

    <tds_range>: Range of the thermodynamic states
      * Format: startindex:endindex
      * The index starts at 1
      * The capital letter K can be used to indicate the end state of the thermodynamic path

Has to be run in the root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "4" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 4"
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

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
system1_basename="${1}"
system2_basename="${2}"
subsystem=${3}
tds_range=${4}
msp_name=${system1_basename}_${system2_basename}
inputfile_ipi_md="$(grep -m 1 "^inputfile_ipi_md_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" input-files/config.txt | awk -F '=' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" input-files/config.txt | awk -F '=' '{print $2}')"
tdw_count="$(grep -m 1 "^tdw_count=" input-files/config.txt | awk -F '=' '{print $2}')"
tds_count="$((tdw_count + 1))"
stride_ipi_properties="$(grep "potential" input-files/ipi/${inputfile_ipi_md} | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')"
stride_ipi_trajectory="$(grep "<checkpoint" input-files/ipi/${inputfile_ipi_md} | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')"

# Printing information
echo -e "\n *** Preparing the MD simulation ${msp_name} (hqf_md_prepare_one_msp.sh)\n"

# Setting the range indices
tds_index_first=${tds_range/:*}
tds_index_last=${tds_range/*:}
if [ "${tds_index_last}" == "K" ]; then
    tds_index_last=${tds_count}
fi

# Checking if the range indices have valid values
if ! [ "${tds_index_first}" -le "${tds_index_first}" ]; then
    echo " * Error: The input variable tds_range was not specified correctly. Exiting..."
    exit 1
fi

# Checking if the checkpoint and potential stride in the ipi input file are equal
if [ "${stride_ipi_properties}" -ne "${stride_ipi_trajectory}" ]; then
    echo -n "Error: the checkpoint and potential need to have the same stride in the ipi input file\.n\n"
    exit 1
fi

# Checking if the general files for this MSP have to be prepared
# Using the system.a1c1.[uc]_atom files as indicators since they are the last files created during the general preparation
if [[ "${md_continue^^}" == "TRUE" ]] && ls ./md/${msp_name}/${subsystem}/system.a1c1.[uc]_atoms &>/dev/null; then

    # Printing information
    echo " * The continuation mode for the MD simulation is enabled, and the general files for the current MSP (${msp_name}) have already been prepared."
    echo " * Skipping the general preparation..."

    # Changing the pwd into the relevant folder
    cd md/${msp_name}/${subsystem}

elif [[ "${md_continue^^}" == "FALSE" ]] || ( [[ "${md_continue^^}" == "TRUE" ]] && ! ls ./md/${msp_name}/${subsystem}/system.a1c1.[uc]_atoms &>/dev/null ); then

    # Preparing the main folder
    echo -e " * Preparing the main folder"
    mkdir -p md/${msp_name}/${subsystem}
    cd md/${msp_name}/${subsystem}

    # Copying the shared simulation files
    echo -e " * Copying general simulation files"
    system_ID=1
    for system_basename in ${system1_basename} ${system2_basename}; do
        cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${system_ID}.vmd.psf
        cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${system_ID}.pdb
        cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${system_ID}.prm
        cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${system_ID}.pdbx
        (( system_ID += 1 ))
    done
    cp ../../../input-files/mappings/${system1_basename}_${system2_basename} ./system.mcs.mapping
    cp ../../../eq/${msp_name}/${subsystem}/system.*.eq.pdb ./

    # Preparing the shared CP2K input files
    hqh_fes_prepare_one_fes_common.sh ${nbeads} ${tdw_count} ${system1_basename} ${system2_basename} ${subsystem} ${md_type} ${md_programs}
fi

# Preparing the MD simulation folder for each TDS
for tds_index in $(seq ${tds_index_first} ${tds_index_last}); do
    hqf_md_prepare_one_tds.sh ${tds_index}
done

cd ../../../

# Printing program completion information
echo -e "\n * The preparation of the subsystem folder for the MSP ${msp_name} has been successfully completed.\n\n"
