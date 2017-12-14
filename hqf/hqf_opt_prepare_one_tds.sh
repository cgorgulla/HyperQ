#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_opt_prepare_one_tds.sh <tds_index>

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

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
tds_index="${1}"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_type="$(grep -m 1 "^tdcycle_type="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_opt_general="$(grep -m 1 "^inputfolder_cp2k_opt_general_${subsystem}="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_opt_specific="$(grep -m 1 "^inputfolder_cp2k_opt_specific_${subsystem}="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_continue="$(grep -m 1 "^opt_continue="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_max_steps="$(grep -m 1 "^opt_max_steps_${subsystem}="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_trajectory_stride="$(grep -m 1 "^opt_trajectory_stride_${subsystem}="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_restart_stride="$(grep -m 1 "^opt_restart_stride_${subsystem}="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cp2k_random_seed="$(grep -m 1 "^cp2k_random_seed="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count="$(grep -m 1 "^tdw_count="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count="$(($tdw_count + 1))"

# Printing information
echo -e "\n *** Preparing the simulation folder for TDS ${tds_index} (hqf_opt_prepare_one_tds.sh) "

# Getting the cell size for the opt program input files
line=$(grep CRYST1 system1.pdb)
IFS=' ' read -r -a line_array <<< "$line"
cell_A=${line_array[1]}
cell_B=${line_array[2]}
cell_C=${line_array[3]}

# Computing the GMAX values for CP2K
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
if [ "${cp2k_random_seed}" == "random" ]; then

    # Setting the random seed
    cp2k_random_seed=$RANDOM

# Checking if the value is an integer
elif ! [ "${cp2k_random_seed}" -eq "${cp2k_random_seed}" ]; then

    # Printing error message before exiting
    echo -e "Error: The variable cp2k_random_seed has an unsupported value (${cp2k_random_seed}). Exiting..."
    exit 1
fi

# Checking which tdcycle type should be used
if [ "${tdcycle_type}" == "hq" ]; then

    # Variables
    bead_step_size=$(expr $nbeads / $tdw_count)
    bead_count1="$(( nbeads - (tds_index-1)*bead_step_size))"
    bead_count2="$(( (tds_index-1)*bead_step_size))"
    bead_configuration="k_${bead_count1}_${bead_count2}"
    lambda_current=$(echo "$((tds_index-1))/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
    tds_folder=tds.${bead_configuration}

    echo -e " * Preparing the files and directories for the optimization with bead-configuration ${bead_configuration}"

    # Checking if this optimization should be continued
    if [[ "${opt_continue^^}" == "TRUE" ]]; then
        if [ -d "${tds_folder}/cp2k" ]; then
            echo " * The folder ${tds_folder}/cp2k already exists. Checking its contents..."
            cd ${tds_folder}
            if [[ -s cp2k/cp2k.out.restart.bak-1 ]]; then

                echo -e " * The folder ${tds_folder}/cp2k seems to contain files from a previous run. Preparing the folder for the next run...\n"

                # Editing the cp2k major input file
                sed -i 's/!\&EXT_RESTART/\&EXT_RESTART/g' cp2k/cp2k.in.main
                sed -i 's/! *EXT/  EXT/g' cp2k/cp2k.in.main
                sed -i 's/!\&END EXT_RESTART/\&END EXT_RESTART/g' cp2k/cp2k.in.main

                # Removing previous error files
                if [ -f cp2k/cp2k.out.err ]; then
                    mv cp2k/cp2k.out.err cp2k/cp2k.out.err.old."$(date --rfc-3339=seconds | tr -s ' ' '_')"
                fi

                # Printing information
                echo -e "\n * The preparation of the optimization folder for the TDS with index ${tds_index} in the folder ${tds_folder} has been successfully completed.\n\n"

                # Finalization
                cd ..
                exit 0
            else
                echo " * The folder ${tds_folder}/cp2k seems to not contain files from a previous run. Preparing it newly..."
                cd ..
                rm -r ${tds_folder}/cp2k
            fi
        fi
    elif [[ "${opt_continue^^}" == "FALSE" ]]; then
        if [ -d "${tds_folder}/cp2k" ]; then
            rm -r "${tds_folder}"/cp2k
        fi
    else
        echo -e "Error: The variable opt_continue has an unsupported value (${opt_continue}). Exiting..."
        exit 1
    fi

    # Preparation of the cp2k files
    if [[ "${opt_programs}" == *"cp2k"* ]]; then

        # Preparing the simulation folders
        mkdir -p tds.${bead_configuration}/cp2k

        # Copying the CP2K input files
        if [ "${lambda_current}" == "0.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys1 tds.${bead_configuration}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys1 tds.${bead_configuration}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.opt.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        elif [ "${lambda_current}" == "1.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys2 tds.${bead_configuration}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys2 tds.${bead_configuration}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.opt.sys2 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        else
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda tds.${bead_configuration}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda tds.${bead_configuration}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.opt.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        fi

        # Adjust the CP2K input files
        sed -i "s/lambda_value_placeholder/${lambda_current}/g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s/subconfiguration_placeholder/${bead_configuration}/g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s|subsystem_folder_placeholder|../..|" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s|tds_potential_folder_placeholder|../general|g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s|cp2k_random_seed_placeholder|${cp2k_random_seed}|g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s|opt_max_steps_placeholder|${opt_max_steps}|g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s|opt_trajectory_stride_placeholder|${opt_trajectory_stride}|g" tds.${bead_configuration}/cp2k/cp2k.in.*
        sed -i "s|opt_restart_stride_placeholder|${opt_restart_stride}|g" tds.${bead_configuration}/cp2k/cp2k.in.*
    fi
elif [ "${tdcycle_type}" == "lambda" ]; then

    # Variables
    lambda_current=$(echo "$((tds_index-1))/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
    lambda_configuration=lambda_${lambda_current}
    tds_folder=tds.${lambda_configuration}

    echo -e " * Preparing the files and directories for the optimization for lambda=${lambda_current}"

    # Checking if this optimization should be continued
    if [[ "${opt_continue^^}" == "TRUE" ]]; then
        if [ -d "${tds_folder}/cp2k" ]; then
            echo " * The folder ${tds_folder}/cp2k already exists. Checking its contents..."
            cd ${tds_folder}
            if [[ -s cp2k/cp2k.out.restart.bak-1 ]]; then

                echo -e " * The folder ${tds_folder}/cp2k seems to contain files from a previous run. Preparing the folder for the next run...\n"

                # Editing the cp2k major input file
                sed -i 's/!\&EXT_RESTART/\&EXT_RESTART/g' cp2k/cp2k.in.main
                sed -i 's/! *EXT/  EXT/g' cp2k/cp2k.in.main
                sed -i 's/!\&END EXT_RESTART/\&END EXT_RESTART/g' cp2k/cp2k.in.main
                # No need to adjust the step number because in geo_opt CP2K continues from the last STEP_START_VAL value by itself (in contrast to MD simulations)

                # Removing previous error files
                if [ -f cp2k/cp2k.out.err ]; then
                    mv cp2k/cp2k.out.err cp2k/cp2k.out.err.old."$(date --rfc-3339=seconds | tr -s ' ' '_')"
                fi

                # Printing information
                echo -e "\n * The preparation of the optimization folder for the TDS with index ${tds_index} in the folder ${tds_folder} has been successfully completed.\n\n"

                # Finalization
                cd ..
                exit 0
            else
                echo " * The folder ${tds_folder}/cp2k seems to not contain files from a previous run. Preparing it newly..."
                cd ..
                rm -r ${tds_folder}/cp2k
            fi
        fi
    elif [[ "${opt_continue^^}" == "FALSE" ]]; then
        if [ -d "${tds_folder}/cp2k" ]; then
            rm -r "${tds_folder}/cp2k"
        fi
    else
        echo -e "Error: The variable opt_continue has an unsupported value (${opt_continue}). Exiting..."
        exit 1
    fi

    # Preparation of the cp2k files
    if [[ "${opt_programs}" == *"cp2k"* ]]; then

        # Preparing the simulation folder
        mkdir -p tds.${lambda_configuration}/cp2k

        # Copying the CP2K input files
        # Copying the main files
        if [ "${lambda_current}" == "0.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys1 tds.${lambda_configuration}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys1 tds.${lambda_configuration}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.opt.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        elif [ "${lambda_current}" == "1.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.sys2 tds.${lambda_configuration}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.sys2 tds.${lambda_configuration}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.opt.sys2 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        else
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda tds.${lambda_configuration}/cp2k/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda tds.${lambda_configuration}/cp2k/cp2k.in.main
            else
                echo "Error: The input file main.opt.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        fi

        # Adjust the CP2K input files
        sed -i "s/lambda_value_placeholder/${lambda_current}/g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s/subconfiguration_placeholder/${lambda_configuration}/g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s|subsystem_folder_placeholder|../..|" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s|tds_potential_folder_placeholder|../general|g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s|cp2k_random_seed_placeholder|${cp2k_random_seed}|g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s|opt_max_steps_placeholder|${opt_max_steps}|g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s|opt_trajectory_stride_placeholder|${opt_trajectory_stride}|g" tds.${lambda_configuration}/cp2k/cp2k.in.*
        sed -i "s|opt_restart_stride_placeholder|${opt_restart_stride}|g" tds.${lambda_configuration}/cp2k/cp2k.in.*
    fi
fi

# Printing program completion information
echo -e "\n * The preparation of the TDS with index ${tds_index} in the folder ${tds_folder} has been successfully completed.\n\n"
