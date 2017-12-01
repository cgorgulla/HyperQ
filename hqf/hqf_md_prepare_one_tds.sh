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
tdcycle_type="$(grep -m 1 "^tdcycle_type=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
temperature="$(grep -m 1 "^temperature=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_stride="$(grep -m 1 "^md_stride_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count="$(grep -m 1 "^tdw_count=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ipi_set_randomseed="$(grep -m 1 "^ipi_set_randomseed=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_activate="$(grep -m 1 "^eq_activate=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"


# Printing information
echo -e "\n *** Preparing the simulation folder for TDS ${tds_index} (hqf_md_prepare_one_tds.sh) "

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
if [ "${tdcycle_type}" == "hq" ]; then

    # Checking if nbeads and tdw_count are compatible
    echo -e -n " * Checking if the variables <nbeads> and <tdw_count> are compatible..."
    trap '' ERR
    mod="$(expr ${nbeads} % ${tdw_count})"
    trap 'error_response_std $LINENO' ERR
    if [ "${mod}" != "0" ]; then
        # Printing some information
        echo " * Error: The variables <nbeads> and <tdw_count> are not compatible. <nbeads> has to be divisible by <tdw_count>. Exiting..."
        # Exiting
        exit 1
    fi
    echo " OK"

    # Variables
    bead_step_size=$(expr ${nbeads} / ${tdw_count})
    bead_count1="$(( nbeads - (tds_index-1)*bead_step_size))"
    bead_count2="$(( (tds_index-1)*bead_step_size))"
    bead_configuration="k_${bead_count1}_${bead_count2}"
    tds_folder="tds.${bead_configuration}"
    k_stepsize=$(echo "1 / $tdw_count" | bc -l)

    # Printing some information
    echo -e "\n * Preparing the files and directories for the TDS with bead-configuration ${bead_configuration}"

    # Copying the coordinate input files from the equilibration
    cp ../../../${coord_source}/${msp_name}/${subsystem}/system.${bead_configuration}.${coord_source}.pdb ./system.${bead_configuration}.initial.pdb

    # Getting the cell size in the cp2k input files
    line=$(grep CRYST1 system.${bead_configuration}.initial.pdb)
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

    # Checking if the MD folder already exists
    if [[ "${md_continue^^}" == "TRUE" ]]; then
        if [ -d "${tds_folder}" ]; then

            # Printing some information
            echo " * The folder ${tds_folder} already exists. Checking its contents..."

            # Changing into the TDS directory
            cd ${tds_folder}

            # Removing empty restart files
            find ipi -iname "*restart*" -type f -empty -delete

            # Variables
            restart_file_no=$(ls -1v ipi/ | { grep restart || true; } | wc -l)

            # Checking the number of restart files
            if [[ -f ipi/ipi.in.main.xml ]] && [[ "${restart_file_no}" -ge "1" ]]; then

                echo " * The folder ${tds_folder} seems to contain files from a previous run. Preparing the folder for the next run..."

                # Variables
                restart_file=$(ls -1v ipi/ | { grep restart || true; } | tail -n 1)
                run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.main.xml | grep -o "run.*" | grep -o "[0-9]*")
                run_new=$((run_old + 1))

                # Editing the ipi input file
                sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.main.xml

                # If the previous run was not started from a restart file, we need to replace the momenta and coordinate (file) tags
                # We do not distinguish the cases with an if statement because this way is more robust
                sed -i "/momenta/d" ipi/ipi.in.main.xml
                sed -i "s|<file.*initial.pdb.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml
                # If the previous run was started from a restart file, we only need to update the checkpoint tag
                sed -i "s|<file.*chk.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml

                # Setting the correct current step value
                current_step_value=$(grep -m 1 "<step>" ipi/${restart_file} | grep -o "[0-9]\+")
                sed -i "s|<step> *[0-9]\+ *</step>|<step>${current_step_value}</step>|g" ipi/ipi.in.main.xml

                # Printing information
                echo -e "\n * The preparation of the simulation for the TDS with index ${tds_index} in the folder ${tds_folder} has been successfully completed.\n\n"

                # Finalization
                cd ..
                exit 0
            else
                echo " * The folder ${tds_folder} seems to not contain files from a previous run. Preparing it newly..."
                cd ..
                rm -r ${tds_folder}
            fi
        fi
    fi

    # Creating directies
    mkdir ${tds_folder}
    mkdir ${tds_folder}/cp2k
    mkdir ${tds_folder}/ipi
    for bead in $(eval echo "{1..$nbeads}"); do
        mkdir ${tds_folder}/cp2k/bead-${bead}
    done

    # Preparing the input files of the packages
    # Preparing the input files of i-PI
    cp ../../../input-files/ipi/${inputfile_ipi_md} ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|md_stride_placeholder|${md_stride}|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|nbeads_placeholder|${nbeads}|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|subconfiguration_placeholder|${bead_configuration}|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|subsystem_folder_placeholder|../..|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|temperature_placeholder|${temperature}|g" ${tds_folder}/ipi/ipi.in.main.xml
    if [ "${ipi_set_randomseed^^}" == "TRUE" ]; then
        sed -i "s|<seed>.*</seed>|<seed> $RANDOM </seed>|g" ${tds_folder}/ipi/ipi.in.main.xml
    fi

    # Preparing the input files of CP2K
    # Preparing the bead folders for the beads with at lambda=0 (k=0)
    if [ "1" -le "${bead_count1}" ]; then
        for bead in $(eval echo "{1..${bead_count1}}"); do

            # Copying the CP2K input files
            # Copying the main files
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi

            # Adjusting the CP2K input files
            sed -i "s/subconfiguration_placeholder/${bead_configuration}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s|subsystem_folder_placeholder/|../../../|g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        done
    fi

    # Preparing the bead folders for the beads at lambda=1 (k=1)
    if [ "$((${bead_count1}+1))" -le "${nbeads}"  ]; then
        for bead in $(eval echo "{$((${bead_count1}+1))..${nbeads}}"); do

            # Copying the CP2K input files
            # Copying the main files
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi

            # Adjusting the CP2K input files
            sed -i "s/subconfiguration_placeholder/${bead_configuration}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s|subsystem_folder_placeholder/|../../../|g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        done
    fi

    # Preparing the input files of i-QI
    if [[ "${md_programs}" == *"iqi"* ]]; then

        # Variables
        inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
        inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

        # Preparing the files and folders
        mkdir ${tds_folder}/iqi
        cp ../../../input-files/iqi/${inputfile_iqi_md} ${tds_folder}/iqi/iqi.in.main.xml
        cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${tds_folder}/iqi/
        sed -i "s|subsystem_folder_placeholder|../..|g" ${tds_folder}/iqi/iqi.in.main.xml
    fi

