#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_md_prepare_one_msp.py <system 1 basename> <system 2 basename> <subsystem type> <md_index_range>

<subsystem>: Possible values: L, LS, RLS

<md_index_range>: Possible values:
                      * all : Will cover all simulations of the MSP
                      * startindex:endindex : The index starts at 1 (w.r.t. the absolute simulation number)

Has to be run in the root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "4" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 4"
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

# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
system1_basename="${1}"
system2_basename="${2}"
subsystem=${3}
md_index_range=${4}
msp_name=${system1_basename}_${system2_basename}
inputfile_ipi_md="$(grep -m 1 "^inputfile_ipi_md_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfolder_cp2k_md_general="$(grep -m 1 "^inputfolder_cp2k_md_general_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfolder_cp2k_md_specific="$(grep -m 1 "^inputfolder_cp2k_md_specific_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
cell_dimensions_scaling_factor="$(grep -m 1 "^cell_dimensions_scaling_factor_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" input-files/config.txt | awk -F '=' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" input-files/config.txt | awk -F '=' '{print $2}')"
ntdsteps="$(grep -m 1 "^ntdsteps=" input-files/config.txt | awk -F '=' '{print $2}')"
nsim="$((ntdsteps + 1))"
stride_ipi_properties="$(grep "potential" input-files/ipi/${inputfile_ipi_md} | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')"
stride_ipi_trajectory="$(grep "<checkpoint" input-files/ipi/${inputfile_ipi_md} | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')"
ipi_set_randomseed="$(grep -m 1 "^ipi_set_randomseed=" input-files/config.txt | awk -F '=' '{print $2}')"

# Printing information
echo -e "\n *** Preparing the MD simulation ${msp_name} (hq_md_prepare_one_fes.sh) "

# Setting the range indices
if [ "${md_index_range}" == "all" ]; then
    md_index_first=1
    md_index_last=${nsim}
