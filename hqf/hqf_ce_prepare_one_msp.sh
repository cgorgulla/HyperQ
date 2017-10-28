#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_ce_prepare_one_msp.sh <system 1 basename> <system 2 basename> <subsystem>

Has to be run in the simulation folder."

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
    echo "Reason: The wrong number of arguments were provided when calling the script."
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
    echo "The error occured in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occured on line $1" 1>&2
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
    md_folder_coordinate_source=${1}
    md_folder_potential_source=${2}
    restartFile=${3}
    crosseval_folder=${4}
    restartID=${5}
    evalstate=${6}
    inputfile_ipi_ce=$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')
    if [ "${TD_cycle_type}" == "hq" ]; then
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

    elif [ "${TD_cycle_type}" == "lambda" ]; then
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
    line="$(tail -n +${restartID} ../../../md/${msp_name}/${subsystem}/${md_folder_coordinate_source}/ipi/ipi.out.all_runs.cell | head -n 1)"
    trap 'error_response_std $LINENO' ERR
    IFS=' ' read -r -a lineArray <<< "$line"
    # Not rounding up since the values have already been rounded up before the MD simulation and this is just a single force evaluation
    A=$(awk -v x="${lineArray[0]}" 'BEGIN{printf("%9.1f", x)}')
    B=$(awk -v y="${lineArray[1]}" 'BEGIN{printf("%9.1f", y)}')
    C=$(awk -v z="${lineArray[2]}" 'BEGIN{printf("%9.1f", z)}')
    # Computing the GMAX values for CP2K
    GMAX_A=${A/.*}
    GMAX_B=${B/.*}
    GMAX_C=${C/.*}
    GMAX_A_scaled=$((GMAX_A*cell_dimensions_scaling_factor))
    GMAX_B_scaled=$((GMAX_B*cell_dimensions_scaling_factor))
    GMAX_C_scaled=$((GMAX_C*cell_dimensions_scaling_factor))
    for value in GMAX_A GMAX_B GMAX_C GMAX_A_scaled GMAX_B_scaled GMAX_C_scaled; do
        mod=$((${value}%2))
        if [ "${mod}" == "0" ]; then
            eval ${value}_odd=$((${value}+1))
        else
            eval ${value}_odd=$((${value}))
        fi
    done

    # Creating the folders
    mkdir -p ${crosseval_folder}/snapshot-${restartID}
    mkdir -p ${crosseval_folder}/snapshot-${restartID}/ipi
    mkdir -p ${crosseval_folder}/snapshot-${restartID}/cp2k

    # Preparing the ipi files
    cp ../../../md/${msp_name}/${subsystem}/${md_folder_coordinate_source}/ipi/${restartFile} ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.restart
    sed -i "/<step>/d" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.restart
    cp ../../../input-files/ipi/${inputfile_ipi_ce} ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.main.xml
    sed -i "s|nbeads=.*>|nbeads='${nbeads}'>|g" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.main.xml
    sed -i "s|subsystem_folder|../../..|g" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.main.xml

    # Preparing the CP2K files
    for bead in $(eval echo "{1..${nbeads}}"); do
        mkdir -p ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/
        if [ "${TD_cycle_type}" == "lambda" ]; then

            # Copying the CP2K input files
            # Copying the main files
            if [ "${lambda_currenteval_local}" == "0.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            elif [ "${lambda_currenteval_local}" == "1.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.lambda ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.lambda ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi
            # Copying the sub files
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/ -type f -name "sub*"); do
                cp $file  ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done
            # The sub files in the specific folder at the end so that they can overrride the ones of the general CP2K input folder
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/ -type f -name "sub*"); do
                cp $file  ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done

            # Adjusting the CP2K files
            sed -i "s/subconfiguration/${subconfiguration_local}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/lambda_value/${lambda_currenteval_local}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*

        elif [ "${TD_cycle_type}" ==  "hq" ]; then

            # Copying the CP2K input files according to the bead type
            # Copying the main files
            if [ ${bead} -le "${bead_count1_local}" ]; then
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_0 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/main.ipi.k_1 ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi
            # Copying the sub files
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_general}/ -type f -name "sub*"); do
                cp $file ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done
            # The sub files in the specific folder at the end so that they can overrride the ones of the general CP2K input folder
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_ce_specific}/ -type f -name "sub*"); do
                cp $file ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done

            # Adjusting the CP2K files
            sed -i "s/subconfiguration/${subconfiguration_local}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        fi

        # Adjusting the CP2K files
        sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_full_rounded/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_odd_rounded/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_scaled_rounded/GMAX ${GMAX_A_scaled} ${GMAX_B_scaled} ${GMAX_C_scaled}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s/GMAX *cell_dimensions_scaled_odd_rounded/GMAX ${GMAX_A_scaled_odd} ${GMAX_B_scaled_odd} ${GMAX_C_scaled_odd}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|subsystem_folder/|../../../../|" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
    done

    # Preparing the iqi files if required
    if [[ "${md_programs}" == *"iqi"* ]]; then

        # Variables
        inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
        inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

        # Preparing the i-QI files and folders
        mkdir -p ${crosseval_folder}/snapshot-${restartID}/iqi
        cp ../../../input-files/iqi/${inputfile_iqi_md} ${crosseval_folder}/snapshot-${restartID}/iqi/iqi.in.main.xml
        cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${crosseval_folder}/snapshot-${restartID}/iqi/
        sed -i "s|subsystem_folder|../../..|g" ${crosseval_folder}/snapshot-${restartID}/iqi/iqi.in.main.xml

    fi
}

