#!/usr/bin/env bash

# Usage information
usage="Usage: hqf_eq_pp_one_msp.sh <tds_range>

Arguments:
    <tds_range>: Range of the thermodynamic states
      * Format: startindex:endindex
      * The index starts at 1
      * The capital letter K can be used to indicate the end state of the thermodynamic path

Has to be run in the subsystem folder."

# Checking the input arguments
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

# Printing information
echo -e "\n *** Postprocessing the equilibration (hqf_eq_pp_one_msp.sh)"

# Config file setup
if [[ -z "${HQ_CONFIGFILE_MSP}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_MSP was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_MSP=input-files/config/general.txt
    export HQ_CONFIGFILE_MSP
fi

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
tds_range="${1}"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
tdcycle_msp_transformation_type="$(grep -m 1 "^tdcycle_msp_transformation_type=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_programs="$(grep -m 1 "^eq_programs_${subsystem}=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$((tdw_count_total + 1))"

# Setting the range indices
tds_index_first=${tds_range/:*}
tds_index_last=${tds_range/*:}
if [ "${tds_index_last}" == "K" ]; then
    tds_index_last=${tds_count_total}
fi

# Loop for each equilibration in the specified tds range
for tds_index in $(seq ${tds_index_first} ${tds_index_last}); do

    # Variables
    tdsname=tds-${tds_index}

    # Variables
    original_pdb_filename="system.a1c1.pdb"
    original_psf_filename="system1.psf"
    output_filename="system.${tdsname}.eq.pdb"

    # Postprocessing the equilibration
    echo -e " * Postprocessing folder ${tdsname}"
    if [ "${eq_programs}" == "cp2k" ]; then
        hq_eq_pp_one_tds.sh ${original_pdb_filename} ${original_psf_filename} ${tdsname}/cp2k/cp2k.out.trajectory.pdb ${output_filename}
    fi
done

# Printing program completion information
echo -e "\n * The postprocessing of the specified TDSs (${tds_range}) of the current MSP (${msp_name}) has been successfully completed.\n\n"