else
    md_index_first=${md_index_range/:*}
    md_index_last=${md_index_range/*:}
    if ! [ "${md_index_first}" -eq "${md_index_first}" ]; then
        echo " * Error: The input variable md_index_range was not specified correctly. Exiting..."
        exit 1
    fi
    if ! [ "${md_index_last}" -eq "${md_index_last}" ]; then
        echo " * Error: The input variable md_index_range was not specified correctly. Exiting..."
        exit 1
    fi
fi

# Checking if the checkpoint and potential in the ipi input file are equal
if [ "${stride_ipi_properties}" -ne "${stride_ipi_trajectory}" ]; then
    echo -n "Error: the checkpoint and potential need to have the same stride in the ipi input file\.n\n"
    exit 1
fi

# Preparing the main folder
echo -e " * Preparing the main folder"
if [[ "${md_continue^^}" == "FALSE" ]]; then

    # Creating required folders
    if [ -d "md/${msp_name}/${subsystem}" ]; then
        rm -r md/${msp_name}/${subsystem}
    fi
fi
mkdir -p md/${msp_name}/${subsystem}
cd md/${msp_name}/${subsystem}

# Copying the shared simulation files
echo -e " * Copying general simulation files"
systemID=1
for system_basename in ${system1_basename} ${system2_basename}; do
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${systemID}.vmd.psf
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${systemID}.pdb
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${systemID}.prm
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${systemID}.pdbx
    (( systemID += 1 ))
done
cp ../../../input-files/mappings/${system1_basename}_${system2_basename} ./system.mcs.mapping
cp ../../../eq/${msp_name}/${subsystem}/system.*.eq.pdb ./

# Preparing the shared CP2K input files
hqh_fes_prepare_one_fes_common.sh ${nbeads} ${ntdsteps} ${system1_basename} ${system2_basename} ${subsystem} ${md_type} ${md_programs}

# Preparing the individual MD folders for each thermodynamic state
if [ "${TD_cycle_type}" == "hq" ]; then

    # Bead step size
    beadStepSize=$(expr ${ntdsteps} / ${nbeads})

    # Loop for each TD window
    for i in $(seq ${md_index_first} ${md_index_last}); do
        bead_count1="$(( nbeads - (i-1)*beadStepSize))"
        bead_count2="$(( (i-1)*beadStepSize))"
        bead_configuration="k_${bead_count1}_${bead_count2}"
        md_folder="md.${bead_configuration}"
        k_stepsize=$(echo "1 / $ntdsteps" | bc -l)
        echo -e "\n * Preparing the files and directories for the fes with bead-configuration ${bead_configuration}"

        # Getting the cell size in the cp2k input files
        line=$(grep CRYST1 system.${bead_configuration}.eq.pdb)
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

        # Checking if the MD folder already exists
        if [[ "${md_continue^^}" == "TRUE" ]]; then
            if [ -d "${md_folder}" ]; then
                echo " * The folder ${md_folder} already exists. Checking its contents..."
                cd ${md_folder}
                restart_file_no=$(ls -1v ipi/ | { grep restart || true; } | wc -l)
                restart_file=$(ls -1v ipi/ | { grep restart || true; } | tail -n 1)
                if [[ -f ipi/ipi.in.main.xml ]] && [[ "${restart_file_no}" -ge "1" ]]; then

                    echo " * The folder ${md_folder} seems to contain files from a previous run. Preparing the folder for the next run..."

                    # Variables
                    restart_file=$(ls -1v ipi/ | { grep restart || true; } | tail -n 1)
                    run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.main.xml | grep -o "run.*" | grep -o "[0-9]*")
                    run_new=$((run_old + 1))

                    # Editing the ipi input file
                    sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.main.xml

                    # If the previous run was not started from a restart file, we need to replace the momenta and coordinate (file) tags
                    # We do not distinguish the cases with an if statement because this way is more robust
                    sed -i "/momenta/d" ipi/ipi.in.main.xml
                    sed -i "s|<file.*eq.pdb.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml
                    # If the previous run was started from a restart file, we only need to update the checkpoint tag
                    sed -i "s|<file.*chk.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml

                    cd ..
                    continue
                else
                    echo " * The folder ${md_folder} seems to not contain files from a previous run. Preparing it newly..."
                    cd ..
                    rm -r ${md_folder}
                fi
            fi
        fi

        # Creating directies
        mkdir ${md_folder}
        mkdir ${md_folder}/cp2k
        mkdir ${md_folder}/ipi
        for bead in $(eval echo "{1..$nbeads}"); do
            mkdir ${md_folder}/cp2k/bead-${bead}
        done

        # Preparing the input files of the packages
        # Preparing the input files of i-PI
        cp ../../../input-files/ipi/${inputfile_ipi_md} ${md_folder}/ipi/ipi.in.main.xml
        sed -i "s|nbeads=.*>|nbeads='${nbeads}'>|g" ${md_folder}/ipi/ipi.in.main.xml
        sed -i "s|subconfiguration|${bead_configuration}|g" ${md_folder}/ipi/ipi.in.main.xml
        sed -i "s|subsystem_folder|../..|g" ${md_folder}/ipi/ipi.in.main.xml
        if [ "${ipi_set_randomseed^^}" == "TRUE" ]; then
            sed -i "s|<seed>.*</seed>|<seed> $RANDOM </seed>|g" ${md_folder}/ipi/ipi.in.main.xml
        fi

        # Preparing the input files of CP2K
        # Preparing the bead folders for the beads with at lambda=0 (k=0)
        if [ "1" -le "${bead_count1}" ]; then
            for bead in $(eval echo "{1..${bead_count1}}"); do

                # Copying the CP2K input files
                # Copying the main files
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.eq.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
                # Copying the sub files
                for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/ -type f -name "sub*"); do
                    cp $file ${md_folder}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
                done
                # The sub files in the specific folder at the end so that they can overrride the ones of the general CP2K input folder
                for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/ -type f -name "sub*"); do
                    cp $file ${md_folder}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
                done

                # Adjusting the CP2K input files
                sed -i "s/subconfiguration/${bead_configuration}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_full_rounded/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_odd_rounded/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_scaled_rounded/GMAX ${GMAX_A_scaled} ${GMAX_B_scaled} ${GMAX_C_scaled}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_scaled_odd_rounded/GMAX ${GMAX_A_scaled_odd} ${GMAX_B_scaled_odd} ${GMAX_C_scaled_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s|subsystem_folder/|../../../|g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            done
        fi

        # Preparing the bead folders for the beads at lambda=1 (k=1)
        if [ "$((${bead_count1}+1))" -le "${nbeads}"  ]; then
            for bead in $(eval echo "{$((${bead_count1}+1))..${nbeads}}"); do

                # Copying the CP2K input files
                # Copying the main files
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
                # Copying the sub files
                for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/ -type f -name "sub*"); do
                    cp $file ${md_folder}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
                done
                # The sub files in the specific folder at the end so that they can overrride the ones of the general CP2K input folder
                for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/ -type f -name "sub*"); do
                    cp $file ${md_folder}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
                done

                # Adjusting the CP2K input files
                sed -i "s/subconfiguration/${bead_configuration}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_full_rounded/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_odd_rounded/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_scaled_rounded/GMAX ${GMAX_A_scaled} ${GMAX_B_scaled} ${GMAX_C_scaled}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s/GMAX *cell_dimensions_scaled_odd_rounded/GMAX ${GMAX_A_scaled_odd} ${GMAX_B_scaled_odd} ${GMAX_C_scaled_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
                sed -i "s|subsystem_folder/|../../../|g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            done
        fi

        # Preparing the input files of i-QI
        if [[ "${md_programs}" == *"iqi"* ]]; then

            # Variables
            inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
            inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

            # Preparing the files and folders
            mkdir ${md_folder}/iqi
            cp ../../../input-files/iqi/${inputfile_iqi_md} ${md_folder}/iqi/iqi.in.main.xml
            cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${md_folder}/iqi/
            sed -i "s|subsystem_folder|../..|g" ${md_folder}/iqi/iqi.in.main.xml
        fi

    done

elif [ "${TD_cycle_type}" == "lambda" ]; then

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
        echo "" > runtime/error
        exit 1
    fi
    echo "OK"

    # Lambda step size
    lambda_stepsize=$(echo "print(1/${ntdsteps})" | python3)

    # Loop for each TD window
    for i in $(seq ${md_index_first} ${md_index_last}); do

        lambda_current=$(echo "$((i-1))/${ntdsteps}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        lambda_configuration=lambda_${lambda_current}
        md_folder="md.lambda_${lambda_current}"

        echo -e "\n * Preparing the files and directories for the fes with lambda-configuration ${lambda_configuration}"

        # Getting the cell size in the cp2k input files
        line=$(grep CRYST1 system.${lambda_configuration}.eq.pdb)
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

        # Checking if the MD folder already exists
        if [[ "${md_continue^^}" == "TRUE" ]]; then
            if [ -d "${md_folder}" ]; then
                echo " * The folder ${md_folder} already exists. Checking its contents..."
                cd ${md_folder}
                restart_file_no=$(ls -1v ipi/ | { grep restart || true; } | wc -l)
                if [[ -f ipi/ipi.in.main.xml ]] && [[ "${restart_file_no}" -ge "1" ]]; then

                    echo " * The folder ${md_folder} seems to contain files from a previous run. Preparing the folder for the next run..."

                    # Variables
                    restart_file=$(ls -1v ipi/ | { grep restart || true; } | tail -n 1)
                    run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.main.xml | grep -o "run.*" | grep -o "[0-9]*")
                    run_new=$((run_old + 1))

                    # Editing the ipi input file
                    sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.main.xml

                    # If the previous run was not started from a restart file, we need to replace the momenta and coordinate (file) tags
                    # We do not distinguish the cases with an if statement because this way is more robust
                    sed -i "/momenta/d" ipi/ipi.in.main.xml
                    sed -i "s|<file.*eq.pdb.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml
                    # If the previous run was started from a restart file, we only need to update the checkpoint tag
                    sed -i "s|<file.*chk.*|<file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.main.xml

                    cd ..
                    continue
                else
                    echo " * The folder ${md_folder} seems to not contain files from a previous run. Preparing it newly..."
                    cd ..
                    rm -r ${md_folder}
                fi
            fi
        fi

        # Creating directies
        mkdir ${md_folder}
        mkdir ${md_folder}/cp2k
        mkdir ${md_folder}/ipi
        for bead in $(eval echo "{1..$nbeads}"); do
            mkdir ${md_folder}/cp2k/bead-${bead}
        done

        # Preparing the input files of the packages
        # Preparing the input files of i-PI
        cp ../../../input-files/ipi/${inputfile_ipi_md} ${md_folder}/ipi/ipi.in.main.xml
        sed -i "s|nbeads=.*>|nbeads='${nbeads}'>|g" ${md_folder}/ipi/ipi.in.main.xml
        sed -i "s|subconfiguration|${lambda_configuration}|g" ${md_folder}/ipi/ipi.in.main.xml
        sed -i "s|subsystem_folder|../..|g" ${md_folder}/ipi/ipi.in.main.xml
        if [ "${ipi_set_randomseed^^}" == "TRUE" ]; then
            sed -i "s|<seed>.*</seed>|<seed> $RANDOM </seed>|g" ${md_folder}/ipi/ipi.in.main.xml
        fi

        # Preparing the input files of CP2K
        for bead in $(eval echo "{1..${nbeads}}"); do

            # Copying the CP2K input files
            # Copying the main files
            if [ "${lambda_current}" == "0.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_0 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_0 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_0 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            elif [ "${lambda_current}" == "1.000" ]; then
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.k_1 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.k_1 ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.k_1 could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            else
                # Checking the specific folder at first to give it priority over the general folder
                if [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/main.ipi.lambda ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                elif [ -f ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda ]; then
                    cp ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/main.ipi.lambda ${md_folder}/cp2k/bead-${bead}/cp2k.in.main
                else
                    echo "Error: The input file main.ipi.lambda could not be found in neither of the two CP2K input folders. Exiting..."
                    exit 1
                fi
            fi
            # Copying the sub files
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_general}/ -type f -name "sub*"); do
                cp $file ${md_folder}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done
            # The sub files in the specific folder at the end so that they can overrride the ones of the general CP2K input folder
            for file in $(find ../../../input-files/cp2k/${inputfolder_cp2k_md_specific}/ -type f -name "sub*"); do
                cp $file ${md_folder}/cp2k/bead-${bead}/cp2k.in.${file/*\/}
            done

            # Adjusting the CP2K input files
            sed -i "s/subconfiguration/${lambda_configuration}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/lambda_value/${lambda_current}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/ABC *cell_dimensions_full_rounded/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_full_rounded/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_odd_rounded/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_scaled_rounded/GMAX ${GMAX_A_scaled} ${GMAX_B_scaled} ${GMAX_C_scaled}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s/GMAX *cell_dimensions_scaled_odd_rounded/GMAX ${GMAX_A_scaled_odd} ${GMAX_B_scaled_odd} ${GMAX_C_scaled_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
            sed -i "s|subsystem_folder/|../../../|g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.*
        done

        # Preparing the input files of i-QI
        if [[ "${md_programs}" == *"iqi"* ]]; then

            # Variables
            inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
            inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

            # Preparing the files and folders
            mkdir ${md_folder}/iqi
            cp ../../../input-files/iqi/${inputfile_iqi_md} ${md_folder}/iqi/iqi.in.main.xml
            cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${md_folder}/iqi/
            sed -i "s|subsystem_folder|../..|g" ${md_folder}/iqi/iqi.in.main.xml
        fi

    done
fi

cd ../../../