# Bash options
set -o pipefail

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
system1_basename="${1}"
system2_basename="${2}"
subsystem=${3}
msp_name=${system1_basename}_${system2_basename}
nbeads="$(grep -m 1 "^nbeads=" input-files/config.txt | awk -F '=' '{print $2}')"
ntdsteps="$(grep -m 1 "^ntdsteps=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfile_ipi_ce="$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"
ce_first_restart_ID="$(grep -m 1 "^ce_first_restart_ID_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
ce_stride="$(grep -m 1 "^ce_stride_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
umbrella_sampling="$(grep -m 1 "^umbrella_sampling=" input-files/config.txt | awk -F '=' '{print $2}')"
ce_type="$(grep -m 1 "^ce_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
ce_continue="$(grep -m 1 "^ce_continue=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfolder_cp2k_ce_general="$(grep -m 1 "^inputfolder_cp2k_ce_general_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfolder_cp2k_ce_specific="$(grep -m 1 "^inputfolder_cp2k_ce_specific_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
nsim="$((ntdsteps + 1))"


# Printing some information
echo -e  "\n *** Preparing the crossevalutaions of the FES ${msp_name} (hqf_ce_prepare_one_msp.sh) ***"

# Checking in the input values
if [ ! "$ce_stride" -eq "$ce_stride" ] 2>/dev/null; then
    echo -e "\nError: The parameter crosseval_trajectory_stride in the configuration file has an unsupported value.\n"
    exit 1
fi

# Checking if the md_folder exists
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
systemID=1
for system_basename in ${system1_basename} ${system2_basename}; do
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${systemID}.psf
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${systemID}.pdb
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${systemID}.prm
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${systemID}.pdbx
    (( systemID += 1 ))
done
cp ../../../input-files/mappings/${system1_basename}_${system2_basename} ./system.mcs.mapping
if [ -f "TD_windows.list" ]; then
    rm TD_windows.list
fi

# Preparing the shared CP2K input files
hqh_fes_prepare_one_fes_common.sh ${nbeads} ${ntdsteps} ${system1_basename} ${system2_basename} ${subsystem} ${ce_type} ${md_programs}

# Copying the equilibration coordinate files (just for CP2K as some initial coordinate files which are not really used by CP2K)
cp ../../../md/${msp_name}/${subsystem}/system.*.eq.pdb ./

# Creating the list of intermediate states
#echo md/methanol_ethane/L/*/ | tr " " "\n" | awk -F '/' '{print $(NF-1)}' >  TD_windows.states

