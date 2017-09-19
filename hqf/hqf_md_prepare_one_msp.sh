#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_md_prepare_one_msp.py <system 1 basename> <system 2 basename> <subsystem type> <nbeads> <ntdsteps>

Has to be run in the root folder.

<ntdstepds>is the number TD windows (minimal value is 1).

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
nbeads="${4}"
ntdsteps="${5}"
nsim="$((ntdsteps + 1))"
system1_basename="${1}"
system2_basename="${2}"
subsystem=${3}
msp_name=${system1_basename}_${system2_basename}
inputfile_cp2k_opt="$(grep -m 1 "^inputfile_cp2k_opt_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfile_ipi_md="$(grep -m 1 "^inputfile_ipi_md_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" input-files/config.txt | awk -F '=' '{print $2}')"


# Printing information
echo -e "\n *** Preparing the md simulation ${msp_name} (hq_md_prepare_one_fes.sh) "

# Folder preparation
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
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${systemID}.psf
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${systemID}.pdb
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${systemID}.prm
    cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${systemID}.pdbx
    (( systemID += 1 ))
done
cp ../../../input-files/mappings/${system1_basename}_${system2_basename} ./system.mcs.mapping

# Preparing the shared CP2K input files
hqh_fes_prepare_one_fes_common.sh ${nbeads} ${ntdsteps} ${system1_basename} ${system2_basename} ${subsystem} ${md_type} ${md_programs}

# Getting the cell size in the cp2k input files
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

# Preparing the individual md folders for each thermodynamic state
if [ "${TD_cycle_type}" == "hq" ]; then

    # Bead step size
    beadStepSize=$(expr ${ntdsteps} / ${nbeads})
    inputfile_cp2k_md_k_0="$(grep -m 1 "^inputfile_cp2k_md_k_0_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
    inputfile_cp2k_md_k_1="$(grep -m 1 "^inputfile_cp2k_md_k_1_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

    # Loop for each TD window
    for i in $(eval echo "{1..${nsim}}"); do
        bead_count1="$(( nbeads - (i-1)*beadStepSize))"
        bead_count2="$(( (i-1)*beadStepSize))"
        bead_configuration="k_${bead_count1}_${bead_count2}"
        md_folder="md.${bead_configuration}"
        k_stepsize=$(echo "1 / $ntdsteps" | bc -l)
        echo -e "\n * Preparing the files and directories for the fes with bead-configuration ${bead_configuration}"

        # Checking if the MD folder already exists
        if [[ "${md_continue^^}" == "TRUE" ]]; then
            if [ -d "${md_folder}" ]; then
                echo " * The folder ${md_folder} already exists. Checking its contents..."
                cd ${md_folder}
                restart_file_no=$(ls -1v ipi/ | grep restart | wc -l)
                restart_file=$(ls -1v ipi/ | grep restart | tail -n 1)
                if [[ -f ipi/ipi.in.md.xml ]] && [[ "${restart_file_no}" -ge "1" ]]; then
                    echo " * The folder ${md_folder} seems to contain files from a previous run. Preparing the folder for the next run..."
                    run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.md.xml | grep -o "run." | grep -o "[0-9]*")
                    run_new=$((run_old + 1))
                    sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.md.xml
                    if [ "${run_old}" == "1" ]; then
                        sed -i "s|^.*opt.pdb.*|      <file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.md.xml
                        sed -i "/momenta/d" ipi/ipi.in.md.xml
                    else
                        sed -i "s|^.file.*chk.*|      <file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.md.xml
                    fi
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

        # Copying in the input files of the packages
        # ipi
        cp ../../../input-files/ipi/${inputfile_ipi_md} ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s|nbeads=.*>|nbeads='${nbeads}'>|g" ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s/subconfiguration/${bead_configuration}/g" ${md_folder}/ipi/ipi.in.md.xml

        # CP2K
        # Preparing the bead folders for the beads with at k=0.0
        if [ "1" -le "${bead_count1}" ]; then
            for bead in $(eval echo "{1..${bead_count1}}"); do
                cp ../../../input-files/cp2k/${inputfile_cp2k_md_k_0} ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/subconfiguration/${bead_configuration}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/GMAX *value/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/GMAX *half_value/GMAX ${GMAX_A_half} ${GMAX_B_half} ${GMAX_C_half}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s|subsystem_folder/|../../../|g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            done
        fi

        # Preparing the bead folders for the beads at k=1.0
        if [ "$((${bead_count1}+1))" -le "${nbeads}"  ]; then
            for bead in $(eval echo "{$((${bead_count1}+1))..${nbeads}}"); do
                cp ../../../input-files/cp2k/${inputfile_cp2k_md_k_1} ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/subconfiguration/${bead_configuration}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/GMAX *value/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/GMAX *half_value/GMAX ${GMAX_A_half} ${GMAX_B_half} ${GMAX_C_half}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/GMAX *odd_value/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s|subsystem_folder/|../../../|g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            done
        fi

        # QM/MM Case
        if [[ "${md_programs}" == *"iqi"* ]]; then

            # iqi
            inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
            inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
            mkdir ${md_folder}/iqi
            cp ../../../input-files/iqi/${inputfile_iqi_md} ${md_folder}/iqi/iqi.in.xml
            sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/iqi/iqi.in.xml
            sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/iqi/iqi.in.xml
            sed -i "s/subconfiguration/${bead_configuration}/g" ${md_folder}/iqi/iqi.in.xml
            cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${md_folder}/iqi/
        fi

        # Copying the geo-opt coordinate files
        cp ../../../opt/${msp_name}/${subsystem}/system.${bead_configuration}.opt.pdb ./

    done

