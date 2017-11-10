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

prepare_restart() {

    # Standard error response
    trap 'error_response_std $LINENO' ERR
    
    # Variables
    tds_folder_coordinate_source=${1}
    tds_folder_potential_source=${2}
    restart_file=${3}
    crosseval_folder=${4}
    restart_ID=${5}
    evalstate=${6}
    inputfile_ipi_ce=$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')
    if [ "${tdcycle_type}" == "hq" ]; then
        if [ "${evalstate}" == "endstate" ]; then
            subconfiguration_local="${bead_configuration_endstate}"
            bead_count1_local=${bead_count1_endstate}
            bead_count2_local=${bead_count2_endstate}
        elif [[ "${evalstate}" == "initialstate" ]]; then
            subconfiguration_local="${bead_configuration_initialstate}"
            bead_count1_local=${bead_count1_initialstate}
            bead_count2_local=${bead_count2_initialstate}
        else
            echo "Error: The variable evalstate has an unsupported value. Exiting..."
            exit 1
        fi

    elif [ "${tdcycle_type}" == "lambda" ]; then
        if [ "${evalstate}" == "endstate" ]; then
            subconfiguration_local="${lambda_configuration_endstate}"
            lambda_currenteval_local="${lambda_endstate}"
        elif [[ "${evalstate}" == "initialstate" ]]; then
            subconfiguration_local="${lambda_configuration_initialstate}"
            lambda_currenteval_local="${lambda_initialstate}"
        fi
    fi

    # Getting the cell size for the CP2K input files. We might need to use the potential source values in order to evaluate at the same potential (same GMAX values)
    # Coordinates should not matter since they come from i-PI
    trap '' ERR
    line="$(tail -n +${restart_ID} ../../../md/${msp_name}/${subsystem}/${tds_folder_coordinate_source}/ipi/ipi.out.all_runs.cell | head -n 1)"
    trap 'error_response_std $LINENO' ERR
    IFS=' ' read -r -a line_array <<< "$line"
    # Not rounding up since the values have already been rounded up before the MD simulation and this is just a single force evaluation
    cell_A=$(awk -v x="${line_array[0]}" 'BEGIN{printf("%9.1f", x)}')
    cell_B=$(awk -v y="${line_array[1]}" 'BEGIN{printf("%9.1f", y)}')
    cell_C=$(awk -v z="${line_array[2]}" 'BEGIN{printf("%9.1f", z)}')
    # Computing the GMAX values for CP2K
    gmax_A=${cell_A/.*}
    gmax_B=${cell_B/.*}
    gmax_C=${cell_C/.*}
    gmax_A_scaled=$((gmax_A*cell_dimensions_scaling_factor))
    gmax_B_scaled=$((gmax_B*cell_dimensions_scaling_factor))
    gmax_C_scaled=$((gmax_C*cell_dimensions_scaling_factor))
    for value in gmax_A gmax_B gmax_C gmax_A_scaled gmax_B_scaled gmax_C_scaled; do
        mod=$((${value}%2))
        if [ "${mod}" == "0" ]; then
            eval ${value}_odd=$((${value}+1))
        else
            eval ${value}_odd=$((${value}))
        fi
    done

    # Creating the folders
    mkdir -p ${crosseval_folder}/snapshot-${restart_ID}
    mkdir -p ${crosseval_folder}/snapshot-${restart_ID}/ipi
    mkdir -p ${crosseval_folder}/snapshot-${restart_ID}/cp2k

    # Preparing the ipi files
    cp ../../../md/${msp_name}/${subsystem}/${tds_folder_coordinate_source}/ipi/${restart_file} ${crosseval_folder}/snapshot-${restart_ID}/ipi/ipi.in.restart
    sed -i "/<step>/d" ${crosseval_folder}/snapshot-${restart_ID}/ipi/ipi.in.restart
    cp ../../../input-files/ipi/${inputfile_ipi_ce} ${crosseval_folder}/snapshot-${restart_ID}/ipi/ipi.in.main.xml
    sed -i "s|nbeads=.*>|nbeads='${nbeads}'>|g" ${crosseval_folder}/snapshot-${restart_ID}/ipi/ipi.in.main.xml
    sed -i "s|subsystem_folder|../../..|g" ${crosseval_folder}/snapshot-${restart_ID}/ipi/ipi.in.main.xml

    # Preparing the CP2K files
    for bead in $(eval echo "{1..${nbeads}}"); do
        mkdir -p ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/
        if [ "${tdcycle_type}" == "lambda" ]; then

            # Copying the CP2K input files
            # Copying the main files
            if [ "${lambda_currenteval_local}" == "0.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            elif [ "${lambda_currenteval_local}" == "1.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.lambda ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.lambda ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi
            # Copying the sub files
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/ -type f -name "sub*"); do
                cp $file  ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done
            # The sub files in the specific folder at the end so that they can override the ones of the general CP2K input folder
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/ -type f -name "sub*"); do
                cp $file  ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done

            # Adjusting the CP2K files
            sed -i "s/subconfiguration/${subconfiguration_local}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/lambda_value/${lambda_currenteval_local}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*

        elif [ "${tdcycle_type}" ==  "hq" ]; then

            # Copying the CP2K input files according to the bead type
            # Copying the main files
            if [ ${bead} -le "${bead_count1_local}" ]; then
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi
            # Copying the sub files
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/ -type f -name "sub*"); do
                cp $file ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done
            # The sub files in the specific folder at the end so that they can override the ones of the general CP2K input folder
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/ -type f -name "sub*"); do
                cp $file ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done

            # Adjusting the CP2K files
            sed -i "s/subconfiguration/${subconfiguration_local}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
        fi

        # Adjusting the CP2K files
        sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${cell_A} ${cell_B} ${cell_C}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_full_rounded/GMAX ${gmax_A} ${gmax_B} ${gmax_C}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_odd_rounded/GMAX ${gmax_A_odd} ${gmax_B_odd} ${gmax_C_odd}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_scaled_rounded/GMAX ${gmax_A_scaled} ${gmax_B_scaled} ${gmax_C_scaled}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_scaled_odd_rounded/GMAX ${gmax_A_scaled_odd} ${gmax_B_scaled_odd} ${gmax_C_scaled_odd}/g" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|subsystem_folder/|../../../../|" ${crosseval_folder}/snapshot-${restart_ID}/cp2k/bead-${bead}/cp2k.in.*
    done

    # Preparing the iqi files if required
    if [[ "${md_programs}" == *"iqi"* ]]; then

        # Variables
        inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
        inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

        # Preparing the i-QI files and folders
        mkdir -p ${crosseval_folder}/snapshot-${restart_ID}/iqi
        cp ../../../input-files/iqi/${inputfile_iqi_md} ${crosseval_folder}/snapshot-${restart_ID}/iqi/iqi.in.main.xml
        cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${crosseval_folder}/snapshot-${restart_ID}/iqi/
        sed -i "s|subsystem_folder|../../..|g" ${crosseval_folder}/snapshot-${restart_ID}/iqi/iqi.in.main.xml
    fi
}

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
system1_basename="${1}"
system2_basename="${2}"
subsystem=${3}
msp_name=${system1_basename}_${system2_basename}
nbeads="$(grep -m 1 "^nbeads=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count="$(grep -m 1 "^tdw_count=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfile_ipi_ce="$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_type="$(grep -m 1 "^tdcycle_type=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_first_restart_ID="$(grep -m 1 "^ce_first_restart_ID_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_stride="$(grep -m 1 "^ce_stride_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
umbrella_sampling="$(grep -m 1 "^umbrella_sampling=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_type="$(grep -m 1 "^ce_type_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_continue="$(grep -m 1 "^ce_continue=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_ce_general="$(grep -m 1 "^inputfolder_cp2k_ce_general_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
inputfolder_cp2k_ce_specific="$(grep -m 1 "^inputfolder_cp2k_ce_specific_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count="$((tdw_count + 1))"


# Printing some information
echo -e  "\n *** Preparing the crossevalutaions of the FES ${msp_name} (hqf_ce_prepare_one_msp.sh) ***"

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
cp ../../../input-files/mappings/${system1_basename}_${system2_basename} ./system.mcs.mapping
if [ -f "TD_windows.list" ]; then
    rm TD_windows.list
fi

# Preparing the shared CP2K input files
hqh_fes_prepare_one_fes_common.sh ${nbeads} ${tdw_count} ${system1_basename} ${system2_basename} ${subsystem} ${ce_type} ${md_programs}

# Copying the equilibration coordinate files (just for CP2K as some initial coordinate files which are not really used by CP2K)
cp ../../../eq/${msp_name}/${subsystem}/system.*.eq.pdb ./

# Creating the list of intermediate states
#echo md/methanol_ethane/L/*/ | tr " " "\n" | awk -F '/' '{print $(NF-1)}' >  TD_windows.states

if [ "${tdcycle_type}" = "hq" ]; then

    # Checking if nbeads and tdw_count are compatible
    echo -e -n " * Checking if the variables <nbeads> and <tdw_count> are compatible..."
    trap '' ERR
    mod="$(expr ${nbeads} % ${tdw_count})"
    trap 'error_response_std $LINENO' ERR
    if [ "${mod}" != "0" ]; then
        echo " * The variables <nbeads> and <tdw_count> are not compatible. <nbeads> has to be divisible by <tdw_count>."
        exit
    fi
    echo " OK"

    # Computing the bead step size
    bead_step_size=$((nbeads/tdw_count))

fi

# Loop for each TD window/step
for window_no in $(seq 1 $((tds_count-1)) ); do

    if [ "${tdcycle_type}" = "hq" ]; then
        
        # Setting the variables
        bead_count1_initialstate="$((nbeads-(window_no-1)*bead_step_size))"
        bead_count1_endstate="$((nbeads-window_no*bead_step_size))"
        bead_count2_initialstate="$(( (window_no-1) * bead_step_size ))"
        bead_count2_endstate="$((window_no*bead_step_size))"
        bead_configuration_initialstate="k_${bead_count1_initialstate}_${bead_count2_initialstate}"
        bead_configuration_endstate="k_${bead_count1_endstate}_${bead_count2_endstate}"
        tds_folder_initialstate="tds.k_${bead_count1_initialstate}_${bead_count2_initialstate}"
        tds_folder_endstate="tds.k_${bead_count1_endstate}_${bead_count2_endstate}"

    elif [ "${tdcycle_type}" = "lambda" ]; then

        # Adjusting lambda_initialstate and lambda_endstate
        lambda_initialstate=$(echo "$((window_no-1))/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        lambda_endstate=$(echo "${window_no}/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        #lambda_initialstate=$(echo "$((window_no-1))/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 5 )
        #lambda_initialstate=${lambda_initialstate:0:5}
        #lambda_endstate=$(echo "${window_no}/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 5 )
        #lambda_endstate=${lambda_endstate:0:5}
        lambda_configuration_initialstate=lambda_${lambda_initialstate}
        lambda_configuration_endstate=lambda_${lambda_endstate}
        tds_folder_initialstate="tds.lambda_${lambda_initialstate}"
        tds_folder_endstate="tds.lambda_${lambda_endstate}"
    fi

    # Variables
    crosseval_folder_fw="${tds_folder_initialstate}-${tds_folder_endstate}"     # TDS folder1 (positions, sampling) is evaluated at mdfolder2's potential: samplingfolder-potentialfolder
    crosseval_folder_bw="${tds_folder_endstate}-${tds_folder_initialstate}"     # Opposite of fw

    echo "${tds_folder_initialstate} ${tds_folder_endstate}" >> TD_windows.list           # Does not include the stationary evaluations naturally
    
    # Printing some information
    echo -e " * Preparing TD window ${window_no}"
    
    # Creating required folders
    mkdir -p ${crosseval_folder_fw}
    mkdir -p ${crosseval_folder_bw}

    # Removing old prepared restart files
    rm ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/*restart_0* || true
    rm ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/*restart_0* || true
    rm ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/*all_runs* || true
    rm ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/*all_runs* || true

    # Determining the number of restart files of the two TDS simulations
    restartfile_count_MD1=$(ls ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)
    restartfile_count_MD2=$(ls ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)

    # Checking if there are enough restart files
    if [[ "${ce_first_restart_ID}" -gt "${restartfile_count_MD1}" ]]; then
        echo " * Warning: For thermodynamic window ${window_no} there are less snapshots (${restartfile_count_MD1}) for the initial state (${tds_folder_initialstate}) required (ce_first_restart_ID=${ce_first_restart_ID}). Skipping this thermodynamic window."
        continue
    elif [[ "${ce_first_restart_ID}" -gt "${restartfile_count_MD2}" ]]; then
        echo " * Warning: For thermodynamic window ${window_no} there are less snapshots (${restartfile_count_MD2}) for the end state (${tds_folder_endstate}) than required (ce_first_restart_ID=${ce_first_restart_ID}). Skipping this thermodynamic window."
        continue
    fi

    # Preparing the restart files
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/ | grep restart_ | grep -v restart_0) ; do
        cp ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/$file ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/ipi.out.all_runs.restart_${counter} || true
        counter=$((counter + 1))
    done
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/ | grep restart_ | grep -v restart_0) ; do
        cp ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/$file ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/ipi.out.all_runs.restart_${counter} || true
        counter=$((counter + 1))
    done

    # Uniting all the ipi property files (previous all_runs files have already been cleaned)
    # Skipping the very first entry (corresponding to restart_0) because during successive runs the values might be duplicate (last value of previous run being the same as the first of the next one if the former has terminated without problems)
    # Even though now that we set the first step to 1 in the ipi input file, the very first run produces no property and restart files in the beginning. Only successive runs do that. Thus we miss the first real snapshot of the first run...
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/*properties)"
    for property_file in ${property_files}; do
        cat ${property_file} | grep -v "^#" | tail -n +2 > ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/ipi.out.all_runs.properties
    done
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/*properties)"
    for property_file in ${property_files}; do
        cat ${property_files} | grep -v "^#" | tail -n +2 > ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/ipi.out.all_runs.properties
    done

    # Uniting all the ipi cell files (previous all_runs files have already been cleaned)
    cell_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/*cell)"
    for cell_file in ${cell_files}; do
        tail -n +3 ${cell_file} >> ../../../md/${msp_name}/${subsystem}/${tds_folder_initialstate}/ipi/ipi.out.all_runs.cell
    done
    cell_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/*cell)"
    for cell_file in ${cell_files}; do
        tail -n +3 ${cell_file} >> ../../../md/${msp_name}/${subsystem}/${tds_folder_endstate}/ipi/ipi.out.all_runs.cell
    done

    # Loop for preparing the restart files in tds_folder 1 (forward evaluation)
    echo -e "\n * Preparing the snapshots for the fortward cross-evaluation."
    for restart_ID in $(seq ${ce_first_restart_ID} ${restartfile_count_MD1}); do

        # Applying the crosseval trajectory stride
        mod=$(( (restart_ID-ce_first_restart_ID) % ce_stride ))
        if [ "${mod}" -eq "0" ]; then

            # Checking if this snapshot has already been prepared and should be skipped
            if [ "${ce_continue^^}" == "TRUE" ]; then
                if [[ -f ${crosseval_folder_fw}/snapshot-${restart_ID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_fw}/snapshot-${restart_ID}/ipi/ipi.in.restart ]]; then
                    echo " * Snapshot ${restart_ID} has already been prepared and ce_continue=true, skipping this snapshot..."
                    continue
                fi
            fi

            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_fw}/snapshot-${restart_ID}/ ]; then
                rm -r ${crosseval_folder_fw}/snapshot-${restart_ID}/
            fi

            # Preparing the snapshot folder
            restart_file=ipi.out.all_runs.restart_${restart_ID}
            prepare_restart ${tds_folder_initialstate} ${tds_folder_endstate} ${restart_file} ${crosseval_folder_fw} ${restart_ID} "endstate"

        else
            echo " * Snapshot ${restart_ID} will be skipped due to the crosseval trajectory stride..."
            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_fw}/snapshot-${restart_ID}/ ]; then
                rm -r ${crosseval_folder_fw}/snapshot-${restart_ID}/
                echo " * Deleting the previously prepared crosseval folder of snapshot ${restart_ID} due to the crosseval trajectory stride."
            fi
        fi
    done

    # Loop for preparing the restart files in tds_folder_endstate (backward evaluation)
    echo -e "\n * Preparing the snapshots for the backward cross-evaluation."
    for restart_ID in $(seq ${ce_first_restart_ID} ${restartfile_count_MD2}); do

        # Applying the crosseval trajectory stride
        mod=$(( (restart_ID-ce_first_restart_ID) % ce_stride ))
        if [ "${mod}" -eq "0" ]; then

            # Checking if this snapshot has already been prepared and should be skipped
            if [ "${ce_continue^^}" == "TRUE" ]; then
                if [[ -f ${crosseval_folder_bw}/snapshot-${restart_ID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_bw}/snapshot-${restart_ID}/ipi/ipi.in.restart ]]; then
                    echo " * Snapshot ${restart_ID} has already been prepared and ce_continue=true, skipping this snapshot..."
                    continue
                fi
            fi

            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_bw}/snapshot-${restart_ID}/ ]; then
                rm -r ${crosseval_folder_bw}/snapshot-${restart_ID}/
            fi

            # Preparing the snapshot folder
            restart_file=ipi.out.all_runs.restart_${restart_ID}
            prepare_restart ${tds_folder_endstate} ${tds_folder_initialstate} ${restart_file} ${crosseval_folder_bw} ${restart_ID} "initialstate"

        else
            echo " * Snapshot ${restart_ID} will be skipped due to the crosseval trajectory stride..."
            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_bw}/snapshot-${restart_ID}/ ]; then
                rm -r ${crosseval_folder_bw}/snapshot-${restart_ID}/
                echo " * Deleting the previously prepared crosseval folder of snapshot ${restart_ID} due to the crosseval trajectory stride."
            fi
        fi
    done

    if [ "${umbrella_sampling}" == "true" ]; then
        # Variables
        crosseval_folder_sn1="${tds_folder_initialstate}-${tds_folder_initialstate}"    # Stationary
        crosseval_folder_sn2="${tds_folder_endstate}-${tds_folder_endstate}"

        # Only if first TD window
        if [[ "${window_no}" == "1" ]]; then

            # Loop for preparing the restart files in tds_folder_initialstate
            echo -e "\n * Preparing the snapshots for the re-evaluation of the initial state (${tds_folder_initialstate})."
            for restart_ID in $(seq ${ce_first_restart_ID} ${restartfile_count_MD1}); do

                # Applying the crosseval trajectory stride
                mod=$(( (restart_ID-ce_first_restart_ID) % ce_stride ))
                if [ "${mod}" -eq "0" ]; then

                    # Checking if this snapshot has already been prepared and should be skipped
                    if [ "${ce_continue^^}" == "TRUE" ]; then
                        if [[ -f ${crosseval_folder_sn1}/snapshot-${restart_ID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_sn1}/snapshot-${restart_ID}/ipi/ipi.in.restart ]]; then
                            echo " * Snapshot ${restart_ID} has already been prepared and ce_continue=true, skipping this snapshot..."
                            continue
                        fi
                    fi

                    # Removing the snapshot folder if it exists already
                    if [ -d ${crosseval_folder_sn1}/snapshot-${restart_ID}/ ]; then
                        rm -r ${crosseval_folder_sn1}/snapshot-${restart_ID}/
                    fi

                    # Preparing the snapshot folder
                    restart_file=ipi.out.all_runs.restart_${restart_ID}
                    prepare_restart ${tds_folder_initialstate} ${tds_folder_initialstate} ${restart_file} ${crosseval_folder_sn1} ${restart_ID} "initialstate"

                else
                    echo " * Snapshot ${restart_ID} will be skipped due to the crosseval trajectory stride..."
                    # Removing the snapshot folder if it exists already
                    if [ -d ${crosseval_folder_sn1}/snapshot-${restart_ID}/ ]; then
                        rm -r ${crosseval_folder_sn1}/snapshot-${restart_ID}/
                        echo " * Deleting the previously prepared crosseval folder of snapshot ${restart_ID} due to the crosseval trajectory stride."
                    fi
                fi
            done
        fi
        
        # Loop for preparing the restart files in tds_folder_endstate
        echo -e "\n * Preparing the snapshots for the re-evaluation of the the end state (${tds_folder_endstate})."
        for restart_ID in $(seq ${ce_first_restart_ID} ${restartfile_count_MD2}); do

            # Applying the crosseval trajectory stride
            mod=$(( (restart_ID-ce_first_restart_ID) % ce_stride ))
            if [ "${mod}" -eq "0" ]; then

                # Checking if this snapshot has already been prepared and should be skipped
                if [ "${ce_continue^^}" == "TRUE" ]; then
                    if [[ -f ${crosseval_folder_sn2}/snapshot-${restart_ID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_sn2}/snapshot-${restart_ID}/ipi/ipi.in.restart ]]; then
                        echo " * Snapshot ${restart_ID} has already been prepared and ce_continue=true, skipping this snapshot..."
                        continue
                    fi
                fi

                # Removing the snapshot folder if it exists already
                if [ -d ${crosseval_folder_sn2}/snapshot-${restart_ID}/ ]; then
                    rm -r ${crosseval_folder_sn2}/snapshot-${restart_ID}/
                fi

                # Preparing the snapshot folder
                restart_file=ipi.out.all_runs.restart_${restart_ID}
                prepare_restart ${tds_folder_endstate} ${tds_folder_endstate} ${restart_file} ${crosseval_folder_sn2} ${restart_ID} "endstate"

            else
                echo " * Snapshot ${restart_ID} will be skipped due to the crosseval trajectory stride..."
                # Removing the snapshot folder if it exists already
                if [ -d ${crosseval_folder_sn2}/snapshot-${restart_ID}/ ]; then
                    rm -r ${crosseval_folder_sn2}/snapshot-${restart_ID}/
                    echo " * Deleting the previously prepared crosseval folder of snapshot ${restart_ID} due to the crosseval trajectory stride."
                fi
            fi
        done
    fi
done

cd ../../../