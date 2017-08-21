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

# Variables
nbeads="${4}"
ntdsteps="${5}"
nsim="$((ntdsteps + 1))"
system_1_basename="${1}"
system_2_basename="${2}"
subsystem=${3}
msp_name=${system_1_basename}_${system_2_basename}
inputfile_cp2k_opt="$(grep -m 1 "^inputfile_cp2k_opt_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfile_cp2k_md_k_0="$(grep -m 1 "^inputfile_cp2k_md_k_0_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfile_cp2k_md_k_1="$(grep -m 1 "^inputfile_cp2k_md_k_1_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
inputfile_ipi_md="$(grep -m 1 "^inputfile_ipi_md_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_type="$(grep -m 1 "^md_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" input-files/config.txt | awk -F '=' '{print $2}')"
opt_type="$(grep -m 1 "^opt_type_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')"
TD_cycle_type="$(grep -m 1 "^TD_cycle_type=" input-files/config.txt | awk -F '=' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" input-files/config.txt | awk -F '=' '{print $2}')"


# Printing information
echo -e "\n *** Preparing the md simulation ${msp_name} (hq_md_prepare_one_fes.sh) "

# De novo preparation
if [[ "${md_continue^^}" == "FALSE" ]]; then

    # Creating required folders
    echo -e " * Preparing the main folder"
    if [ -d "md/${msp_name}/${subsystem}" ]; then
        rm -r md/${msp_name}/${subsystem}
    fi
    mkdir -p md/${msp_name}/${subsystem}
    cd md/${msp_name}/${subsystem}
    rm /tmp/ipi_ipi.${runtimeletter}.${msp_name}* 2>/dev/null || true

    # Copying the system files
    echo -e " * Copying general simulation files"
    systemID=1
    for system_basename in ${system_1_basename} ${system_2_basename}; do
        cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.psf ./system${systemID}.psf
        cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdb ./system${systemID}.pdb
        cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.prm ./system${systemID}.prm
        if [[ "${md_type}" == *"QMMM"* ]]; then
            cp ../../../input-files/systems/${system_basename}/${subsystem}/system_complete.reduced.pdbx ./system${systemID}.pdbx
        fi
        (( systemID += 1 ))
    done
    cp ../../../input-files/mappings/${system_1_basename}_${system_2_basename} ./system.mcs.mapping

    # Getting the cell size in the cp2k input files
    line=$(grep CRYST1 system1.pdb)
    IFS=' ' read -r -a lineArray <<< "$line"
    A=${lineArray[1]}
    B=${lineArray[2]}
    C=${lineArray[3]}

    if [ "${TD_cycle_type}" == "hq" ]; then

        # Bead step size
        beadStepSize=$(expr ${ntdsteps} / ${nbeads})

        # Loop for each TD window
        lambda_current=0.000
        for i in $(eval echo "{1..${nsim}}"); do
            bead_count1="$(( nbeads - (i-1)*beadStepSize))"
            bead_count2="$(( (i-1)*beadStepSize))"
            bead_configuration="k_${bead_count1}_${bead_count2}"
            md_folder="md.${bead_configuration}"
            k_stepsize=$(echo "1 / $ntdsteps" | bc -l)
            echo -e " * Preparing the files and directories for the fes with bead-configuration ${bead_configuration}"

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
                    if [ "${TD_cycle_type}" == "lambda" ]; then
                        sed -i "s/lambda/${lambda_current}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                    fi
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
                    if [ "${TD_cycle_type}" == "lambda" ]; then
                        sed -i "s/lambda/${lambda_current}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                    fi
                done
            fi

            # QM/MM Case
            if [ ${md_type^^} == "QMMM" ]; then

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

            # Adjusting lambda_current
            lambda_current=$(echo "${lambda_current} + ${k_stepsize}" | bc -l)
            lambda_current=${lambda_current:0:5}

        done

    elif [ "${TD_cycle_type}" == "lambda" ]; then

        # Checking if the CP2K input file contains a lambda variable
        lambda_count="$(grep -c lambda ../../../input-files/cp2k/${inputfile_cp2k_md_k_0} )"
        echo -n " * Checking if the lambda variable is present in the CP2K input file... "
        if  [ ! "${lambda_count}" -ge "1" ]; then
            echo "Check failed"
            echo -e "\n * Error: The CP2K input file does not contain the lambda variable. Exiting...\n\n"
            echo "" > runtime/error
            exit 1
        fi
        echo "OK"

        # Checking if the two CP2K input files are the same
        echo -n " * Checking if the two CP2K input files (k_0 und k_1) are the same, as required for in the TD_cycle_type=lambda)... "
        echo ${inputfile_cp2k_md_k_0}
        echo ${inputfile_cp2k_md_k_1}
        if  [ ! "${inputfile_cp2k_md_k_0}" = "${inputfile_cp2k_md_k_1}" ]; then
            echo "Check failed."
            echo -e "\n * Error: The two CP2K input files do not seem to be the same. Exiting....\n\n"
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
            echo -e " * Preparing the files and directories for the fes with bead-configuration ${bead_configuration}"

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
            sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/ipi/ipi.in.md.xml
            sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/ipi/ipi.in.md.xml
            sed -i "s/subconfiguration/${lambda_configuration}/g" ${md_folder}/ipi/ipi.in.md.xml

            # CP2K
            for bead in $(eval echo "{1..${nbeads}}"); do
                cp ../../../input-files/cp2k/${inputfile_cp2k_md_k_0} ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/fes_basename/${msp_name}.${subsystem}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/runtimeletter/${runtimeletter}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/subconfiguration/${lambda_configuration}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/lambda_value/${lambda_current}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
                sed -i "s/ABC .*/ABC ${A} ${B} ${C}/g" ${md_folder}/cp2k/bead-${bead}/cp2k.in.md
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
            lambda_current=$(echo "${lambda_current} + ${lambda_stepsize}" | bc -l)
            lambda_current="$(LC_ALL=C /usr/bin/printf "%.*f\n" 3 ${lambda_current})"
        done
    fi

    # Preparing the shared CP2K input files
    hqh_fes_prepare_one_fes_common.sh ${nbeads} ${ntdsteps} ${system_1_basename} ${system_2_basename} ${subsystem} ${md_type}

    cd ../../../

# Continuing the old simulation
# Assumes that a previous simulation exists already
elif [ ${md_continue^^} == "TRUE" ]; then
    cd md/${msp_name}/${subsystem}

    for md_folder in md*; do
        cd ${md_folder}
        run_old=$(grep "output.*ipi.out.run" ipi/ipi.in.md.xml | grep -o "run." | grep -o "[0-9]*")
        run_new=$((run_old + 1))
        restart_file=$(ls -1v ipi/ | grep restart | tail -n 1)
        sed -i "s/ipi.out.run${run_old}/ipi.out.run${run_new}/" ipi/ipi.in.md.xml
        if [ "${run_old}" == "1" ]; then
            sed -i "s|^.*opt.pdb.*|      <file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.md.xml
            sed  -i "/momenta/d" ipi/ipi.in.md.xml
        else
            sed -i "s|^.file.*chk.*|      <file mode='chk'> ${restart_file} </file>|g" ipi/ipi.in.md.xml
        fi
        cd ..
    done
else
    echo -e "\n * ERROR: The parameter md_continue of the config.txt file has an unsupported value (md_continue=${md_continue}). Exiting...\n\n"
    echo "" > runtime/error
    exit 1
fi
