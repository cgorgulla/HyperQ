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
    echo -e "\n * Error: Cannot find the input-files directory..."
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
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
system1_basename="${1}"
system2_basename="${2}"
subsystem="${3}"
tds_range="${4}"
msp_name="${system1_basename}_${system2_basename}"
inputfile_ipi_md="$(grep -m 1 "^inputfile_ipi_md_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_md_general="$(grep -m 1 "^inputfolder_cp2k_md_general_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_md_specific="$(grep -m 1 "^inputfolder_cp2k_md_specific_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
signpostings_activate="$(grep -m 1 "^signpostings_activate=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$((tdw_count_total + 1))"

# Printing information
echo -e "\n\n *** Preparing the MD simulation ${msp_name} (hqf_md_prepare_one_msp.sh) ***\n"

# Creating the main folder if not yet existing
mkdir -p md/${msp_name}/${subsystem} || true   # Parallel robustness

# Checking if enough time has elapsed since other pipelines have prepared this workflow ro provided interferences between parallel running pipelines
if [ "${signpostings_activate^^}" == "TRUE" ]; then

    # Printing some information
    echo -e "\n * Signposting checks are activated. Starting checks..."

    # Variables
    signpostings_minimum_waiting_time="$(grep -m 1 "^signpostings_minimum_waiting_time=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signpostings_dispersion_time_maximum="$(grep -m 1 "^signpostings_dispersion_time_maximum=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    status="wait"

    # Sleeping some initial random time to disperse multiple simultaneously arriving pipelines in time (which can happen e.g. if jobs have been dispatched at the same time by the batchsystem)
    sleeping_time="$(shuf -i 0-${signpostings_dispersion_time_maximum} -n1)"
    echo -e "   * Sleeping initial (random) period of ${sleeping_time} seconds..."
    sleep ${sleeping_time}

    # Loop setup
    while [[ "${status}" = "wait" ]]; do

        # Checking if there is an entrance signpost from previous pipelines
        if [ -f md/${msp_name}/${subsystem}/preparation.common.signpost.entrance ]; then

            # Variables
            modification_time="$(stat -c %Y md/${msp_name}/${subsystem}/preparation.common.signpost.entrance || true)"
            modification_time_difference="$(($(date +%s) - modification_time))"
            if [ "${modification_time_difference}" -lt "${signpostings_minimum_waiting_time}" ]; then

                # Variables
                sleeping_time="$(shuf -i 0-${signpostings_dispersion_time_maximum} -n1)"

                # Printing some information
                echo -e "   * The minimum waiting time (${signpostings_minimum_waiting_time} seconds) since the last entrance signpost hast been set has not yet been passed (current waiting time: ${modification_time_difference} seconds)"
                echo -e "   * Sleeping for ${sleeping_time} more seconds..."

                # Sleeping some random time to disperse multiple waiting pipelines in time
                sleep ${sleeping_time}
            else
                # Printing some information
                echo -e "   * The minimum waiting time (${signpostings_minimum_waiting_time} seconds) since the last entrance signpost hast been set has been passed (current waiting time: ${modification_time_difference} seconds)"
                echo -e "   * Clearance obtained. Updating previous entrance signpost and continuing...\n"

                # Updating the entrance signpost
                touch md/${msp_name}/${subsystem}/preparation.common.signpost.entrance
                status="continue"
            fi
        else
            # Printing some information
            echo -e "   * No entrance signposting from previous runs has been found"
            echo -e "   * Clearance obtained. Setting the entrance signpost and continuing...\n"

            # Setting the signpost
            touch md/${msp_name}/${subsystem}/preparation.common.signpost.entrance
            status="continue"
        fi
    done
fi

# Setting the range indices
tds_index_first=${tds_range/:*}
tds_index_last=${tds_range/*:}
if [ "${tds_index_last}" == "K" ]; then
    tds_index_last=${tds_count_total}
fi

# Checking if the range indices have valid values
if ! [ "${tds_index_first}" -le "${tds_index_first}" ]; then
    echo -e "\n * Error: The input variable tds_range was not specified correctly. Exiting..."
    exit 1
fi

# Checking if the general files for this MSP have to be prepared
# Using the system.a1c1.[uc]-atom files as indicators since they are the last files created during the general preparation
if [[ "${md_continue^^}" == "TRUE"  && -f md/${msp_name}/${subsystem}/preparation.common.signpost.success ]] && ls ./md/${msp_name}/${subsystem}/system.a1c1.uatoms &>/dev/null && ls ./md/${msp_name}/${subsystem}/system.a1c1.qatoms &>/dev/null && ls ./md/${msp_name}/${subsystem}/cp2k.in.sub.forces.* &>/dev/null && ls ./md/${msp_name}/${subsystem}/tds*/general/ &>/dev/null; then

    # Printing information
    echo " * The continuation mode for the MD simulation is enabled, and the general files for the current MSP (${msp_name}) have already been prepared."
    echo " * Skipping the general preparation..."

    # Changing the pwd into the relevant folder
    cd md/${msp_name}/${subsystem}

else

    # Changing to the subsystem directory
    cd md/${msp_name}/${subsystem}

    # Copying the shared simulation files
    echo -e " * Copying general simulation files"
    system_ID=1
    for system_basename in ${system1_basename} ${system2_basename}; do

        # Copying the required input files. Making sure the files exist, and copying them ignoring possible errors which can arise during parallel preparations of different TDS of the same MSP
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${system_ID}.vmd.psf || true   # Parallel robustness
        else
            # Printing some error message
            echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${system_ID}.pdb || true   # Parallel robustness
        else
            # Printing some error message
            echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${system_ID}.prm || true   # Parallel robustness
        else
            # Printing some error message
            echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${system_ID}.pdbx || true   # Parallel robustness
        else
            # Printing some error message
            echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        (( system_ID += 1 ))
    done
    if [ -f ../../../input-files/mappings/curated/${msp_name} ]; then
        cp ../../../input-files/mappings/curated/${msp_name} ./system.mcs.mapping || true   # Parallel robustness
    else
        # Printing some error message
        echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

        # Raising an error
        false
    fi
    if [ -f ../../../input-files/mappings/hr/${msp_name} ]; then
        cp ../../../input-files/mappings/hr/${msp_name} ./system.mcs.mapping.hr || true   # Parallel robustness
    fi

    # Copying the CP2K sub files
    for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/ -type f -name "sub*"); do
        cp $file cp2k.in.${file/*\/}
    done
    # Copying the sub files in the specific folder at the end so that they can override the ones of the general CP2K input folder
    for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/ -type f -name "sub*"); do
        cp $file cp2k.in.${file/*\/}
    done

    # Preparing the shared input files (independent of simulation type)
    hqh_fes_prepare_one_fes_common.sh
fi

# Preparing a success signpost
touch preparation.common.signpost.success

# Preparing the MD simulation folder for each TDS
for tds_index in $(seq ${tds_index_first} ${tds_index_last}); do
    hqf_md_prepare_one_tds.sh ${tds_index}
done

cd ../../../

# Printing program completion information
echo -e "\n * The preparation of the subsystem folder for the MSP ${msp_name} has been successfully completed.\n\n"
