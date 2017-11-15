#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_eq_prepare_one_msp.sh <system 1 basename> <system 2 basename> <subsystem> <tds_range>

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
            touch runtime/${HQ_BS_STARTDATE}/error.pipeline
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
HQ_VERBOSITY="$(grep -m 1 "^verbosity_runtime=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
system_1_basename="${1}"
system_2_basename="${2}"
subsystem=${3}
tds_range=${4}
msp_name=${system_1_basename}_${system_2_basename}
inputfolder_cp2k_eq_general="$(grep -m 1 "^inputfolder_cp2k_eq_general_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_eq_specific="$(grep -m 1 "^inputfolder_cp2k_eq_specific_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_programs="$(grep -m 1 "^eq_programs_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_type="$(grep -m 1 "^eq_type_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_continue="$(grep -m 1 "^eq_continue=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_type="$(grep -m 1 "^tdcycle_type=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count="$(grep -m 1 "^tdw_count=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count="$((tdw_count + 1))"

# Printing information
echo -e "\n *** Preparing the equilibration folder for fes ${msp_name} (hq_eq_prepare_one_fes) *** "

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

# Checking if the variables nbeads and tdw_count are compatible
if [ "${tdcycle_type}" == "hq" ]; then
    echo -e -n " * Checking if the variables <nbeads> and <tdw_count> are compatible... "
    trap '' ERR
    mod="$(expr ${nbeads} % ${tdw_count})"
    trap 'error_response_std $LINENO' ERR
    if [ "${mod}" != "0" ]; then
        echo "Check failed"
        echo " * The variables <nbeads> and <tdw_count> are not compatible. <nbeads> has to be divisible by <tdw_count>."
        exit 1
    fi
    echo " OK"
fi

# Checking if the system names are proper by checking if the mapping file exists
echo -e -n " * Checking if the mapping file exists... "
if [ -f input-files/mappings/${system_1_basename}_${system_2_basename} ]; then
    echo " OK"
else
    echo "Check failed. The mapping file ${system_1_basename}_${system_2_basename} was not found in the input-files/mappings folder."
    exit 1
fi

# Checking if the CP2K equilibration input file contains a lambda variable
echo -n " * Checking if the lambda_value variable is present in the CP2K input file... "
if [ -f input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.lambda ]; then
    lambdavalue_count="$(grep -c lambda_value input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.lambda)"
elif [ -f input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.lambda ]; then
    lambdavalue_count="$(grep -c lambda_value input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.lambda)"
else
    echo "Error: The input file main.eq.lambda could not be found in neither of the two CP2K input folders. Exiting..."
    exit 1
fi
if  [ ! "${lambdavalue_count}" -ge "1" ]; then
    echo "Check failed"
    echo -e "\n * Error: The CP2K equilibration input file does not contain the lambda_value variable. Exiting...\n\n"
    touch runtime/${HQ_BS_STARTDATE}/error.pipeline
    exit 1
fi
echo "OK"

# Using the system.a1c1.[uc]_atom files as indicators since they are the last files created during the general preparation
if [[ "${eq_continue^^}" == "TRUE" ]] && ls ./eq/${msp_name}/${subsystem}/system.a1c1.[uc]_atoms &>/dev/null; then

    # Printing information
    echo " * The continuation mode for the equilibration is enabled, and the general files for the current MSP (${msp_name}) have already been prepared."
    echo " * Skipping the general preparation..."

    # Changing the pwd into the relevant folder
    cd eq/${msp_name}/${subsystem}

elif [[ "${eq_continue^^}" == "FALSE" ]] || ( [[ "${eq_continue^^}" == "TRUE" ]] && ! ls ./eq/${msp_name}/${subsystem}/system.a1c1.[uc]_atoms &>/dev/null ); then

    # Creating the main folder if not yet existing
    echo -e " * Preparing the main folder"
    mkdir -p eq/${msp_name}/${subsystem} || true   # Parallel robustness

    # Changing the pwd into the relevant folder
    cd eq/${msp_name}/${subsystem}

    # Copying the system files
    echo -e " * Copying general simulation files"
    system_ID=1
    for system_basename in ${system_1_basename} ${system_2_basename}; do

        # Copying the required input files. Making sure the files exist, and copying them ignoring possible errors which can arise during parallel preparations of different TDS of the same MSP
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${system_ID}.vmd.psf || true   # Parallel robustness
        else
            # Printing some error message
            echo "Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${system_ID}.pdb || true   # Parallel robustness
        else
            # Printing some error message
            echo "Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${system_ID}.prm || true   # Parallel robustness
        else
            # Printing some error message
            echo "Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        if [ -f ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${system_ID}.pdbx || true   # Parallel robustness
        else
            # Printing some error message
            echo "Error: An required input-file does not exist. Exiting...\n\n"

            # Raising an error
            false
        fi
        (( system_ID += 1 ))
    done
    if [ -f ../../../input-files/mappings/${system_1_basename}_${system_2_basename} ]; then
        cp ../../../input-files/mappings/${system_1_basename}_${system_2_basename} ./system.mcs.mapping || true   # Parallel robustness
    else
        # Printing some error message
        echo "Error: An required input-file does not exist. Exiting...\n\n"

        # Raising an error
        false
    fi

    # Preparing the shared input files
    hqh_fes_prepare_one_fes_common.sh ${nbeads} ${tdw_count} ${system_1_basename} ${system_2_basename} ${subsystem} ${eq_type} ${eq_programs}

else
    echo "Error: The parameter 'eq_continue' specified in the main configuration file has an unsupported value (${eq_continue}). Exiting..."
    exit 1
fi

# Preparing the equilibration folder for each TDS
for tds_index in $(seq ${tds_index_first} ${tds_index_last}); do
    hqf_eq_prepare_one_tds.sh ${tds_index}
done

cd ../../../

# Printing script completion information
echo -e "\n * The preparation of the subsystem folder for the the current MSP (${msp_name}) has been successfully completed.\n\n"