#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_ce_prepare_one_msp.sh <system 1 basename> <system 2 basename> <subsystem>

Has to be run in the root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "3" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 3"
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

handle_snapshot_continuation() {

    # Variables
    crosseval_folder_local="${1}"
    restart_id_local="${2}"

    # Checking if this snapshot has already been prepared and should be skipped
    if [[ -f ${crosseval_folder_local}/snapshot-${restart_id_local}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_local}/snapshot-${restart_id_local}/ipi/ipi.in.restart ]]; then

        # Printing some information
        echo " * Snapshot ${restart_id_local} has already been prepared and ce_continue=true, skipping this snapshot..."

        # Checking if the snapshot has already been completed successfully
        if energy_line_old="$(grep "^ ${restart_id_local}" ${crosseval_folder_local}/ce_potential_energies.txt &> /dev/null)"; then

            # Printing some information
            echo -e " * Info: There is already an entry in the common energy file for this snapshot: ${energy_line_old}"

            # Checking if the entry contains two words
            if [ "$(echo ${energy_line_old} | wc -w)" == "2" ]; then

                # Printing some information
                echo -e " * Info: This entry does seem to be valid. Removing  the existing folder and continuing with next snapshot..."

                # Removing the folder
                rm -r ${crosseval_folder_local}/snapshot-${restart_id_local} &>/dev/null || true
            else

                # Printing some information
                echo -e " * Info: This entry does seem to be invalid. Removing this entry from the common energy file and continuing with next snapshot..."
                sed -i "/^ ${restart_id_local} /d" ${crosseval_folder_local}/ce_potential_energies.txt
            fi
        fi

        # Continuing with the next snapshot
        skip_snapshot="true"
    else
        skip_snapshot="false"
    fi
}

