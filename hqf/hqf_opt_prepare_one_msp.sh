#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_opt_prepare_one_msp.py <system 1 basename> <system 2 basename> <subsystem>

Has to be run in the root folder.

Possible subsystems are: L, LS, RLS."

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
system_1_basename="${1}"
system_2_basename="${2}"
subsystem=${3}
msp_name=${system_1_basename}_${system_2_basename}
inputfolder_cp2k_opt_general="$(grep -m 1 "^inputfolder_cp2k_opt_general_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfolder_cp2k_opt_specific="$(grep -m 1 "^inputfolder_cp2k_opt_specific_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" input-files/config.txt | awk -F '=' '{print $2}')"
ntdsteps="$(grep -m 1 "^ntdsteps=" input-files/config.txt | awk -F '=' '{print $2}')"
nsim="$((ntdsteps + 1))"

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
        exit 1
    fi
    echo " OK"
fi

# Checking if the system names are proper by checking if the mapping file exists
echo -e -n " * Checking if the mapping file exists... "
if [ -f input-files/mappings/${system_1_basename}_${system_2_basename} ]; then
    echo " OK"
else
    echo "Check failed. The mapping file ${system_1_basename}_${system_2_basename} was not found in the input-files/mappings folder."
    exit 1
fi

# Checking if the CP2K opt input file contains a lambda variable
echo -n " * Checking if the lambda_value variable is present in the CP2K input file... "
if [ -f input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda ]; then
    lambdavalue_count="$(grep -c lambda_value input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda)"
elif [ -f input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda ]; then
    lambdavalue_count="$(grep -c lambda_value input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda)"
else
    echo "Error: The input file main.opt.lambda could not be found in neither of the two CP2K input folders. Exiting..."
    exit 1
fi
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
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${systemID}.vmd.psf
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

            # Preparing the simulation folders
            mkdir -p opt.${bead_configuration}/cp2k

            # Copying the CP2K input files
            if [ "${lambda_current}" == "0.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_0 opt.${bead_configuration}/cp2k/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_0 opt.${bead_configuration}/cp2k/cp2k.in.main
                else
                    echo "Error: The input file main.opt.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            elif [ "${lambda_current}" == "1.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_1 opt.${bead_configuration}/cp2k/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_1 opt.${bead_configuration}/cp2k/cp2k.in.main
                else
                    echo "Error: The input file main.opt.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda opt.${bead_configuration}/cp2k/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda opt.${bead_configuration}/cp2k/cp2k.in.main
                else
                    echo "Error: The input file main.opt.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/ -type f -name "sub*"); do
                cp $file opt.${bead_configuration}/cp2k/cp2k.in.${file/*\/}
            done
            # The specific subfiles at the end so that they can overrride the general subfiles
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/ -type f -name "sub*"); do
                cp $file opt.${bead_configuration}/cp2k/cp2k.in.${file/*\/}
            done

            # Adjust the CP2K input files
            sed -i "s/lambda_value/${lambda_current}/g" opt.${bead_configuration}/cp2k/cp2k.in.*
            sed -i "s/subconfiguration/${bead_configuration}/g" opt.${bead_configuration}/cp2k/cp2k.in.*
            sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" opt.${bead_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_full_rounded/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" opt.${bead_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_odd_rounded/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" opt.${bead_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_scaled_rounded/GMAX ${GMAX_A_scaled} ${GMAX_B_scaled} ${GMAX_C_scaled}/g" opt.${bead_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_scaled_odd_rounded/GMAX ${GMAX_A_scaled_odd} ${GMAX_B_scaled_odd} ${GMAX_C_scaled_odd}/g" opt.${bead_configuration}/cp2k/cp2k.in.*
            sed -i "s|subsystem_folder/|../../|" opt.${bead_configuration}/cp2k/cp2k.in.*
        fi
    done
elif [ "${TD_cycle_type}" == "lambda" ]; then

    # Loop for each intermediate state
    for i in $(eval echo "{1..${nsim}}"); do

        # Variables
        lambda_current=$(echo "$((i-1))/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        lambda_configuration=lambda_${lambda_current}

        echo -e " * Preparing the files and directories for the optimization for lambda=${lambda_current}"

        # Preparation of the cp2k files
        if [[ "${opt_programs}" == *"cp2k"* ]]; then

            # Preparing the simulation folder
            mkdir -p opt.${lambda_configuration}/cp2k

            # Copying the CP2K input files
            # Copying the main files
            if [ "${lambda_current}" == "0.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_0 opt.${lambda_configuration}/cp2k/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_0 opt.${lambda_configuration}/cp2k/cp2k.in.main
                else
                    echo "Error: The input file main.opt.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            elif [ "${lambda_current}" == "1.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.k_1 opt.${lambda_configuration}/cp2k/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.k_1 opt.${lambda_configuration}/cp2k/cp2k.in.main
                else
                    echo "Error: The input file main.opt.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/main.opt.lambda opt.${lambda_configuration}/cp2k/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/main.opt.lambda opt.${lambda_configuration}/cp2k/cp2k.in.main
                else
                    echo "Error: The input file main.opt.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi
            # Copying the sub files
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_opt_general}/ -type f -name "sub*"); do
                cp $file opt.${lambda_configuration}/cp2k/cp2k.in.${file/*\/}
            done
            # The sub files in the specific folder at the end so that they can overrride the ones of the general CP2K input folder
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_opt_specific}/ -type f -name "sub*"); do
                cp $file opt.${lambda_configuration}/cp2k/cp2k.in.${file/*\/}
            done

            # Adjust the CP2K input files
            sed -i "s/lambda_value/${lambda_current}/g" opt.${lambda_configuration}/cp2k/cp2k.in.*
            sed -i "s/subconfiguration/${lambda_configuration}/g" opt.${lambda_configuration}/cp2k/cp2k.in.*
            sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" opt.${lambda_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_full_rounded/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" opt.${lambda_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_odd_rounded/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" opt.${lambda_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_scaled_rounded/GMAX ${GMAX_A_scaled} ${GMAX_B_scaled} ${GMAX_C_scaled}/g" opt.${lambda_configuration}/cp2k/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_scaled_odd_rounded/GMAX ${GMAX_A_scaled_odd} ${GMAX_B_scaled_odd} ${GMAX_C_scaled_odd}/g" opt.${lambda_configuration}/cp2k/cp2k.in.*
            sed -i "s|subsystem_folder/|../../|" opt.${lambda_configuration}/cp2k/cp2k.in.*
        fi
    done
fi

# Preparing the shared input files
hqh_fes_prepare_one_fes_common.sh ${nbeads} ${ntdsteps} ${system_1_basename} ${system_2_basename} ${subsystem} ${opt_type} ${opt_programs}

cd ../../../
