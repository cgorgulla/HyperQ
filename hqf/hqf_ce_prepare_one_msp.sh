#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_ce_prepare_one_msp.sh <system 1 basename> <system 2 basename> <subsystem> <nbeads> <ntdsteps> <crosseval_trajectory_stride>

Has to be run in the simulation folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "6" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 6"
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
            bead_configuration_local="${bead_configuration_endstate}"
            bead_count1_local=${bead_count1_endstate}
            bead_count2_local=${bead_count2_endstate}
        elif [[ "${evalstate}" == "initialstate" ]]; then
            bead_configuration_local="${bead_configuration_initialstate}"
            bead_count1_local=${bead_count1_initialstate}
            bead_count2_local=${bead_count2_initialstate}
        else
            echo "Error: The variable evalstate has an unsupported value. Exiting..."
            false
        fi

    elif [ "${TD_cycle_type}" == "lambda" ]; then
        if [ "${evalstate}" == "endstate" ]; then
            lambda_configuration_local="${lambda_configuration_endstate}"
            lambda_current_local="${lambda_endstate}"
        elif [[ "${evalstate}" == "initialstate" ]]; then
            lambda_configuration_local="${lambda_configuration_initialstate}"
            lambda_current_local="${lambda_initialstate}"
        fi
    fi

    # Creating up the folders
    mkdir -p ${crosseval_folder}/snapshot-${restartID}
    mkdir ${crosseval_folder}/snapshot-${restartID}/ipi
    mkdir ${crosseval_folder}/snapshot-${restartID}/cp2k

    # Preparing the ipi files
    cp ../../../md/${msp_name}/${subsystem}/${md_folder_coordinate_source}/ipi/${restartFile} ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.restart
    sed -i "/<step>/d" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.restart
    cp ../../../input-files/ipi/${inputfile_ipi_ce} ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.ce.xml
    sed -i "s|<address>.*cp2k.*|<address>ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.cp2k.${crosseval_folder}.restart-${restartID}</address>|g" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.ce.xml
    sed -i "s|<address>.*iqi.*|<address>ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.iqi.${crosseval_folder}.restart-${restartID}</address>|g" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.ce.xml
    sed -i "s|nbeads=.*>|nbeads='${nbeads}'>|g" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.ce.xml

    # Preparing the CP2K files
    for bead in $(eval echo "{1..${nbeads}}"); do
        mkdir ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/
        if [ "${TD_cycle_type}" == "lambda" ]; then
            cp ../../../input-files/cp2k/${inputfile_cp2k_ce_lambda} ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
            sed -i "s/subconfiguration/${lambda_configuration_local}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
            sed -i "s/lambda_value/${lambda_current_local}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        elif [ "${TD_cycle_type}" ==  "hq" ]; then
            # Bead type 1
            if [ ${bead} -le "${bead_count1_local}" ]; then
                cp ../../../input-files/cp2k/${inputfile_cp2k_ce_k_0} ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
            else
                cp ../../../input-files/cp2k/${inputfile_cp2k_ce_k_1} ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
            fi
            sed -i "s/subconfiguration/${bead_configuration_local}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        fi
        sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        sed -i "s/runtimeletter/${runtimeletter}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        sed -i "s/GMAX *value/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        sed -i "s/GMAX *half_value/GMAX ${GMAX_A_half} ${GMAX_B_half} ${GMAX_C_half}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        sed -i "s/GMAX *odd_value/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.ce
        sed -i "s|subsystem_folder/|../../../../|" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|HOST.*|HOST ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.cp2k.${crosseval_folder}.restart-${restartID}|g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
    done

    # Preparing the iqi files if required
    if [[ "${md_programs}" == *"iqi"* ]]; then
        mkdir ${crosseval_folder}/snapshot-${restartID}/iqi
        cp ../../../md/${msp_name}/${subsystem}/${md_folder_potential_source}/iqi/iqi.in.* ${crosseval_folder}/snapshot-${restartID}/iqi
        sed -i "s|>.*\.\.\/\.\./|>\.\./\.\./\.\./|" ${crosseval_folder}/snapshot-${restartID}/iqi/iqi* ${crosseval_folder}/snapshot-${restartID}/iqi/iqi.in.xml
        sed -i "s|<address>.*iqi.*|<address>ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.iqi.${crosseval_folder}.restart-${restartID}</address>|g" ${crosseval_folder}/snapshot-${restartID}/iqi/iqi.in.*
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
nbeads="${4}"
ntdsteps="${5}"
nsim="$((ntdsteps + 1))"
msp_name=${system1_basename}_${system2_basename}
#msp_name=$(pwd | awk -F '/' '{print $(NF-1)}')
crosseval_trajectory_stride=${6}
# "$(grep crosseval_trajectory_stride ${config_folder}/config.txt | awk -F '=' '{print $2}')"
inputfile_ipi_ce="$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"
ce_first_restart_ID="$(grep -m 1 "^ce_first_restart_ID=" input-files/config.txt | awk -F '=' '{print $2}')"
umbrella_sampling="$(grep -m 1 "^umbrella_sampling=" input-files/config.txt | awk -F '=' '{print $2}')"
ce_type="$(grep -m 1 "^ce_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"

