#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_opt_prepare_one_msp.sh <system 1 basename> <system 2 basename> <subsystem> <tds_range>

Arguments:
    <subsystem>: Possible values: L, LS, RLS

    <tds_range>: Range of the thermodynamic states
      * Format: startindex:endindex
      * The index starts at 1
      * The capital letter K can be used to indicate the end state of the thermodynamic path

Has to be run in the root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then

    # Printing usage information
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "4" ]; then

    # Printing input argument error information
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
system_1_basename="${1}"
system_2_basename="${2}"
subsystem="${3}"
tds_range="${4}"
msp_name=${system_1_basename}_${system_2_basename}
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_msp_transformation_type="$(grep -m 1 "^tdcycle_msp_transformation_type=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_continue="$(grep -m 1 "^opt_continue=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
signpostings_activate="$(grep -m 1 "^signpostings_activate=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_opt_general="$(grep -m 1 "^inputfolder_cp2k_opt_general_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_opt_specific="$(grep -m 1 "^inputfolder_cp2k_opt_specific_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$((tdw_count_total + 1))"

# Printing information
echo -e "\n\n *** Preparing the optimization folder for MSP ${msp_name} (hqf_opt_prepare_one_msp.sh) ***\n"

# Creating the main folder if not yet existing
mkdir -p opt/${msp_name}/${subsystem} || true   # Parallel robustness

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
        if [ -f opt/${msp_name}/${subsystem}/preparation.common.signpost.entrance ]; then

            # Variables
            modification_time="$(stat -c %Y opt/${msp_name}/${subsystem}/preparation.common.signpost.entrance || true)"
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
                touch opt/${msp_name}/${subsystem}/preparation.common.signpost.entrance
                status="continue"
            fi
        else
            # Printing some information
            echo -e "   * No entrance signposting from previous runs has been found"
            echo -e "   * Clearance obtained. Setting the entrance signpost and continuing...\n"

            # Setting the signpost
            touch opt/${msp_name}/${subsystem}/preparation.common.signpost.entrance
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
    echo " * Error: The input variable tds_range was not specified correctly. Exiting..."
    exit 1
fi


# Checking if the system names are proper by checking if the mapping file exists
echo -e -n " * Checking if the mapping file exists... "
if [[ -f input-files/mappings/curated/${system_1_basename}_${system_2_basename} || -f input-files/mappings/hr_override/${system_1_basename}_${system_2_basename} ]]; then
    echo " OK"
else
    echo "Check failed. The mapping file for MSP ${msp_name} was not found in the input-files/mappings folder. Exiting..."
    exit 1
fi

# Checking if the CP2K opt input file contains a lambda variable
echo -n " * Checking if the lambda_value variable is present in the CP2K input file... "
if [ -f input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda ]; then
    lambdavalue_count="$(grep -c lambda_value input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda)"
elif [ -f input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda ]; then
    lambdavalue_count="$(grep -c lambda_value input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda)"
else
    echo -e "\n * Error: The input file main.opt.lambda could not be found in neither of the two CP2K input folders. Exiting..."
    exit 1
fi
if  [ ! "${lambdavalue_count}" -ge "1" ]; then
    echo "Check failed"
    echo -e "\n * Error: The main CP2K optimization input file does not contain the lambda_value variable. Exiting...\n\n"
    touch runtime/${HQ_STARTDATE_BS}/error.pipeline
    exit 1
fi
echo "OK"

# Checking if the general files for this MSP have to be prepared
# Using the system.a1c1.[uc]-atom files as indicators since they are the last files created during the general preparation
if [[ "${opt_continue^^}" == "TRUE"  && -f opt/${msp_name}/${subsystem}/preparation.common.signpost.success ]] && ls ./opt/${msp_name}/${subsystem}/system.a1c1.uatoms &>/dev/null && ls ./opt/${msp_name}/${subsystem}/system.a1c1.qatoms &>/dev/null && ls ./opt/${msp_name}/${subsystem}/cp2k.in.sub.forces.* &>/dev/null && ls ./opt/${msp_name}/${subsystem}/tds*/general/ &>/dev/null; then

    # Printing information
    echo " * The continuation mode for the optimizations is enabled, and the general files for the current MSP (${msp_name}) have already been prepared."
    echo " * Skipping the general preparation..."

    # Changing the pwd into the relevant folder
    cd opt/${msp_name}/${subsystem}

else

    # Changing the pwd into the relevant folder
    cd opt/${msp_name}/${subsystem}

    # Copying the system files
    echo -e " * Copying general simulation files"
    system_ID=1
    for system_basename in ${system_1_basename} ${system_2_basename}; do

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
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${system_ID}.pdbx || true    # Parallel robustness
        else
            # Printing some error message
            echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        (( system_ID += 1 ))
    done
    if [ -f ../../../input-files/mappings/hr_override/${msp_name} ]; then
        cp ../../../input-files/mappings/hr_override/${msp_name} ./system.mcs.mapping || true   # Parallel robustness
    elif [ -f ../../../input-files/mappings/curated/${msp_name} ]; then
        cp ../../../input-files/mappings/curated/${msp_name} ./system.mcs.mapping || true   # Parallel robustness
    else
        # Printing some error message
        echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

        # Raising an error
        false
    fi
    if [ -f ../../../input-files/mappings/hr_override/${msp_name} ]; then
        echo " * A mapping file for this MSP in the hr_override folder has been found. Using it instead of the default mapping file ..."
        grep  -E "^ *[0-9]+"  ../../../input-files/mappings/hr_override/${msp_name} | awk '{print $1, $2}' > ./system.mcs.mapping || true   # Parallel robustness
    elif [ -f ../../../input-files/mappings/curated/${msp_name} ]; then
        echo " * No mapping file for this MSP in the hr_override folder has been found. Using the default mapping file instead ..."
        cp ../../../input-files/mappings/curated/${msp_name} ./system.mcs.mapping || true   # Parallel robustness
    else
        # Printing some error message
        echo -e "\n * Error: An required input-file does not exist. Exiting...\n\n"

        # Raising an error
        false
    fi
    if [ -f ../../../input-files/mappings/hr/${system_1_basename}_${system_2_basename} ]; then
        cp ../../../input-files/mappings/hr/${system_1_basename}_${system_2_basename} ./system.mcs.mapping.hr || true   # Parallel robustness
    fi

    # Copying the CP2K sub files
    for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/ -type f -name "sub*"); do
        cp $file cp2k.in.${file/*\/}
    done
    # The sub files in the specific folder at the end so that they can override the ones of the general CP2K input folder
    for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/ -type f -name "sub*"); do
        cp $file cp2k.in.${file/*\/}
    done

    # Preparing the shared input files
    hqh_fes_prepare_one_fes_common.sh
fi

# Preparing a success signpost
touch preparation.common.signpost.success

# Preparing the optimization folder for each TDS
for tds_index in $(seq ${tds_index_first} ${tds_index_last}); do
    hqf_opt_prepare_one_tds.sh ${tds_index}
done

cd ../../../

# Printing program completion information
echo -e "\n * The preparation of the subsystem folder for the MSP ${msp_name} has been successfully completed.\n\n"
