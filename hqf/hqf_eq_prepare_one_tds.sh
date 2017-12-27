#!/usr/bin/env bash

# Usage information
usage="Usage: hqf_eq_prepare_one_tds.sh <tds_index>

Arguments:
    <tds_range>: Index of the thermodynamic state
        * The index starts at 1 (w.r.t. the absolute simulation number)

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
        if [ -d  input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE_BS}/error.pipeline
            exit 1
        else
            cd ..
        fi
    done

    # Printing some information
    echo "Error: Cannot find the  ../../../input-files directory..."
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
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
tds_index="${1}"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_msp_transformation_type="$(grep -m 1 "^tdcycle_msp_transformation_type="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_eq_general="$(grep -m 1 "^inputfolder_cp2k_eq_general_${subsystem}="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_eq_specific="$(grep -m 1 "^inputfolder_cp2k_eq_specific_${subsystem}="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_programs="$(grep -m 1 "^eq_programs_${subsystem}="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_continue="$(grep -m 1 "^eq_continue="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_total_steps="$(grep -m 1 "^eq_total_steps_${subsystem}="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_trajectory_stride="$(grep -m 1 "^eq_trajectory_stride_${subsystem}="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_restart_stride="$(grep -m 1 "^eq_restart_stride_${subsystem}="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
temperature="$(grep -m 1 "^temperature="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cp2k_random_seed="$(grep -m 1 "^cp2k_random_seed="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total="  ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$(($tdw_count_total + 1))"
tdsname="tds-${tds_index}"
tds_msp_configuration="$(grep -m 1 "^tds_msp_configuration=" ${tdsname}/general/configuration.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Printing information
echo -e "\n\n  ** Preparing the simulation folder for TDS ${tds_index} (hqf_eq_prepare_one_tds.sh) **\n"

# Getting the cell size for the eq program input files
line=$(grep CRYST1 system1.pdb)
IFS=' ' read -r -a line_array <<< "$line"
cell_A=${line_array[1]}
cell_B=${line_array[2]}
cell_C=${line_array[3]}
cell_A_floor=${cell_A/.*}
cell_B_floor=${cell_B/.*}
cell_C_floor=${cell_C/.*}
cell_A_scaled=$((cell_A_floor*cell_dimensions_scaling_factor))
cell_B_scaled=$((cell_B_floor*cell_dimensions_scaling_factor))
cell_C_scaled=$((cell_C_floor*cell_dimensions_scaling_factor))
for value in cell_A_floor cell_B_floor cell_C_floor cell_A_scaled cell_B_scaled cell_C_scaled; do
    mod=$((${value}%2))
    if [ "${mod}" == "0" ]; then
        eval ${value}_odd=$((${value}+1))
    else
        eval ${value}_odd=$((${value}))
    fi
done

# Setting the cp2k random seed
if [ "${cp2k_random_seed^^}" == "RANDOM" ]; then

    # Setting the random seed
    cp2k_random_seed=$RANDOM

# Checking if the value is an integer
elif ! [ "${cp2k_random_seed}" -eq "${cp2k_random_seed}" ]; then

    # Printing error message before exiting
    echo -e "Error: The variable cp2k_random_seed has an unsupported value (${cp2k_random_seed}). Exiting..."
    exit 1
fi

# Checking which tdcycle type should be used
if [ "${tdcycle_msp_transformation_type}" == "hq" ]; then

    # Variables
    bead_counts="${tds_msp_configuration/k_}"
    bead_count1="${bead_counts/_*}"
    bead_count2="${bead_counts/*_}"
    lambda="$(grep -m 1 "^tds_msp_configuration_associated_lambda=" ${tdsname}/general/configuration.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

    # Checking if this equilibration should be continued
    if [[ "${eq_continue^^}" == "TRUE" ]]; then
        if [ -d "${tdsname}/cp2k" ]; then
            echo " * The folder ${tdsname}/cp2k already exists. Checking its contents..."
            cd ${tdsname}
            if [[ -s cp2k/cp2k.out.restart.bak-1 ]]; then

                echo -e " * The folder ${tdsname}/cp2k seems to contain files from a previous run. Preparing the folder for the next run...\n"

                # Editing the cp2k major input file
                sed -i 's/!\&EXT_RESTART/\&EXT_RESTART/g' cp2k/cp2k.in.main
                sed -i 's/! *EXT/  EXT/g' cp2k/cp2k.in.main
                sed -i 's/!\&END EXT_RESTART/\&END EXT_RESTART/g' cp2k/cp2k.in.main

                # Computing the remaining number of steps to run (only required for eq, not opt, because in geo_opt CP2K continues from the STEP_START_VAL value by itself)
                steps_todo="$(grep -m 1 "^ \+!HQ_STEPS_TOTAL " cp2k/cp2k.in.main | awk '{print $2}')"
                steps_completed="$(grep -m 1 "^ \+STEP_START_VAL " cp2k/cp2k.out.restart.bak-1 | awk '{print $2}')"
                steps_remaining="$((steps_todo-steps_completed))"
                sed -i "s/ STEPS \+[0-9]\+/ STEPS ${steps_remaining}/g" cp2k/cp2k.in.main

                # Removing previous error files
                if [ -f cp2k/cp2k.out.err ]; then
                    mv cp2k/cp2k.out.err cp2k/cp2k.out.err.old."$(date --rfc-3339=seconds | tr -s ' ' '_')"
                fi

                # Printing information
                echo -e "\n * The preparation of the equilibration folder for the TDS with index ${tds_index} in the folder ${tdsname} has been successfully completed.\n\n"

                # Finalization
                cd ..
                exit 0
            else
                echo " * The folder ${tdsname}/cp2k seems to not contain files from a previous run. Preparing it newly..."
                cd ..
                rm -r ${tdsname}/cp2k
            fi
        fi
    elif [[ "${eq_continue^^}" == "FALSE" ]]; then
        if [ -d "${tdsname}/cp2k" ]; then
            rm -r "${tdsname}/cp2k"
        fi
    else
        echo -e "Error: The variable eq_continue has an unsupported value (${tdsname}). Exiting..."
        exit 1
    fi

    # Copying the coordinate input files from the geo_opt
    cp ../../../opt/${msp_name}/${subsystem}/system.${tdsname}.opt.pdb ./

    # Preparation of the cp2k files
    if [[ "${eq_programs}" == *"cp2k"* ]]; then

        # Preparing the simulation folders
        mkdir -p ${tdsname}/cp2k

        # Copying the CP2K input files
        if [ "${lambda}" == "0.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys1 ${tdsname}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys1 ${tdsname}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.eq.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        elif [ "${lambda}" == "1.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys2 ${tdsname}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys2 ${tdsname}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.eq.sys2 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        else
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.lambda ${tdsname}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.lambda ${tdsname}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.eq.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        fi

        # Adjust the CP2K input files
        sed -i "s/lambda_value_placeholder/${lambda}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/tdsname_placeholder/${tdsname}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/temperature_placeholder/${temperature}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|subsystem_folder_placeholder|../..|" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|tds_potential_folder_placeholder|../general|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|cp2k_random_seed_placeholder|${cp2k_random_seed}|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|eq_total_steps_placeholder|${eq_total_steps}|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|eq_trajectory_stride_placeholder|${eq_trajectory_stride}|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|eq_restart_stride_placeholder|${eq_restart_stride}|g" ${tdsname}/cp2k/cp2k.in.*
    fi
elif [ "${tdcycle_msp_transformation_type}" == "lambda" ]; then

    # Variables
    lambda=${tds_msp_configuration/lambda_}

    # Checking if this equilibration should be continued
    if [[ "${eq_continue^^}" == "TRUE" ]]; then
        if [ -d "${tdsname}/cp2k" ]; then
            echo " * The folder ${tdsname}/cp2k already exists. Checking its contents..."
            cd ${tdsname}
            if [[ -s cp2k/cp2k.out.restart.bak-1 ]]; then

                echo -e " * The folder ${tdsname}/cp2k seems to contain files from a previous run. Preparing the folder for the next run...\n"

                # Editing the cp2k major input file
                sed -i 's/!\&EXT_RESTART/\&EXT_RESTART/g' cp2k/cp2k.in.main
                sed -i 's/! *EXT/  EXT/g' cp2k/cp2k.in.main
                sed -i 's/!\&END EXT_RESTART/\&END EXT_RESTART/g' cp2k/cp2k.in.main

                # Computing the remaining number of steps to run (only required for eq, not opt, because in geo_opt CP2K continues from the STEP_START_VAL value by itself)
                steps_todo="$(grep -m 1 "^ \+!HQ_STEPS_TOTAL " cp2k/cp2k.in.main | awk '{print $2}')"
                steps_completed="$(grep -m 1 "^ \+STEP_START_VAL " cp2k/cp2k.out.restart.bak-1 | awk '{print $2}')"
                steps_remaining="$((steps_todo-steps_completed))"
                sed -i "s/ STEPS \+[0-9]\+/ STEPS ${steps_remaining}/g" cp2k/cp2k.in.main

                # Removing previous error files
                if [ -f cp2k/cp2k.out.err ]; then
                    mv cp2k/cp2k.out.err cp2k/cp2k.out.err.old."$(date --rfc-3339=seconds | tr -s ' ' '_')"
                fi

                # Printing information
                echo -e "\n * The preparation of the equilibration folder for the TDS with index ${tds_index} in the folder ${tdsname} has been successfully completed.\n\n"

                # Finalization
                cd ..
                exit 0
            else
                echo " * The folder ${tdsname}/cp2k seems to not contain files from a previous run. Preparing it newly..."
                cd ..
                rm -r ${tdsname}/cp2k
            fi
        fi
    elif [[ "${eq_continue^^}" == "FALSE" ]]; then
        if [ -d "${tdsname}/cp2k" ]; then
            rm -r "${tdsname}/cp2k"
        fi
    else
        echo -e "Error: The variable eq_continue has an unsupported value (${tdsname}). Exiting..."
        exit 1
    fi

    # Copying the coordinate input files from the geo-opt
    cp ../../../opt/${msp_name}/${subsystem}/system.${lambda}.opt.pdb ./

    # Preparation of the cp2k files
    if [[ "${eq_programs}" == *"cp2k"* ]]; then

        # Preparing the simulation folder
        mkdir -p ${tdsname}/cp2k

        # Copying the CP2K input files
        # Copying the main files
        if [ "${lambda}" == "0.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys1 ${tdsname}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys1 ${tdsname}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.eq.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        elif [ "${lambda}" == "1.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.sys2 ${tdsname}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.sys2 ${tdsname}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.eq.sys2 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        else
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_specific}/main.eq.lambda ${tdsname}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_eq_general}/main.eq.lambda ${tdsname}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.eq.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        fi

        # Adjust the CP2K input files
        sed -i "s/lambda_value_placeholder/${lambda}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/tdsname_placeholder/${tdsname}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/temperature_placeholder/${temperature}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|subsystem_folder_placeholder|../..|" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|tds_potential_folder_placeholder|../general|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|cp2k_random_seed_placeholder|${cp2k_random_seed}|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|eq_total_steps_placeholder|${eq_total_steps}|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|eq_trajectory_stride_placeholder|${eq_trajectory_stride}|g" ${tdsname}/cp2k/cp2k.in.*
        sed -i "s|eq_restart_stride_placeholder|${eq_restart_stride}|g" ${tdsname}/cp2k/cp2k.in.*
    fi
fi

# Printing script completion information
echo -e "\n * The preparation of the TDS ${tds_index} has been successfully completed.\n\n"