# Printing some information
echo -e  "\n *** Preparing the crossevalutaions of the FES ${msp_name} (hqf_ce_prepare_one_msp.sh) ***"

# Checking in the input values
if [ ! "$crosseval_trajectory_stride" -eq "$crosseval_trajectory_stride" ] 2>/dev/null; then
    echo -e "\nError: The parameter crosseval_trajectory_stride in the configuration file has an unsupported value.\n"
    false
fi

# Checking if the md_folder exists
if [ ! -d "md/${msp_name}/${subsystem}" ]; then
    echo -e "\nError: The folder md/${msp_name}/${subsystem} does not exist. Exiting\n\n" 1>&2
    false
fi

# Preparing the folders
echo -e " * Preparing the main folder"
if [ -d "ce/${msp_name}/${subsystem}" ]; then
    rm -r ce/${msp_name}/${subsystem}
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


# Preparing the shared CP2K input files
hqh_fes_prepare_one_fes_common.sh ${nbeads} ${ntdsteps} ${system1_basename} ${system2_basename} ${subsystem} ${ce_type} ${md_programs}

# Copying the geo-opt coordinate files (not really needed, just for CP2K as some initial coordinate files which are not really used)
cp ../../../md/${msp_name}/${subsystem}/system.*.opt.pdb ./

# Creating the list of intermediate states
#echo md/methanol_ethane/L/*/ | tr " " "\n" | awk -F '/' '{print $(NF-1)}' >  TD_windows.states


# Getting the cell size for the cp2k input files
line=$(grep CRYST1 system1.pdb)
IFS=' ' read -r -a lineArray <<< "$line"
A=${lineArray[1]}
B=${lineArray[2]}
C=${lineArray[3]}

# Computing the GMAX values for CP2K
GMAX_A=${A/.*}
GMAX_B=${B/.*}
GMAX_C=${C/.*}
GMAX_A_half=$((GMAX_A/2))
GMAX_B_half=$((GMAX_B/2))
GMAX_C_half=$((GMAX_C/2))
for value in GMAX_A GMAX_B GMAX_C GMAX_A_half GMAX_B_half GMAX_C_half; do
    mod=$((${value}%2))
    if [ "${mod}" == "0" ]; then
        eval ${value}_odd=$((${value}+1))
    fi
done

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

    # CP2K input files
    inputfile_cp2k_ce_k_0="$(grep -m 1 "^inputfile_cp2k_ce_k_0_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
    inputfile_cp2k_ce_k_1="$(grep -m 1 "^inputfile_cp2k_ce_k_1_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

