#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_md_prepare_one_tds.sh <tds_index>

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

# Function which checks and handles continuation of previous MD simulations
handle_md_continuation() {

    # Checking if the continuation mode is activated
    if [[ "${md_continue^^}" == "TRUE" ]]; then

        # Checking if the MD folder already exists
        if [ -d "${tdsname}"/ipi ]; then

            # Printing some information
            echo " * The folder ${tdsname} already exists. Checking its contents..."

            # Changing into the TDS directory
            cd ${tdsname}

            # Removing empty restart files
            #find ipi -iname "*restart*" -type f -empty -delete # We will not remove empty restart files, because our cross evaluations depend on all of them

            # Variables
            restart_file_no=$(ls -1v ipi/ | { grep "ipi.out.run.*restart_.*.bz2" || true; } | wc -l)

            # Checking the number of restart files
            if [[ -f ipi/ipi.in.main.xml ]] && [[ "${restart_file_no}" -ge "1" ]]; then

                echo " * The folder ${tdsname} seems to contain files from a previous run. Preparing the folder for the next run..."

                # Variables
                restart_file=$(ls -1v ipi/ | { grep "restart.*.bz2" || true; } | tail -n 1)
                run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.main.xml | grep -o "run.*" | grep -o "[0-9]*")
                run_new=$((run_old + 1))

                # Editing the ipi input file
                sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.main.xml

                # If the previous run was not started from a restart file, we need to replace the momenta and coordinate (file) tags
                # We do not distinguish the cases with an if statement because this way is more robust
                sed -i "/momenta/d" ipi/ipi.in.main.xml
                sed -i "s|<file.*initial.pdb.*|<file mode='chk'> ipi/ipi.in.sub.restart </file>|g" ipi/ipi.in.main.xml
                # If the previous run was started from a restart file, we only need to update the checkpoint tag
                sed -i "s|<file.*chk.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml

                # Preparing the restart file
                bzcat ipi/${restart_file} > ipi/ipi.in.sub.restart

                # Setting the correct current step value
                current_step_value=$(grep -m 1 "<step>" ipi/${restart_file} | grep -o "[0-9]\+")
                sed -i "s|<step> *[0-9]\+ *</step>|<step>${current_step_value}</step>|g" ipi/ipi.in.main.xml

                # Printing information
                echo -e "\n * The preparation of the simulation for the TDS with index ${tds_index} in the folder ${tdsname} has been successfully completed.\n\n"

                # Finalization
                cd ..
                exit 0
            else
                echo " * The folder ${tdsname}/ipi seems to not contain files from a previous run. Preparing it (and the cp2k folder if present) newly..."
                cd ..
                rm -r ${tdsname}/ipi
                rm -r ${tdsname}/cp2k || true
            fi
        fi
    fi
}

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
tds_index="${1}"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
inputfile_ipi_md="$(grep -m 1 "^inputfile_ipi_md_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_md_general="$(grep -m 1 "^inputfolder_cp2k_md_general_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_md_specific="$(grep -m 1 "^inputfolder_cp2k_md_specific_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_msp_transformation_type="$(grep -m 1 "^tdcycle_msp_transformation_type=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
temperature="$(grep -m 1 "^temperature=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_trajectory_centroid_stride="$(grep -m 1 "^md_trajectory_centroid_stride_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_trajectory_beads_stride="$(grep -m 1 "^md_trajectory_beads_stride_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_forces_stride="$(grep -m 1 "^md_forces_stride_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_restart_stride="$(grep -m 1 "^md_restart_stride_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_total_steps="$(grep -m 1 "^md_total_steps_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ipi_set_randomseed="$(grep -m 1 "^ipi_set_randomseed=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_activate="$(grep -m 1 "^eq_activate=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdsname="tds-${tds_index}"
tds_msp_configuration="$(grep -m 1 "^tds_msp_configuration=" ${tdsname}/general/configuration.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"


