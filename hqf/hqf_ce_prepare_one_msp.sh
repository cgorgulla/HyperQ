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
    echo "The error occured on lin $1" 1>&2
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

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

prepare_restart() {
    
    trap 'error_response_std $LINENO' ERR
    
    # Variables
    md_folder_coordinate_source=${1}
    md_folder_potential_source=${2}
    restartFile=${3}
    crosseval_folder=${4}
    restartID=${5}
    inputfile_ipi_ce=$(grep -m 1 "^inputfile_ipi_ce_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')

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

    # Preparing the CP2K files
    for bead in $(eval echo "{1..${nbeads}}"); do
        mkdir ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/
        cp ../../../md/${msp_name}/${subsystem}/${md_folder_potential_source}/cp2k/bead-${bead}/cp2k.in.md ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/
        sed -i "s|../../|../../../|" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
        sed -i "s|HOST.*cp2k.*|HOST ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.cp2k.${crosseval_folder}.restart-${restartID}|g" ${crosseval_folder}/snapshot-${restartID}/cp2k/bead-${bead}/cp2k.in.*
    done

    # Preparing the iqi files if required
    ce_type="$(grep -m 1 "^md_type_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
    if [ "${ce_type^^}" == "QMMM" ]; then 
        mkdir ${crosseval_folder}/snapshot-${restartID}/iqi
        sed -i "s|<address>.*iqi.*|<address>ipi.ce.${msp_name}.iqi.${crosseval_folder}.restart-${restartID}</address>|g" ${crosseval_folder}/snapshot-${restartID}/ipi/ipi.in.ce.xml
        cp ../../../md/${msp_name}/${subsystem}/${md_folder_potential_source}/iqi/iqi.in.* ${crosseval_folder}/snapshot-${restartID}/iqi
        sed -i "s|>.*\.\.\/\.\./|>\.\./\.\./\.\./|" ${crosseval_folder}/snapshot-${restartID}/iqi/iqi* ${crosseval_folder}/snapshot-${restartID}/iqi/iqi.in.xml
        sed -i "s|<address>.*iqi.*|<address>ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.iqi.${crosseval_folder}.restart-${restartID}</address>|g" ${crosseval_folder}/snapshot-${restartID}/iqi/iqi.in.*
    fi
}

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
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"
ce_first_restart_ID="$(grep -m 1 "^ce_first_restart_ID=" input-files/config.txt | awk -F '=' '{print $2}')"


# Printing some information
echo -e  "\n *** Preparing the crossevalutaions of the FES ${msp_name} (hqf_ce_prepare_one_msp.sh) ***"

# Checking in the input values
if [ ! "$crosseval_trajectory_stride" -eq "$crosseval_trajectory_stride" ] 2>/dev/null; then
    echo "Error regarding the variable crosseval_trajectory_stride in the configuration file. Exiting."
    exit 1
fi

# Checking if the md_folder exists
if [ ! -d "md/${msp_name}/${subsystem}" ]; then
    echo -e "\nError: The folder md/${msp_name}/${subsystem} does not exist. Exiting\n\n" 1>&2
    exit 1
fi

# Preparing the folders
echo -e " * Preparing the main folder"
if [ -d "ce/${msp_name}/${subsystem}" ]; then
    rm -r ce/${msp_name}/${subsystem}
fi
mkdir -p ce/${msp_name}/${subsystem}
cd ce/${msp_name}/${subsystem}

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

elif [ "${TD_cycle_type}" = "lambda" ]; then

    # Lambda step size
    lambda_stepsize=$(echo "print(1/${ntdsteps})" | python3)
    lambda_current=0.000
fi

# Loop for each TD window/step
for i in $(seq 1 $((nsim-1)) ); do

    if [ "${TD_cycle_type}" = "hq" ]; then
        
        # Setting the variables
        bead_count1="$((nbeads-(i-1)*beadStepSize))"
        bead_count1_next="$((nbeads-i*beadStepSize))"
        bead_count2="$(( (i-1) * beadStepSize ))"
        bead_count2_next="$((i*beadStepSize))"
        md_folder_1="md.k_${bead_count1}_${bead_count2}"
        md_folder_2="md.k_${bead_count1_next}_${bead_count2_next}"

    elif [ "${TD_cycle_type}" = "lambda" ]; then

        # Adjusting lambda_current and lambda_next
        lambda_current=$(echo "$((i-1))*${lambda_stepsize}" | bc -l)
        lambda_current="$(LC_ALL=C /usr/bin/printf "%.*f\n" 3 ${lambda_current})"
        lambda_next="$(echo "print(${lambda_current}+${lambda_stepsize})" | python3)"
        lambda_next="$(LC_ALL=C /usr/bin/printf "%.*f\n" 3 ${lambda_next})"

        # Setting the variables
        md_folder_1="md.lambda_${lambda_current}"
        md_folder_2="md.lambda_${lambda_next}"

    fi

    # Variables
    crosseval_folder_fw="${md_folder_1}-${md_folder_2}"     # md folder1 (positions, sampling) is evaluated at mdfolder2's potential: samplingfolder-potentialfolder
    crosseval_folder_bw="${md_folder_2}-${md_folder_1}"     # Opposite of fw
    
    echo "${md_folder_1} ${md_folder_2}" >> TD_windows.list
    
    # Printing some information
    echo -e " * Preparing TD window ${i}"
    
    # Creating required folders
    if [ -d "${crosseval_folder_fw}" ]; then         
        rm -r ${crosseval_folder_fw}
    fi
    mkdir ${crosseval_folder_fw}
    if [ -d "${crosseval_folder_bw}" ]; then         
        rm -r ${crosseval_folder_bw}
    fi
    mkdir ${crosseval_folder_bw}

    # Determining the number of restart files of the two md simulations
    restartFileCountMD1=$(ls ../../../md/${msp_name}/${subsystem}/${md_folder_1}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)
    restartFileCountMD2=$(ls ../../../md/${msp_name}/${subsystem}/${md_folder_2}/ipi/ | grep "restart" | grep -v restart_0 | wc -l)

    # Preparing the restart files
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_1}/ipi/*restart_0* || true
    rm ../../../md/${msp_name}/${subsystem}/${md_folder_2}/ipi/*restart_0* || true
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_1}/ipi/ | grep restart_ | grep -v restart_0) ; do
        mv ../../../md/${msp_name}/${subsystem}/${md_folder_1}/ipi/$file ../../../md/${msp_name}/${subsystem}/${md_folder_1}/ipi/ipi.out.all_runs.restart_${counter} || true
        counter=$((counter + 1))
    done
    counter=1
    for file in $(ls -1v ../../../md/${msp_name}/${subsystem}/${md_folder_2}/ipi/ | grep restart_ | grep -v restart_0) ; do
        mv ../../../md/${msp_name}/${subsystem}/${md_folder_2}/ipi/$file ../../../md/${msp_name}/${subsystem}/${md_folder_2}/ipi/ipi.out.all_runs.restart_${counter} || true
        counter=$((counter + 1))
    done
    #if [[ "${restartFileCountMD1}" -ge "${restartFileCountMD2}" ]]; then
    #    restartFileCountCommon="${restartFileCountMD2}"
    #elif [[ "${restartFileCountMD2}" -ge "${restartFileCountMD1}" ]]; then
    #    restartFileCountCommon="${restartFileCountMD1}"
    #else
    #    echo -e "\n * ERROR: Something went wrong when determining the maximum common restart-file number."
    #    echo -e " * restartFileCountMD1=${restartFileCountMD1}"
    #    echo -e " * restartFileCountMD2=${restartFileCountMD1}"
    #    echo -e " * Exiting... \n\n"
    #    exit 1
    #fi

    # Loop for preparing the restart files in md_folder 1 (forward evaluation)
    for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD1}); do
        #restartID=$((i-1))
        restartFile=ipi.out.all_runs.restart_${restartID}
        # Applying the crosseval_trajectory_stride
        mod=$(((restartID-ce_first_restart_ID)%crosseval_trajectory_stride))
        if [ "${mod}" -eq "0" ]; then
            restartID=${restartFile/*_}
            prepare_restart ${md_folder_1} ${md_folder_2} ${restartFile} ${crosseval_folder_fw} ${restartID}
        fi
    done

    # Loop for preparing the restart files in md_folder_2 (backward evaluation)
    for restartID in $(seq ${ce_first_restart_ID} ${restartFileCountMD2}); do
        #restartID=$((i-1))
        restartFile=ipi.out.all_runs.restart_${restartID}

        # Applying the crosseval_trajectory_stride
        mod=$(((restartID-ce_first_restart_ID)%crosseval_trajectory_stride))
        if [ "${mod}" -eq "0" ]; then
            restartID=${restartFile/*_}
            prepare_restart ${md_folder_2} ${md_folder_1} ${restartFile} ${crosseval_folder_bw} ${restartID}
        fi
    done

done

# Preparing the shared input files
cp ../../../md/${msp_name}/${subsystem}/system* ./
cp ../../../md/${msp_name}/${subsystem}/cp2k* ./

cd ../../../