elif [ "${TD_cycle_type}" == "lambda" ]; then

    # Lambda step size
    lambda_stepsize=$(echo "print(1/${ntdsteps})" | python3)
    lambda_initialstate=0.000

    # CP2K input file
    inputfile_cp2k_ce_lambda="$(grep -m 1 "^inputfile_cp2k_ce_lambda_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
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
        lambda_initialstate=$(echo "$((window_no-1))*${lambda_stepsize}" | bc -l)
        lambda_initialstate="$(LC_ALL=C /usr/bin/printf "%.*f\n" 3 ${lambda_initialstate})"
        lambda_endstate="$(echo "print(${lambda_initialstate}+${lambda_stepsize})" | python3)"
        lambda_endstate="$(LC_ALL=C /usr/bin/printf "%.*f\n" 3 ${lambda_endstate})"
        lambda_configuration_initialstate=lambda_${lambda_initialstate}
        lambda_configuration_endstate=lambda_${lambda_endstate}
        md_folder_initialstate="md.lambda_${lambda_initialstate}"
        md_folder_endstate="md.lambda_${lambda_endstate}"
    fi

    # Variables
    crosseval_folder_fw="${md_folder_initialstate}-${md_folder_endstate}"     # md folder1 (positions, sampling) is evaluated at mdfolder2's potential: samplingfolder-potentialfolder
    crosseval_folder_bw="${md_folder_endstate}-${md_folder_initialstate}"     # Opposite of fw

    echo "${md_folder_initialstate} ${md_folder_endstate}" >> TD_windows.list
    
    # Printing some information
    echo -e " * Preparing TD window ${window_no}"
    
    # Creating required folders
    if [ -d "${crosseval_folder_fw}" ]; then         
        rm -r ${crosseval_folder_fw}
    fi
    mkdir ${crosseval_folder_fw}
    if [ -d "${crosseval_folder_bw}" ]; then         
        rm -r ${crosseval_folder_bw}
    fi
    mkdir ${crosseval_folder_bw}

    # Removing old prepared restart files
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/*restart_0* || true
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/*restart_0* || true
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/*all_runs* || true
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/*all_runs* || true

    # Determining the number of restart files of the two md simulations
    restartFileCountMD1=$(ls ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)
    restartFileCountMD2=$(ls ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)

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

    # Uniting all the ipi property files
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/* | grep properties)"
    cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ../../../md/${msp_name}/${subsystem}/${md_folder_initialstate}/ipi/ipi.out.all_runs.properties
    property_files="$(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/* | grep properties)"
    cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ../../../md/${msp_name}/${subsystem}/${md_folder_endstate}/ipi/ipi.out.all_runs.properties

    # Loop for preparing the restart files in md_folder 1 (forward evaluation)
    for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD1}); do
        restartFile=ipi.out.all_runs.restart_${restartID}
        # Applying the crosseval_trajectory_stride
        mod=$(( (restartID-ce_first_restart_ID) % crosseval_trajectory_stride ))
        if [ "${mod}" -eq "0" ]; then
            restartID=${restartFile/*_}
            prepare_restart ${md_folder_initialstate} ${md_folder_endstate} ${restartFile} ${crosseval_folder_fw} ${restartID} "endstate"
        fi
    done

    # Loop for preparing the restart files in md_folder_endstate (backward evaluation)
    for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD2}); do
        restartFile=ipi.out.all_runs.restart_${restartID}

        # Applying the crosseval_trajectory_stride
        mod=$(( (restartID-ce_first_restart_ID) % crosseval_trajectory_stride))
        if [ "${mod}" -eq "0" ]; then
            restartID=${restartFile/*_}
            prepare_restart ${md_folder_endstate} ${md_folder_initialstate} ${restartFile} ${crosseval_folder_bw} ${restartID} "initialstate"
        fi
    done

    if [ "${umbrella_sampling}" == "true" ]; then

        # Variables
        crosseval_folder_sn1="${md_folder_initialstate}-${md_folder_initialstate}"    # Stationary
        crosseval_folder_sn2="${md_folder_endstate}-${md_folder_endstate}"
        # Only if first TD window
        if [[ "${window_no}" == "1" ]]; then
            # Loop for preparing the restart files in md_folder 1
            for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD1}); do
                restartFile=ipi.out.all_runs.restart_${restartID}
                # Applying the crosseval_trajectory_stride
                mod=$(( (restartID-ce_first_restart_ID) % crosseval_trajectory_stride ))
                if [ "${mod}" -eq "0" ]; then
                    restartID=${restartFile/*_}
                    prepare_restart ${md_folder_initialstate} ${md_folder_initialstate} ${restartFile} ${crosseval_folder_sn1} ${restartID} "initialstate"
                fi
            done
        fi
        
        # Loop for preparing the restart files in md_folder 2
        for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD2}); do
            restartFile=ipi.out.all_runs.restart_${restartID}
            # Applying the crosseval_trajectory_stride
            mod=$(( (restartID-ce_first_restart_ID) % crosseval_trajectory_stride ))
            if [ "${mod}" -eq "0" ]; then
                restartID=${restartFile/*_}
                prepare_restart ${md_folder_endstate} ${md_folder_endstate} ${restartFile} ${crosseval_folder_sn2} ${restartID} "endstate"
            fi
        done
    fi
done

cd ../../../