# Printing information
echo -e "\n *** Preparing the simulation files and folder for TDS ${tds_index} (hqf_md_prepare_one_tds.sh) "

# Determining the coordinate source
if [ "${eq_activate^^}" == "TRUE" ]; then
    coord_source="eq"
elif [ "${eq_activate^^}" == "FALSE" ]; then
    coord_source="opt"
else
    # Printing some information
    echo " * Error: The variables eq_activate has an unsupported value (${coord_source}). Exiting..."

    # Exiting
    exit 1
fi

# Preparing the individual MD folders for each thermodynamic state
if [ "${tdcycle_msp_transformation_type}" == "hq" ]; then

    # Variables
    bead_counts="${tds_msp_configuration/k_}"
    bead_count1="${bead_counts/_*}"
    bead_count2="${bead_counts/*_}"

    # Copying the coordinate input files from the equilibration
    cp ../../../${coord_source}/${msp_name}/${subsystem}/system.${tdsname}.${coord_source}.pdb ./system.${tdsname}.initial.pdb

    # Getting the cell size in the cp2k input files
    line=$(grep CRYST1 system.${tdsname}.initial.pdb)
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

    # Handling the MD continuation mode if needed
    handle_md_continuation

    # Creating directories
    mkdir -p ${tdsname}/cp2k
    mkdir -p ${tdsname}/ipi
    for bead in $(eval echo "{1..$nbeads}"); do
        mkdir -p ${tdsname}/cp2k/bead-${bead}
    done

    # Preparing the input files of the packages
    # Preparing the input files of i-PI
    cp ../../../input-files/ipi/${inputfile_ipi_md} ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_trajectory_centroid_stride_placeholder|${md_trajectory_centroid_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_trajectory_beads_stride_placeholder|${md_trajectory_beads_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_forces_stride_placeholder|${md_forces_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_restart_stride_placeholder|${md_restart_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|nbeads_placeholder|${nbeads}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|tdsname_placeholder|${tdsname}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|subsystem_folder_placeholder|../..|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|temperature_placeholder|${temperature}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_total_steps_placeholder|${md_total_steps}|g" ${tdsname}/ipi/ipi.in.main.xml
    if [ "${ipi_set_randomseed^^}" == "TRUE" ]; then
        sed -i "s|<seed>.*</seed>|<seed> $RANDOM </seed>|g" ${tdsname}/ipi/ipi.in.main.xml
    fi

    # Preparing the input files of CP2K
    # Preparing the bead folders for the beads of system 1
    if [ "1" -le "${bead_count1}" ]; then
        for bead in $(eval echo "{1..${bead_count1}}"); do

            # Copying the CP2K input files
            # Copying the main files
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys1 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys1 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi

            # Adjusting the CP2K input files
            sed -i "s/tdsname_placeholder/${tdsname}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s|subsystem_folder_placeholder|../../..|g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s|tds_potential_folder_placeholder|../../general|g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        done
    fi

    # Preparing the bead folders for the beads of system 2
    if [ "$((${bead_count1}+1))" -le "${nbeads}"  ]; then
        for bead in $(eval echo "{$((${bead_count1}+1))..${nbeads}}"); do

            # Copying the CP2K input files
            # Copying the main files
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys2 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys2 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.sys2 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi

            # Adjusting the CP2K input files
            sed -i "s/tdsname_placeholder/${tdsname}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s|subsystem_folder_placeholder|../../..|g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s|tds_potential_folder_placeholder|../../general|g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        done
    fi

    # Preparing the input files of i-QI
    if [[ "${md_programs}" == *"iqi"* ]]; then

        # Variables
        inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
        inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

        # Preparing the files and folders
        mkdir -p ${tdsname}/iqi
        cp ../../../input-files/iqi/${inputfile_iqi_md} ${tdsname}/iqi/iqi.in.main.xml
        cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${tdsname}/iqi/
        sed -i "s|subsystem_folder_placeholder|../..|g" ${tdsname}/iqi/iqi.in.main.xml
    fi

elif [ "${tdcycle_msp_transformation_type}" == "lambda" ]; then

    # Checking if the CP2K eq input file contains a lambda variable
    echo -n " * Checking if the lambda_value variable is present in the CP2K MD input file... "
    if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda ]; then
        lambdavalue_count="$(grep -c lambda_value ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda )"
    elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda ]; then
        lambdavalue_count="$(grep -c lambda_value ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda )"
    else
        echo "Error: The input file main.ipi.lambda could not be found in neither of the two CP2K input folders. Exiting..."
        exit 1
    fi
    if  [ ! "${lambdavalue_count}" -ge "1" ]; then
        echo "Check failed"
        echo -e "\n * Error: The CP2K equilibration input file does not contain the lambda_value variable. Exiting...\n\n"
        touch runtime/${HQ_STARTDATE_BS}/error.pipeline
        exit 1
    fi
    echo "OK"

    # Variables
    lambda="${tds_msp_configuration/lambda_}"

    # Copying the coordinate input files from the equilibration
    cp ../../../${coord_source}/${msp_name}/${subsystem}/system.${tdsname}.${coord_source}.pdb ./system.${tdsname}.initial.pdb

    # Getting the cell size in the cp2k input files
    line=$(grep CRYST1 system.${tdsname}.initial.pdb)
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


    # Handling the MD continuation mode if needed
    handle_md_continuation

    # Creating directories
    mkdir -p ${tdsname}/cp2k
    mkdir -p ${tdsname}/ipi
    for bead in $(eval echo "{1..$nbeads}"); do
        mkdir ${tdsname}/cp2k/bead-${bead}
    done

    # Preparing the input files of the packages
    # Preparing the input files of i-PI
    cp ../../../input-files/ipi/${inputfile_ipi_md} ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_trajectory_centroid_stride_placeholder|${md_trajectory_centroid_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_trajectory_beads_stride_placeholder|${md_trajectory_beads_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_forces_stride_placeholder|${md_forces_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_restart_stride_placeholder|${md_restart_stride}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|nbeads_placeholder|${nbeads}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|tdsname_placeholder|${tdsname}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|subsystem_folder_placeholder|../..|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|temperature_placeholder|${temperature}|g" ${tdsname}/ipi/ipi.in.main.xml
    sed -i "s|md_total_steps_placeholder|${md_total_steps}|g" ${tdsname}/ipi/ipi.in.main.xml
    if [ "${ipi_set_randomseed^^}" == "TRUE" ]; then
        sed -i "s|<seed>.*</seed>|<seed> $RANDOM </seed>|g" ${tdsname}/ipi/ipi.in.main.xml
    fi

    # Preparing the input files of CP2K
    for bead in $(eval echo "{1..${nbeads}}"); do

        # Copying the CP2K input files
        # Copying the main files
        if [ "${lambda}" == "0.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys1 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys1 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        elif [ "${lambda}" == "1.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.sys2 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys2 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.sys2 ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.sys2 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        else
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda ${tdsname}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        fi

        # Adjusting the CP2K input files
        sed -i "s/tdsname_placeholder/${tdsname}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/lambda_value_placeholder/${lambda}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|subsystem_folder_placeholder|../../..|g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|tds_potential_folder_placeholder|../../general|g" ${tdsname}/cp2k/bead-${bead}/cp2k.in.*
    done

    # Preparing the input files of i-QI
    if [[ "${md_programs}" == *"iqi"* ]]; then

        # Variables
        inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
        inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

        # Preparing the files and folders
        mkdir -p ${tdsname}/iqi
        cp ../../../input-files/iqi/${inputfile_iqi_md} ${tdsname}/iqi/iqi.in.main.xml
        cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${tdsname}/iqi/
        sed -i "s|subsystem_folder_placeholder|../..|g" ${tdsname}/iqi/iqi.in.main.xml
    fi
fi

# Printing program completion information
echo -e "\n * The preparation of TDS ${tds_index} has been successfully completed.\n\n"