elif [ "${tdcycle_type}" == "lambda" ]; then

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
    lambda_stepsize=$(echo "print(1/${tdw_count})" | python3)
    lambda_current=$(echo "$((tds_index-1))/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
    lambda_configuration=lambda_${lambda_current}
    tds_folder="tds.lambda_${lambda_current}"

    # Printing some information
    echo -e "\n * Preparing the files and directories for the TDS with lambda-configuration ${lambda_configuration}"

    # Copying the coordinate input files from the equilibration
    cp ../../../${coord_source}/${msp_name}/${subsystem}/system.${lambda_configuration}.${coord_source}.pdb ./system.${lambda_configuration}.initial.pdb

    # Getting the cell size in the cp2k input files
    line=$(grep CRYST1 system.${lambda_configuration}.initial.pdb)
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

    # Checking if the MD folder already exists
    if [[ "${md_continue^^}" == "TRUE" ]]; then
        if [ -d "${tds_folder}" ]; then

            # Printing some information
            echo " * The folder ${tds_folder} already exists. Checking its contents..."

            # Changing into the TDS directory
            cd ${tds_folder}

            # Removing empty restart files
            find ipi -iname "*restart*" -type f -empty -delete

            # Variables
            restart_file_no=$(ls -1v ipi/ | { grep restart || true; } | wc -l)

            # Checking the number of restart files
            if [[ -f ipi/ipi.in.main.xml ]] && [[ "${restart_file_no}" -ge "1" ]]; then

                # Printing some information
                echo " * The folder ${tds_folder} seems to contain files from a previous run. Preparing the folder for the next run..."

                # Variables
                restart_file=$(ls -1v ipi/ | { grep restart || true; } | tail -n 1)
                restart_file_ID=${restart_file//*_}
                run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.main.xml | grep -o "run.*" | grep -o "[0-9]*")
                run_new=$((run_old + 1))

                # Todo: (Maybe) Checking if the restart ID is larger than 1. If yes ok, if not checking if we can use file from previous run (so that we only use the second newest restart file)

                # Editing the ipi input file
                sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.main.xml

                # If the previous run was not started from a restart file, we need to replace the momenta and coordinate (file) tags
                # We do not distinguish the cases with an if statement because this way is more robust
                sed -i "/momenta/d" ipi/ipi.in.main.xml
                sed -i "s|<file.*initial.pdb.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml
                # If the previous run was started from a restart file, we only need to update the checkpoint tag
                sed -i "s|<file.*chk.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml

                # Setting the correct current step value
                current_step_value=$(grep -m 1 "<step>" ipi/${restart_file} | grep -o "[0-9]\+")
                current_step_value=$((current_step_value+1))            # Because i-PI start to count internally at 0, thus we get 99 instead of 100 for instance after 100 steps
                sed -i "s|<step> *[0-9]\+ *</step>|<step>${current_step_value}</step>|g" ipi/ipi.in.main.xml

                # Printing information
                echo -e "\n * The preparation of the simulation for the TDS with index ${tds_index} in the folder ${tds_folder} has been successfully completed.\n\n"

                # Finalization
                cd ..
                exit 0
            else
                echo " * The folder ${tds_folder} seems to not contain files from a previous run. Preparing it newly..."
                cd ..
                rm -r ${tds_folder}
            fi
        fi
    fi

    # Creating directies
    mkdir ${tds_folder}
    mkdir ${tds_folder}/cp2k
    mkdir ${tds_folder}/ipi
    for bead in $(eval echo "{1..$nbeads}"); do
        mkdir ${tds_folder}/cp2k/bead-${bead}
    done

    # Preparing the input files of the packages
    # Preparing the input files of i-PI
    cp ../../../input-files/ipi/${inputfile_ipi_md} ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|md_stride_placeholder|${md_stride}|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|nbeads_placeholder|${nbeads}|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|subconfiguration_placeholder|${lambda_configuration}|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|subsystem_folder_placeholder|../..|g" ${tds_folder}/ipi/ipi.in.main.xml
    sed -i "s|temperature_placeholder|${temperature}|g" ${tds_folder}/ipi/ipi.in.main.xml
    if [ "${ipi_set_randomseed^^}" == "TRUE" ]; then
        sed -i "s|<seed>.*</seed>|<seed> $RANDOM </seed>|g" ${tds_folder}/ipi/ipi.in.main.xml
    fi

    # Preparing the input files of CP2K
    for bead in $(eval echo "{1..${nbeads}}"); do

        # Copying the CP2K input files
        # Copying the main files
        if [ "${lambda_current}" == "0.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        elif [ "${lambda_current}" == "1.000" ]; then
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        else
            # Checking the specific folder at first to give it priority over the general folder
            if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda ]; then
                cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda ${tds_folder}/cp2k/bead-${bead}/cp2k.in.main
            else
                echo "Error: The input file main.ipi.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                exit 1
            fi
        fi

        # Adjusting the CP2K input files
        sed -i "s/subconfiguration_placeholder/${lambda_configuration}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/lambda_value_placeholder/${lambda_current}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|subsystem_folder_placeholder|../../..|g" ${tds_folder}/cp2k/bead-${bead}/cp2k.in.*
    done

    # Preparing the input files of i-QI
    if [[ "${md_programs}" == *"iqi"* ]]; then

        # Variables
        inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
        inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

        # Preparing the files and folders
        mkdir ${tds_folder}/iqi
        cp ../../../input-files/iqi/${inputfile_iqi_md} ${tds_folder}/iqi/iqi.in.main.xml
        cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${tds_folder}/iqi/
        sed -i "s|subsystem_folder_placeholder|../..|g" ${tds_folder}/iqi/iqi.in.main.xml
    fi
fi

# Printing program completion information
echo -e "\n * The preparation of the TDS with index ${tds_index} in the folder ${tds_folder} has been successfully completed.\n\n"