elif [ "${TD_cycle_type}" == "lambda" ]; then

    # Variables
    inputfile_cp2k_md_lambda="$(grep -m 1 "^inputfile_cp2k_md_lambda_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

    # Checking if the CP2K input file contains a lambda variable
    lambdavalue_count="$(grep -c lambda_value ../../../input-files/cp2k/${inputfile_cp2k_md_lambda} )"
    echo -n " * Checking if the lambda_value variable is present in the CP2K input file... "
    if  [ ! "${lambdavalue_count}" -ge "1" ]; then
        echo "Check failed"
        echo -e "\n * Error: The CP2K MD input file does not contain the lambda_value variable. Exiting...\n\n"
        echo "" > runtime/error
        exit 1
    fi
    echo "OK"

    # Lambda step size
    lambda_stepsize=$(echo "print(1/${ntdsteps})" | python3)

    # Loop for each TD window
    lambda_current=0.000
    for i in $(eval echo "{1..${nsim}}"); do
        lambda_configuration=lambda_${lambda_current}
        md_folder="md.lambda_${lambda_current}"
        echo -e "\n * Preparing the files and directories for the fes with lambda-configuration ${lambda_configuration}"

        # Checking if the MD folder already exists
        if [[ "${md_continue^^}" == "TRUE" ]]; then
            if [ -d "${md_folder}" ]; then
                echo " * The folder ${md_folder} already exists. Checking its contents..."
                cd ${md_folder}
                restart_file_no=$(ls -1v ipi/ | grep restart | wc -l)
                restart_file=$(ls -1v ipi/ | grep restart | tail -n 1)
                if [[ -f ipi/ipi.in.md.xml ]] && [[ "${restart_file_no}" -ge "1" ]]; then
                    echo " * The folder ${md_folder} seems to contain files from a previous run. Preparing the folder for the next run..."
                    run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.md.xml | grep -o "run." | grep -o "[0-9]*")
                    run_new=$((run_old + 1))
                    sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.md.xml
                    if [ "${run_old}" == "1" ]; then
                        sed -i "s|^.*opt.pdb.*|      <file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.md.xml
                        sed -i "/momenta/d" ipi/ipi.in.md.xml
                    else
                        sed -i "s|^.file.*chk.*|      <file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.md.xml
                    fi

                    # Adjusting lambda_current
                    if [ "${i}" -lt $((nsim-1)) ]; then
                        lambda_current=$(echo "${lambda_current} + ${lambda_stepsize}" | bc -l)
                        lambda_current="$(LC_ALL=C /usr/bin/printf "%.*f\n" 3 ${lambda_current})"
                    else
                        lambda_current="1.000"
                    fi

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

        # Copying in the input files of the packages
        # ipi
        cp ../../../input-files/ipi/${inputfile_ipi_md} ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s|nbeads=.*>|nbeads='${nbeads}'>|g" ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/ipi/ipi.in.md.xml
        sed -i "s/subconfiguration/${lambda_configuration}/g" ${md_folder}/ipi/ipi.in.md.xml

        # CP2K
        for bead in $(eval echo "{1..${nbeads}}"); do
            cp ../../../input-files/cp2k/${inputfile_cp2k_md_lambda} ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/subconfiguration/${lambda_configuration}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/lambda_value/${lambda_current}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/GMAX *value/GMAX ${GMAX_A} ${GMAX_B} ${GMAX_C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/GMAX *half_value/GMAX ${GMAX_A_half} ${GMAX_B_half} ${GMAX_C_half}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s/GMAX *odd_value/GMAX ${GMAX_A_odd} ${GMAX_B_odd} ${GMAX_C_odd}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
            sed -i "s|subsystem_folder/|../../../|g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
        done

        # iqi
        if [[ "${md_programs}" == *"iqi"* ]]; then
            # Variables
            inputfile_iqi_md="$(grep -m 1 "^inputfile_iqi_md_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
            inputfile_iqi_constraints="$(grep -m 1 "^inputfile_iqi_constraints_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

            mkdir ${md_folder}/iqi
            cp ../../../input-files/iqi/${inputfile_iqi_md} ${md_folder}/iqi/iqi.in.xml
            sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/iqi/iqi.in.xml
            sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/iqi/iqi.in.xml
            sed -i "s/subconfiguration/${lambda_configuration}/g" ${md_folder}/iqi/iqi.in.xml
            cp ../../../input-files/iqi/${inputfile_iqi_constraints} ${md_folder}/iqi/
        fi

        # Copying the geo-opt coordinate files
        cp ../../../opt/${msp_name}/${subsystem}/system.${lambda_configuration}.opt.pdb ./

        # Adjusting lambda_current
        if [ "${i}" -lt $((nsim-1)) ]; then
            lambda_current=$(echo "${lambda_current} + ${lambda_stepsize}" | bc -l)
            lambda_current="$(LC_ALL=C /usr/bin/printf "%.*f\n" 3 ${lambda_current})"
        else
            lambda_current="1.000"
        fi
    done
fi

cd ../../../