if [ "${TD_cycle_type}" = "hq" ]; then

    # Checking if nbeads and ntdsteps are compatible
    echo -e -n " * Checking if the variables <nbeads> and <ntdsteps> are compatible..."
    trap '' ERR
    mod="$(expr ${nbeads} % ${ntdsteps})"
    trap 'error_response_std $LINENO' ERR
    if [ "${mod}" != "0" ]; then
        echo " * The variables <nbeads> and <ntdsteps> are not compatible. nbeads % ntdsteps should be zero"
        exit
    fi
    echo " OK"

    # Computing the bead step size
    beadStepSize=$((nbeads/ntdsteps))

fi

# Loop for each TD window/step
for window_no in $(seq 1 $((nsim-1)) ); do

    if [ "${TD_cycle_type}" = "hq" ]; then
        
        # Setting the variables
        bead_count1_initialstate="$((nbeads-(window_no-1)*beadStepSize))"
        bead_count1_endstate="$((nbeads-window_no*beadStepSize))"
        bead_count2_initialstate="$(( (window_no-1) * beadStepSize ))"
        bead_count2_endstate="$((window_no*beadStepSize))"
        bead_configuration_initialstate="k_${bead_count1_initialstate}_${bead_count2_initialstate}"
        bead_configuration_endstate="k_${bead_count1_endstate}_${bead_count2_endstate}"
        md_folder_initialstate="md.k_${bead_count1_initialstate}_${bead_count2_initialstate}"
        md_folder_endstate="md.k_${bead_count1_endstate}_${bead_count2_endstate}"

    elif [ "${TD_cycle_type}" = "lambda" ]; then

        # Adjusting lambda_initialstate and lambda_endstate
        lambda_initialstate=$(echo "$((window_no-1))/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        lambda_endstate=$(echo "${window_no}/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        #lambda_initialstate=$(echo "$((window_no-1))/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 5 )
        #lambda_initialstate=${lambda_initialstate:0:5}
        #lambda_endstate=$(echo "${window_no}/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 5 )
        #lambda_endstate=${lambda_endstate:0:5}
        lambda_configuration_initialstate=lambda_${lambda_initialstate}
        lambda_configuration_endstate=lambda_${lambda_endstate}
        md_folder_initialstate="md.lambda_${lambda_initialstate}"
        md_folder_endstate="md.lambda_${lambda_endstate}"
    fi

    # Variables
    crosseval_folder_fw="${md_folder_initialstate}-${md_folder_endstate}"     # md folder1 (positions, sampling) is evaluated at mdfolder2's potential: samplingfolder-potentialfolder
    crosseval_folder_bw="${md_folder_endstate}-${md_folder_initialstate}"     # Opposite of fw

    echo "${md_folder_initialstate} ${md_folder_endstate}" >> TD_windows.list           # Does not include the stationary evaluations naturally
    
    # Printing some information
    echo -e " * Preparing TD window ${window_no}"
    
    # Creating required folders
    mkdir -p ${crosseval_folder_fw}
    mkdir -p ${crosseval_folder_bw}

    # Removing old prepared restart files
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/*restart_0* || true
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/*restart_0* || true
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/*all_runs* || true
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/*all_runs* || true

    # Determining the number of restart files of the two md simulations
    restartFileCountMD1=$(ls ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)
    restartFileCountMD2=$(ls ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)

    # Checking if there are enough restart files
    if [[ "${ce_first_restart_ID}" -gt "${restartFileCountMD1}" ]]; then
        echo " * Warning: For thermodynamic window ${window_no} there are less snapshots (${restartFileCountMD1}) for the initial state (${md_folder_initialstate}) required (ce_first_restart_ID=${ce_first_restart_ID}). Skipping this thermodynamic window."
        continue
    elif [[ "${ce_first_restart_ID}" -gt "${restartFileCountMD2}" ]]; then
        echo " * Warning: For thermodynamic window ${window_no} there are less snapshots (${restartFileCountMD2}) for the end state (${md_folder_endstate}) than required (ce_first_restart_ID=${ce_first_restart_ID}). Skipping this thermodynamic window."
        continue
    fi

    # Preparing the restart files
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/ | grep restart_ | grep -v restart_0) ; do
        cp ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/$file ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/ipi.out.all_runs.restart_${counter} || true
        counter=$((counter + 1))
    done
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/ | grep restart_ | grep -v restart_0) ; do
        cp ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/$file ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/ipi.out.all_runs.restart_${counter} || true
        counter=$((counter + 1))
    done

    # Uniting all the ipi property files (previous all_runs files have already been cleaned)
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/*properties)"
    cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/ipi.out.all_runs.properties
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/*properties)"
    cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/ipi.out.all_runs.properties

    # Uniting all the ipi cell files (previous all_runs files have already been cleaned)
    cell_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/*cell)"
    for cell_file in ${cell_files}; do
        tail -n +3 ${cell_file} >> ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/ipi.out.all_runs.cell
    done
    cell_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/*cell)"
    for cell_file in ${cell_files}; do
        tail -n +3 ${cell_file} >> ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/ipi.out.all_runs.cell
    done

    # Loop for preparing the restart files in md_folder 1 (forward evaluation)
    echo -e "\n * Preparing the snapshots for the fortward cross-evaluation."
    for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD1}); do

        # Applying the crosseval trajectory stride
        mod=$(( (restartID-ce_first_restart_ID) % ce_stride ))
        if [ "${mod}" -eq "0" ]; then

            # Checking if this snapshot has already been prepared and should be skipped
            if [ "${ce_continue^^}" == "TRUE" ]; then
                if [[ -f ${crosseval_folder_fw}/snapshot-${restartID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_fw}/snapshot-${restartID}/ipi/ipi.in.restart ]]; then
                    echo " * Snapshot ${restartID} has already been prepared and ce_continue=true, skipping this snapshot..."
                    continue
                fi
            fi

            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_fw}/snapshot-${restartID}/ ]; then
                rm -r ${crosseval_folder_fw}/snapshot-${restartID}/
            fi

            # Preparing the snapshot folder
            restartFile=ipi.out.all_runs.restart_${restartID}
            prepare_restart ${md_folder_initialstate} ${md_folder_endstate} ${restartFile} ${crosseval_folder_fw} ${restartID} "endstate"

        else
            echo " * Snapshot ${restartID} will be skipped due to the crosseval trajectory stride..."
            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_fw}/snapshot-${restartID}/ ]; then
                rm -r ${crosseval_folder_fw}/snapshot-${restartID}/
                echo " * Deleting the previously prepared crosseval folder of snapshot ${restartID} due to the crosseval trajectory stride."
            fi
        fi
    done

    # Loop for preparing the restart files in md_folder_endstate (backward evaluation)
    echo -e "\n * Preparing the snapshots for the backward cross-evaluation."
    for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD2}); do

        # Applying the crosseval trajectory stride
        mod=$(( (restartID-ce_first_restart_ID) % ce_stride ))
        if [ "${mod}" -eq "0" ]; then

            # Checking if this snapshot has already been prepared and should be skipped
            if [ "${ce_continue^^}" == "TRUE" ]; then
                if [[ -f ${crosseval_folder_bw}/snapshot-${restartID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_bw}/snapshot-${restartID}/ipi/ipi.in.restart ]]; then
                    echo " * Snapshot ${restartID} has already been prepared and ce_continue=true, skipping this snapshot..."
                    continue
                fi
            fi

            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_bw}/snapshot-${restartID}/ ]; then
                rm -r ${crosseval_folder_bw}/snapshot-${restartID}/
            fi

            # Preparing the snapshot folder
            restartFile=ipi.out.all_runs.restart_${restartID}
            prepare_restart ${md_folder_endstate} ${md_folder_initialstate} ${restartFile} ${crosseval_folder_bw} ${restartID} "initialstate"

        else
            echo " * Snapshot ${restartID} will be skipped due to the crosseval trajectory stride..."
            # Removing the snapshot folder if it exists already
            if [ -d ${crosseval_folder_bw}/snapshot-${restartID}/ ]; then
                rm -r ${crosseval_folder_bw}/snapshot-${restartID}/
                echo " * Deleting the previously prepared crosseval folder of snapshot ${restartID} due to the crosseval trajectory stride."
            fi
        fi
    done

    if [ "${umbrella_sampling}" == "true" ]; then
        # Variables
        crosseval_folder_sn1="${md_folder_initialstate}-${md_folder_initialstate}"    # Stationary
        crosseval_folder_sn2="${md_folder_endstate}-${md_folder_endstate}"

        # Only if first TD window
        if [[ "${window_no}" == "1" ]]; then

            # Loop for preparing the restart files in md_folder_initialstate
            echo -e "\n * Preparing the snapshots for the re-evaluation of the initial state (${md_folder_initialstate})."
            for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD1}); do

                # Applying the crosseval trajectory stride
                mod=$(( (restartID-ce_first_restart_ID) % ce_stride ))
                if [ "${mod}" -eq "0" ]; then

                    # Checking if this snapshot has already been prepared and should be skipped
                    if [ "${ce_continue^^}" == "TRUE" ]; then
                        if [[ -f ${crosseval_folder_sn1}/snapshot-${restartID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_sn1}/snapshot-${restartID}/ipi/ipi.in.restart ]]; then
                            echo " * Snapshot ${restartID} has already been prepared and ce_continue=true, skipping this snapshot..."
                            continue
                        fi
                    fi

                    # Removing the snapshot folder if it exists already
                    if [ -d ${crosseval_folder_sn1}/snapshot-${restartID}/ ]; then
                        rm -r ${crosseval_folder_sn1}/snapshot-${restartID}/
                    fi

                    # Preparing the snapshot folder
                    restartFile=ipi.out.all_runs.restart_${restartID}
                    prepare_restart ${md_folder_initialstate} ${md_folder_initialstate} ${restartFile} ${crosseval_folder_sn1} ${restartID} "initialstate"

                else
                    echo " * Snapshot ${restartID} will be skipped due to the crosseval trajectory stride..."
                    # Removing the snapshot folder if it exists already
                    if [ -d ${crosseval_folder_sn1}/snapshot-${restartID}/ ]; then
                        rm -r ${crosseval_folder_sn1}/snapshot-${restartID}/
                        echo " * Deleting the previously prepared crosseval folder of snapshot ${restartID} due to the crosseval trajectory stride."
                    fi
                fi
            done
        fi
        
        # Loop for preparing the restart files in md_folder_endstate
        echo -e "\n * Preparing the snapshots for the re-evaluation of the the end state (${md_folder_endstate})."
        for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD2}); do

            # Applying the crosseval trajectory stride
            mod=$(( (restartID-ce_first_restart_ID) % ce_stride ))
            if [ "${mod}" -eq "0" ]; then

                # Checking if this snapshot has already been prepared and should be skipped
                if [ "${ce_continue^^}" == "TRUE" ]; then
                    if [[ -f ${crosseval_folder_sn2}/snapshot-${restartID}/ipi/ipi.in.main.xml ]] && [[ -f ${crosseval_folder_sn2}/snapshot-${restartID}/ipi/ipi.in.restart ]]; then
                        echo " * Snapshot ${restartID} has already been prepared and ce_continue=true, skipping this snapshot..."
                        continue
                    fi
                fi

                # Removing the snapshot folder if it exists already
                if [ -d ${crosseval_folder_sn2}/snapshot-${restartID}/ ]; then
                    rm -r ${crosseval_folder_sn2}/snapshot-${restartID}/
                fi

                # Preparing the snapshot folder
                restartFile=ipi.out.all_runs.restart_${restartID}
                prepare_restart ${md_folder_endstate} ${md_folder_endstate} ${restartFile} ${crosseval_folder_sn2} ${restartID} "endstate"

            else
                echo " * Snapshot ${restartID} will be skipped due to the crosseval trajectory stride..."
                # Removing the snapshot folder if it exists already
                if [ -d ${crosseval_folder_sn2}/snapshot-${restartID}/ ]; then
                    rm -r ${crosseval_folder_sn2}/snapshot-${restartID}/
                    echo " * Deleting the previously prepared crosseval folder of snapshot ${restartID} due to the crosseval trajectory stride."
                fi
            fi
        done
    fi
done

cd ../../../