#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_opt_prepare_one_msp.py <nbeads> <ntdsteps> <system 1 basename> <system 2 basename> <subsystem type>

Has to be run in the root folder.

<ntdstepds> is the number of TD windows (minimal value is 1).

Possible subsystems are: L, LS, PLS."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "5" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 5"
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

# Bash options
set -o pipefail

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
nbeads="${1}"
ntdsteps="${2}"
nsim="$((ntdsteps + 1))"
system_1_basename="${3}"
system_2_basename="${4}"
subsystem=${5}
msp_name=${system_1_basename}_${system_2_basename}
inputfile_cp2k_opt="$(grep -m 1 "^inputfile_cp2k_opt_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"

# Printing information
echo -e "\n *** Preparing the optimization folder for fes ${msp_name} (hq_opt_prepare_one_fes) *** "

# Checking if nbeads and ntdsteps are compatible
if [ "${TD_cycle_type}" == "hq" ]; then
    echo -e -n " * Checking if the variables <nbeads> and <ntdsteps> are compatible... "
    trap '' ERR
    mod="$(expr ${nbeads} % ${ntdsteps})"
    trap 'error_response_std $LINENO' ERR
    if [ "${mod}" != "0" ]; then
        echo "Check failed"
        echo " * The variables <nbeads> and <ntdsteps> are not compatible. nbeads % ntdsteps should be zero"
        false
    fi
    echo " OK"
fi

# Checking if the system names are proper by checking if the mapping file exists
echo -e -n " * Checking if the mapping file exists... "
if [ -f input-files/mappings/${system_1_basename}_${system_2_basename} ]; then
    echo " OK"
else
    echo "Check failed. The mapping file ${system_1_basename}_${system_2_basename} was not found in the input-files/mappings folder "
    false
fi

# Checking if the CP2K input file contains a lambda variable
lambdavalue_count="$(grep -c lambda_value input-files/cp2k/${inputfile_cp2k_opt} )"
echo -n " * Checking if the lambda_value variable is present in the CP2K input file... "
if  [ ! "${lambdavalue_count}" -ge "1" ]; then
    echo "Check failed"
    echo -e "\n * Error: The CP2K optimization input file does not contain the lambda_value variable. Exiting...\n\n"
    echo "" > runtime/error
    exit 1
fi
echo "OK"

# Creating required folders
echo -e " * Preparing the main folder"
if [ -d "opt/${msp_name}/${subsystem}" ]; then
    rm -r opt/${msp_name}/${subsystem}
fi
mkdir -p opt/${msp_name}/${subsystem}
cd opt/${msp_name}/${subsystem}

# Copying the system files
echo -e " * Copying general simulation files"
systemID=1
for system_basename in ${system_1_basename} ${system_2_basename}; do 
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${systemID}.psf
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${systemID}.pdb
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${systemID}.prm
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${systemID}.pdbx
    (( systemID += 1 ))
done
cp ../../../input-files/mappings/${system_1_basename}_${system_2_basename} ./system.mcs.mapping

# Getting the cell size for the opt program input files
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
    else
        eval ${value}_odd=$((${value}))
    fi
done

if [ "${TD_cycle_type}" == "hq" ]; then

    # Loop for each intermediate state
    beadStepSize=$(expr $nbeads / $ntdsteps)
    for i in $(eval echo "{1..${nsim}}"); do

        # Variables
        bead_count1="$(( nbeads - (i-1)*beadStepSize))"
        bead_count2="$(( (i-1)*beadStepSize))"
        bead_configuration="k_${bead_count1}_${bead_count2}"
        lambda_current=$(echo "$((i-1))/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )

        echo -e " * Preparing the files and directories for the optimization with bead-configuration ${bead_configuration}"

        # Preparation of the cp2k files
        if [[ "${opt_programs}" == *"cp2k"* ]]; then
            mkdir -p opt.${bead_configuration}/cp2k
            cp ../../../input-files/cp2k/${inputfile_cp2k_opt} opt.${bead_configuration}/cp2k/cp2k.in.opt
            sed -i "s/lambda_value/${lambda_current}/g" opt.${bead_configuration}/cp2k/cp2k.in.opt
            sed -i "s/subconfiguration/${bead_configuration}/g" opt.${bead_configuration}/cp2k/cp2k.in.opt
            sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" opt.${bead_configuration}/cp2k/cp2k.in.opt
            sed -i "s/GMAX *value/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" opt.${bead_configuration}/cp2k/cp2k.in.opt
            sed -i "s/GMAX *half_value/GMAX ${GMAX_A_half} ${GMAX_B_half} ${GMAX_C_half}/g" opt.${bead_configuration}/cp2k/cp2k.in.opt
            sed -i "s/GMAX *odd_value/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" opt.${bead_configuration}/cp2k/cp2k.in.opt
            sed -i "s|subsystem_folder/|../../|" opt.${bead_configuration}/cp2k/cp2k.in.opt
        fi
    done
elif [ "${TD_cycle_type}" == "lambda" ]; then

    # Loop for each intermediate state
    for i in $(eval echo "{1..${nsim}}"); do

        # Variables
        lambda_current=$(echo "$((i-1))/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        lambda_configuration=lambda_${lambda_current}

        echo -e " * Preparing the files and directories for the optimization for lambda=${lambda_stepsize}"

        # Preparation of the cp2k files
        if [[ "${opt_programs}" == *"cp2k"* ]]; then
            mkdir -p opt.${lambda_configuration}/cp2k
            cp ../../../input-files/cp2k/${inputfile_cp2k_opt} opt.${lambda_configuration}/cp2k/cp2k.in.opt
            sed -i "s/lambda_value/${lambda_current}/g" opt.${lambda_configuration}/cp2k/cp2k.in.opt
            sed -i "s/subconfiguration/${lambda_configuration}/g" opt.${lambda_configuration}/cp2k/cp2k.in.opt
            sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" opt.${lambda_configuration}/cp2k/cp2k.in.opt
            sed -i "s/GMAX *value/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" opt.${lambda_configuration}/cp2k/cp2k.in.opt
            sed -i "s/GMAX *half_value/GMAX ${GMAX_A_half} ${GMAX_B_half} ${GMAX_C_half}/g" opt.${lambda_configuration}/cp2k/cp2k.in.opt
            sed -i "s/GMAX *odd_value/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" opt.${lambda_configuration}/cp2k/cp2k.in.opt
            sed -i "s|subsystem_folder/|../../|" opt.${lambda_configuration}/cp2k/cp2k.in.opt
        fi
    done
fi

# Preparing the shared input files
hqh_fes_prepare_one_fes_common.sh ${nbeads} ${ntdsteps} ${system_1_basename} ${system_2_basename} ${subsystem} ${opt_type} ${opt_programs}

cd ../../../