prepare_restart() {

    # Standard error response
    trap 'error_response_std $LINENO' ERR
    
    # Variables
    tds_folder_coordinate_source=${1}
    tds_folder_potential_source=${2}    # not used currently
    restart_file=${3}
    crosseval_folder=${4}
    restart_id=${5}
    evalstate=${6}
    inputfile_ipi_ce=$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')
    if [ "${tdcycle_msp_transformation_type}" == "hq" ]; then
        if [ "${evalstate}" == "endstate" ]; then
            tdsname_local="${tdsname_endstate}"
            bead_count1_local=${bead_count1_endstate}
            bead_count2_local=${bead_count2_endstate}
        elif [[ "${evalstate}" == "initialstate" ]]; then
            tdsname_local="${tdsname_initialstate}"
            bead_count1_local=${bead_count1_initialstate}
            bead_count2_local=${bead_count2_initialstate}
        else
            echo "Error: The variable evalstate has an unsupported value. Exiting..."
            exit 1
        fi

    elif [ "${tdcycle_msp_transformation_type}" == "lambda" ]; then
        if [ "${evalstate}" == "endstate" ]; then
            tdsname_local="${tdsname_endstate}"
            lambda_currenteval_local="${lambda_endstate}"
        elif [[ "${evalstate}" == "initialstate" ]]; then
            tdsname_local="${tdsname_initialstate}"
            lambda_currenteval_local="${lambda_initialstate}"
        fi
    fi

    # Getting the cell size for the CP2K input files. We might need to use the potential source values in order to evaluate at the same potential (same GMAX values)
    # Coordinates should not matter since they come from i-PI
    trap '' ERR
    line="$(tail -n +${restart_id} ../../../md/${msp_name}/${subsystem}/${tds_folder_coordinate_source}/ipi/ipi.out.all_runs.cell | head -n 1)"
    trap 'error_response_std $LINENO' ERR
    IFS=' ' read -r -a line_array <<< "$line"
    # Not rounding up since the values have already been rounded up before the MD simulation and this is just a single force evaluation
    cell_A=$(awk -v x="${line_array[0]}" 'BEGIN{printf("%9.1f", x)}')
    cell_B=$(awk -v y="${line_array[1]}" 'BEGIN{printf("%9.1f", y)}')
    cell_C=$(awk -v z="${line_array[2]}" 'BEGIN{printf("%9.1f", z)}')
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

    # Creating the folders
    mkdir -p ${crosseval_folder}/snapshot-${restart_id}
    mkdir -p ${crosseval_folder}/snapshot-${restart_id}/ipi
    mkdir -p ${crosseval_folder}/snapshot-${restart_id}/cp2k

    # Preparing the ipi files
    bzcat ../../../md/${msp_name}/${subsystem}/${tds_folder_coordinate_source}/ipi/${restart_file} > ${crosseval_folder}/snapshot-${restart_id}/ipi/ipi.in.restart
    sed -i "/<step>/d" ${crosseval_folder}/snapshot-${restart_id}/ipi/ipi.in.restart
    cp ../../../input-files/ipi/${inputfile_ipi_ce} ${crosseval_folder}/snapshot-${restart_id}/ipi/ipi.in.main.xml
    sed -i "s|nbeads_placeholder|${nbeads}|g" ${crosseval_folder}/snapshot-${restart_id}/ipi/ipi.in.main.xml
    sed -i "s|subsystem_folder_placeholder|../../..|g" ${crosseval_folder}/snapshot-${restart_id}/ipi/ipi.in.main.xml
    sed -i "s|temperature_placeholder|${temperature}|g" ${crosseval_folder}/snapshot-${restart_id}/ipi/ipi.in.main.xml

    # Preparing the CP2K files
    for bead in $(eval echo "{1..${nbeads}}"); do
        mkdir -p ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/
        if [ "${tdcycle_msp_transformation_type}" == "lambda" ]; then

            # Copying the CP2K input files
            # Copying the main files
            if [ "${lambda_currenteval_local}" == "0.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys1 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys1 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            elif [ "${lambda_currenteval_local}" == "1.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys2 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys2 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys2 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys2 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.sys2 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.lambda ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.lambda ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi

            # Adjusting the CP2K files
            sed -i "s/tdsname_placeholder/${tdsname_local}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/lambda_value_placeholder/${lambda_currenteval_local}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*

        elif [ "${tdcycle_msp_transformation_type}" ==  "hq" ]; then

            # Copying the CP2K input files according to the bead type
            # Copying the main files
            if [ ${bead} -le "${bead_count1_local}" ]; then
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys1 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys1 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys2 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.sys2 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys2 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.sys2 ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.sys1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi

            # Adjusting the CP2K files
            sed -i "s/tdsname_placeholder/${tdsname_local}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
        fi

        # Adjusting the CP2K files
        sed -i "s/cell_dimensions_full_placeholder/${cell_A} ${cell_B} ${cell_C}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_full_rounded_placeholder/${cell_A_floor} ${cell_B_floor} ${cell_C_floor}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_odd_rounded_placeholder/${cell_A_floor_odd} ${cell_B_floor_odd} ${cell_C_floor_odd}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_rounded_placeholder/${cell_A_scaled} ${cell_B_scaled} ${cell_C_scaled}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/cell_dimensions_scaled_odd_rounded_placeholder/${cell_A_scaled_odd} ${cell_B_scaled_odd} ${cell_C_scaled_odd}/g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|subsystem_folder_placeholder|../../../..|" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|tds_potential_folder_placeholder|../../../../${tdsname_local}/general|g" ${crosseval_folder}/snapshot-${restart_id}/cp2k/bead-${bead}/cp2k.in.*
    done

    # Preparing the iqi files if required
    if [[ "${md_programs}" == *"iqi"* ]]; then

        # Variables
        inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
        inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

        # Preparing the i-QI files and folders
        mkdir -p ${crosseval_folder}/snapshot-${restart_id}/iqi
        cp ../../../input-files/iqi/${inputfile_iqi_md} ${crosseval_folder}/snapshot-${restart_id}/iqi/iqi.in.main.xml
        cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${crosseval_folder}/snapshot-${restart_id}/iqi/
        sed -i "s|subsystem_folder_placeholder|../../..|g" ${crosseval_folder}/snapshot-${restart_id}/iqi/iqi.in.main.xml
    fi
}

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
subsystem=${3}
msp_name=${system1_basename}_${system2_basename}
nbeads="$(grep -m 1 "^nbeads=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfile_ipi_ce="$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_msp_transformation_type="$(grep -m 1 "^tdcycle_msp_transformation_type=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_first_restart_id="$(grep -m 1 "^ce_first_restart_ID_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_stride="$(grep -m 1 "^ce_stride_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
umbrella_sampling="$(grep -m 1 "^umbrella_sampling=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_type="$(grep -m 1 "^ce_type_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_continue="$(grep -m 1 "^ce_continue=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_ce_general="$(grep -m 1 "^inputfolder_cp2k_ce_general_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_ce_specific="$(grep -m 1 "^inputfolder_cp2k_ce_specific_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
temperature="$(grep -m 1 "^temperature=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total=" ${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$((tdw_count_total + 1))"


# Printing some information
echo -e  "\n\n *** Preparing the cross evaluations of the FES ${msp_name} (hqf_ce_prepare_one_msp.sh) ***\n"

# Checking in the input values
if [ ! "$ce_stride" -eq "$ce_stride" ] 2>/dev/null; then
    echo -e "\nError: The parameter crosseval_trajectory_stride in the configuration file has an unsupported value.\n"
    exit 1
fi

# Checking if the tds_folder exists
if [ ! -d "md/${msp_name}/${subsystem}" ]; then
    echo -e "\nError: The folder md/${msp_name}/${subsystem} does not exist. Exiting\n\n" 1>&2
    exit 1
fi

# Preparing the main folder
if [ "${ce_continue^^}" == "FALSE" ]; then
    # Preparing the folders
    echo -e " * Preparing the main folder"
    if [ -d "ce/${msp_name}/${subsystem}" ]; then
        rm -r ce/${msp_name}/${subsystem}
    fi
fi
mkdir -p ce/${msp_name}/${subsystem}
cd ce/${msp_name}/${subsystem}

# Preparing the shared input files
echo -e " * Copying general simulation files"
system_ID=1
for system_basename in ${system1_basename} ${system2_basename}; do
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${system_ID}.vmd.psf
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${system_ID}.pdb
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${system_ID}.prm
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${system_ID}.pdbx
    (( system_ID += 1 ))
done
cp ../../../input-files/mappings/curated/${system1_basename}_${system2_basename} ./system.mcs.mapping
if [ -f ../../../input-files/mappings/hr/${system1_basename}_${system2_basename} ]; then
    cp ../../../input-files/mappings/hr/${system1_basename}_${system2_basename} ./system.mcs.mapping.hr || true   # Parallel robustness
fi
if [ -f "TD_windows.list" ]; then
    rm TD_windows.list
fi

# Preparing the shared CP2K input files
hqh_fes_prepare_one_fes_common.sh

# Copying the CP2K sub input files
for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/ -type f -name "sub*"); do
    cp $file cp2k.in.${file/*\/}
done
# The sub files in the specific folder are copied at the end so that they can override the ones of the general CP2K input folder
for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/ -type f -name "sub*"); do
    cp $file cp2k.in.${file/*\/}
done

# Copying the equilibration coordinate files (just for CP2K as some initial coordinate files which are not really used by CP2K)
cp ../../../md/${msp_name}/${subsystem}/system.*.initial.pdb ./

# Creating the list of intermediate states
#echo md/methanol_ethane/L/*/ | tr " " "\n" | awk -F '/' '{print $(NF-1)}' >  TD_windows.states

# Loop for each TD window/step
for tdw_index in $(seq 1 $((tds_count_total-1)) ); do

    # Variables
    tds_index_initialstate=${tdw_index}
    tds_index_endstate=$((tdw_index+1))
    tdsname_initialstate=tds-${tds_index_initialstate}
    tdsname_endstate=tds-${tds_index_endstate}
    tds_initialstate_msp_configuration="$(grep -m 1 "^tds_msp_configuration=" ${tdsname_initialstate}/general/configuration.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    tds_endstate_msp_configuration="$(grep -m 1 "^tds_msp_configuration=" ${tdsname_endstate}/general/configuration.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

    if [ "${tdcycle_msp_transformation_type}" = "hq" ]; then

        # Variables
        bead_counts_initialstate="${tds_initialstate_msp_configuration/k_}"
        bead_count1_initialstate="${bead_counts_initialstate/_*}"
        bead_count2_initialstate="${bead_counts_initialstate/*_}"
        bead_counts_endstate="${tds_endstate_msp_configuration/k_}"
        bead_count1_endstate="${bead_counts_endstate/_*}"
        bead_count2_endstate="${bead_counts_endstate/*_}"

    elif [ "${tdcycle_msp_transformation_type}" = "lambda" ]; then

        # Adjusting lambda_initialstate and lambda_endstate
        lambda_initialstate=${tds_initialstate_msp_configuration/lambda_}
        lambda_endstate=${tds_endstate_msp_configuration/lambda_}
    fi

    # Variables
    crosseval_folder_fw="${tdsname_initialstate}_${tdsname_endstate}"     # TDS folder1 (positions, sampling) is evaluated at mdfolder2's potential: samplingfolder-potentialfolder
    crosseval_folder_bw="${tdsname_endstate}_${tdsname_initialstate}"     # Opposite of fw

    echo "${tdsname_initialstate} ${tdsname_endstate}" >> TD_windows.list           # Does not include the stationary evaluations naturally
    
    # Printing some information
    echo -e "\n * Preparing TDW ${tdw_index}"
    
    # Creating required folders
    mkdir -p ${crosseval_folder_fw}
    mkdir -p ${crosseval_folder_bw}

    # Removing old prepared restart files
    rm ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/*restart_0* &>/dev/null || true
    rm ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/*restart_0* &>/dev/null || true
    rm ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/*all_runs* &>/dev/null || true
    rm ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/*all_runs* &>/dev/null || true

    # Note: We are not removing any uncompressed or empty restart files because we are dependent on a complete set of restart files even if one is not proper, because the cell/property files contain the associated information in corresponding lines

    # Compressing all restart files which are uncompressed
    for restart_file in $(find ../../../md/${msp_name}/${subsystem}/{${tdsname_initialstate},${tdsname_endstate}}/ipi -iregex ".*ipi.out.run.*restart_[0-9]+$") ; do
        bzip2 -f $restart_file
    done

    # Recompressing all restart files which were compressed with gz (backward compatibility) Todo: Remove later
    for restart_file in $(find ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi -iregex ".*ipi.out.run.*restart_[0-9]+.gz$") $(find ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi -iregex ".*ipi.out.run.*restart_[0-9]+.gz$"); do
        # There were some problems with gunzip and bzip in the common way
        temp_filename=/tmp/${HQ_STARTDATE_BS}_$(basename ${restart_file/.gz})
        zcat $restart_file > ${temp_filename}
        sleep 0.2
        cat ${temp_filename} | bzip2 > ${restart_file/.gz/.bz2}
        rm ${temp_filename} &>/dev/null
        rm ${restart_file} &>/dev/null
    done

    # Determining the number of restart files of the two TDS simulations
    trap '' ERR
    restartfile_count_MD1=$(ls ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/ | grep "restart_[0-9]*.bz2" | grep -v restart_0 | wc -l)   # works for .bz2 endings. i-PI restart files have no preceding zeros in their restart IDs
    restartfile_count_MD2=$(ls ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/ | grep "restart_[0-9]*.bz2" | grep -v restart_0 | wc -l)
    trap 'error_response_std $LINENO' ERR
    if [[ "${restartfile_count_MD1}" == "0" || "${restartfile_count_MD2}" == "0" ]]; then

        # Printing error message
        echo "   * Error: One of the MD simulation does not have any restart files (with restart ID other than 0). Exiting..."

        # Exiting
        exit 1
    fi

    # Checking if there are enough restart files
    if [[ "${ce_first_restart_id}" -gt "${restartfile_count_MD1}" ]]; then
        echo "   * Warning: For thermodynamic window ${tdw_index} there are less snapshots (${restartfile_count_MD1}) for the initial state (${tdsname_initialstate}) required (ce_first_restart_id=${ce_first_restart_id}). Skipping this thermodynamic window."
        continue
    elif [[ "${ce_first_restart_id}" -gt "${restartfile_count_MD2}" ]]; then
        echo "   * Warning: For thermodynamic window ${tdw_index} there are less snapshots (${restartfile_count_MD2}) for the end state (${tdsname_endstate}) than required (ce_first_restart_id=${ce_first_restart_id}). Skipping this thermodynamic window."
        continue
    fi

    # Preparing the restart files
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/ | grep "restart_[0-9]*.bz2" | grep -v restart_0) ; do
        cp ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/$file ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/ipi.out.all_runs.restart_${counter}.bz2 || true
        counter=$((counter + 1))
    done
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/ | grep "restart_[0-9]*.bz2" | grep -v restart_0) ; do
        cp ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/$file ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/ipi.out.all_runs.restart_${counter}.bz2 || true
        counter=$((counter + 1))
    done

    # Uniting all the ipi property files (previous all_runs files have already been cleaned)
    # Skipping the very first entry (corresponding to restart_0) because during successive runs the values might be duplicate (last value of previous run being the same as the first of the next one if the former has terminated without problems)
    # Even though now that we set the first step to 1 in the ipi input file, the very first run produces no property and restart files in the beginning. Only successive runs do that. Thus we miss the first real snapshot of the first run...
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/*properties)"
    for property_file in ${property_files}; do
        cat ${property_file} | (grep -v "^#" || true)  | tail -n +2 > ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/ipi.out.all_runs.properties
    done
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/*properties)"
    for property_file in ${property_files}; do
        cat ${property_files} | ( grep -v "^#" || true ) | tail -n +2 > ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/ipi.out.all_runs.properties
    done

    # Uniting all the ipi cell files (previous all_runs files have already been cleaned)
    cell_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/*cell)"
    for cell_file in ${cell_files}; do
        tail -n +3 ${cell_file} >> ../../../md/${msp_name}/${subsystem}/${tdsname_initialstate}/ipi/ipi.out.all_runs.cell
    done
    cell_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/*cell)"
    for cell_file in ${cell_files}; do
        tail -n +3 ${cell_file} >> ../../../md/${msp_name}/${subsystem}/${tdsname_endstate}/ipi/ipi.out.all_runs.cell
    done

    # Loop for preparing the restart files in tds_folder 1 (forward evaluation)
    echo -e "\n   * Preparing the snapshots for the forward cross-evaluation."
    for restart_id in $(seq ${ce_first_restart_id} ${restartfile_count_MD1}); do

        # Applying the crosseval trajectory stride
        mod=$(( (restart_id-ce_first_restart_id) % ce_stride ))
        if [ "${mod}" -eq "0" ]; then

            # Printing some information
            echo "     * Preparing snapshot ${restart_id}"

            # Checking if the continuation mode is enabled
            if [ "${ce_continue^^}" == "TRUE" ]; then

                # Checking if this snapshot has already been prepared and should be skipped
                handle_snapshot_continuation ${crosseval_folder_fw} ${restart_id}
                if [ "${skip_snapshot}" == "true" ]; then
                    # Continuing with the next snapshot
                    continue
                fi
            fi

            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_fw}/snapshot-${restart_id}/ ]; then
                rm -r ${crosseval_folder_fw}/snapshot-${restart_id}/
            fi

            # Preparing the snapshot folder
            restart_file=ipi.out.all_runs.restart_${restart_id}.bz2
            prepare_restart ${tdsname_initialstate} ${tdsname_endstate} ${restart_file} ${crosseval_folder_fw} ${restart_id} "endstate"

        else
            echo "     * Snapshot ${restart_id} will be skipped due to the crosseval trajectory stride..."
            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_fw}/snapshot-${restart_id}/ ]; then
                rm -r ${crosseval_folder_fw}/snapshot-${restart_id}/
                echo "       * Deleting the previously prepared crosseval folder of snapshot ${restart_id} due to the crosseval trajectory stride."
            fi
        fi
    done

    # Loop for preparing the restart files in tdsname_endstate (backward evaluation)
    echo -e "\n   * Preparing the snapshots for the backward cross-evaluation."
    for restart_id in $(seq ${ce_first_restart_id} ${restartfile_count_MD2}); do

        # Applying the crosseval trajectory stride
        mod=$(( (restart_id-ce_first_restart_id) % ce_stride ))
        if [ "${mod}" -eq "0" ]; then

            # Printing some information
            echo "     * Preparing snapshot ${restart_id}"

            # Checking if this snapshot has already been prepared and should be skipped
            if [ "${ce_continue^^}" == "TRUE" ]; then

                # Checking if this snapshot has already been prepared and should be skipped
                handle_snapshot_continuation ${crosseval_folder_bw} ${restart_id}
                if [ "${skip_snapshot}" == "true" ]; then
                    # Continuing with the next snapshot
                    continue
                fi
            fi

            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_bw}/snapshot-${restart_id}/ ]; then
                rm -r ${crosseval_folder_bw}/snapshot-${restart_id}/
            fi

            # Preparing the snapshot folder
            restart_file=ipi.out.all_runs.restart_${restart_id}.bz2
            prepare_restart ${tdsname_endstate} ${tdsname_initialstate} ${restart_file} ${crosseval_folder_bw} ${restart_id} "initialstate"

        else
            echo "     * Snapshot ${restart_id} will be skipped due to the crosseval trajectory stride..."
            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_bw}/snapshot-${restart_id}/ ]; then
                rm -r ${crosseval_folder_bw}/snapshot-${restart_id}/
                echo "       * Deleting the previously prepared crosseval folder of snapshot ${restart_id} due to the crosseval trajectory stride."
            fi
        fi
    done

    if [ "${umbrella_sampling}" == "true" ]; then
        # Variables
        crosseval_folder_sn1="${tdsname_initialstate}-${tdsname_initialstate}"    # Stationary
        crosseval_folder_sn2="${tdsname_endstate}-${tdsname_endstate}"

        # Only if first TD window
        if [[ "${tdw_index}" == "1" ]]; then

            # Loop for preparing the restart files in tdsname_initialstate
            echo -e "\n   * Preparing the snapshots for the re-evaluation of the initial state (${tdsname_initialstate})."
            for restart_id in $(seq ${ce_first_restart_id} ${restartfile_count_MD1}); do

                # Applying the crosseval trajectory stride
                mod=$(( (restart_id-ce_first_restart_id) % ce_stride ))
                if [ "${mod}" -eq "0" ]; then

                    # Printing some information
                    echo "     * Preparing snapshot ${restart_id}"

                    # Checking if this snapshot has already been prepared and should be skipped
                    if [ "${ce_continue^^}" == "TRUE" ]; then

                        # Checking if this snapshot has already been prepared and should be skipped
                        handle_snapshot_continuation ${crosseval_folder_sn1} ${restart_id}
                        if [ "${skip_snapshot}" == "true" ]; then
                            # Continuing with the next snapshot
                            continue
                        fi
                    fi

                    # Removing the snapshot folder if it exists already
                    if [ -d ${crosseval_folder_sn1}/snapshot-${restart_id}/ ]; then
                        rm -r ${crosseval_folder_sn1}/snapshot-${restart_id}/
                    fi

                    # Preparing the snapshot folder
                    restart_file=ipi.out.all_runs.restart_${restart_id}.bz2
                    prepare_restart ${tdsname_initialstate} ${tdsname_initialstate} ${restart_file} ${crosseval_folder_sn1} ${restart_id} "initialstate"

                else
                    echo "     * Snapshot ${restart_id} will be skipped due to the crosseval trajectory stride..."
                    # Removing the snapshot folder if it exists already
                    if [ -d ${crosseval_folder_sn1}/snapshot-${restart_id}/ ]; then
                        rm -r ${crosseval_folder_sn1}/snapshot-${restart_id}/
                        echo "       * Deleting the previously prepared crosseval folder of snapshot ${restart_id} due to the crosseval trajectory stride."
                    fi
                fi
            done
        fi
        
        # Loop for preparing the restart files in tdsname_endstate
        echo -e "\n   * Preparing the snapshots for the re-evaluation of the end state (${tdsname_endstate})."
        for restart_id in $(seq ${ce_first_restart_id} ${restartfile_count_MD2}); do

            # Applying the crosseval trajectory stride
            mod=$(( (restart_id-ce_first_restart_id) % ce_stride ))
            if [ "${mod}" -eq "0" ]; then

                # Printing some information
                echo "     * Preparing snapshot ${restart_id}"

                # Checking if this snapshot has already been prepared and should be skipped
                if [ "${ce_continue^^}" == "TRUE" ]; then

                    # Checking if this snapshot has already been prepared and should be skipped
                    handle_snapshot_continuation ${crosseval_folder_sn2} ${restart_id}
                    if [ "${skip_snapshot}" == "true" ]; then
                        # Continuing with the next snapshot
                        continue
                    fi
                fi

                # Removing the snapshot folder if it exists already
                if [ -d ${crosseval_folder_sn2}/snapshot-${restart_id}/ ]; then
                    rm -r ${crosseval_folder_sn2}/snapshot-${restart_id}/
                fi

                # Preparing the snapshot folder
                restart_file=ipi.out.all_runs.restart_${restart_id}.bz2
                prepare_restart ${tdsname_endstate} ${tdsname_endstate} ${restart_file} ${crosseval_folder_sn2} ${restart_id} "endstate"

            else
                echo "     * Snapshot ${restart_id} will be skipped due to the crosseval trajectory stride..."
                # Removing the snapshot folder if it exists already
                if [ -d ${crosseval_folder_sn2}/snapshot-${restart_id}/ ]; then
                    rm -r ${crosseval_folder_sn2}/snapshot-${restart_id}/
                    echo "       * Deleting the previously prepared crosseval folder of snapshot ${restart_id} due to the crosseval trajectory stride."
                fi
            fi
        done
    fi
done

cd ../../../