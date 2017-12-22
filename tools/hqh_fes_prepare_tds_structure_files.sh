#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_fes_prepare_tds_structure_files.sh

Has to be run in the subsystem folder of the MSP."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "0" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 0"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

center_text(){

    # Variables
    input_text="$1"
    text_width=${#1}
    output_width="$2"
    left_padding_plus_text_width=$(( ($output_width + $text_width) / 2))
    printf "%${left_padding_plus_text_width}s" "$input_text"
}

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

# Bash options
set -o pipefail

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
runtype="$(pwd | awk -F '/' '{print $(NF-2)}')"
sim_type="$(grep -m 1 "^${runtype}_type_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_msp_transformation_type="$(grep -m 1 "^tdcycle_msp_transformation_type=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_activate="$(grep -m 1 "^tdcycle_si_activate=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_hydrogen_single_step="$(grep -m 1 "^tdcycle_si_hydrogen_single_step=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_separate_neighbors="$(grep -m 1 "^tdcycle_si_separate_neighbors=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_consider_branches="$(grep -m 1 "^tdcycle_si_consider_branches=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$((tdw_count_total + 1))"
tdw_count_es_transformation="$(grep -m 1 "^tdw_count_es_transformation=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_es_transformation="$((tdw_count_es_transformation + 1))"
tdw_count_msp_transformation="$(grep -m 1 "^tdw_count_msp_transformation=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_msp_transformation="$((tdw_count_msp_transformation + 1))"
tdcycle_es_transformation_tds_configurations="$(grep -m 1 "^tdcycle_es_transformation_tds_configurations=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
es_transformation_atoms_to_transform="$(grep -m 1 "^es_transformation_atoms_to_transform=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"


# Verifying that the variables have compatible values
echo -e " * Checking if the variables <tdw_count_total>, <tdw_count_es_transformation> and <tdw_count_msp_transformation> are compatible... "
if [ "${tdw_count_total}" -eq "$(( 2*tdw_count_es_transformation+tdw_count_msp_transformation))" ]; then

    # Printing the result
    echo "Check passed. Continuing..."
else
    # Printing error message
    echo "Check failed. The variables <tdw_count_total> (${tdw_count_total}), <tdw_count_es_transformation> (${tdw_count_es_transformation}) and <tdw_count_msp_transformation> (${tdw_count_msp_transformation}) do not have valid/compatible values."
    echo "The following condition is not met: tdw_count_total = 2*tdw_count_es_transformation + tdw_count_msp_transformation"
    echo "Exiting..."

    # Exiting
    exit 1
fi
echo -e " * Checking if the variables <tdw_count_es_transformation> and <tdcycle_es_transformation_tds_configurations> are compatible..."
tdcycle_es_transformation_scalingfactor_count="$(echo ${tdcycle_es_transformation_tds_configurations} | tr ':' ' ' | wc -w)"
if [ "${tdcycle_es_transformation_scalingfactor_count}" -eq "${tds_count_es_transformation}" ]; then

    # Printing the result
    echo "Check passed. Continuing..."
else
    # Printing error message
    echo "Check failed. The variables <tdw_count_es_transformation> (${tdw_count_es_transformation}) and <tdcycle_es_transformation_scalingfactor_count> (${tdcycle_es_transformation_scalingfactor_count}) do not have valid/compatible values...."
    echo "The following condition is not met: tdcycle_es_transformation_scalingfactor_count = tdw_count_es_transformation + 1 "
    echo "Exiting..."

    # Exiting
    exit 1
fi

# Preparing and folders
for tds_index in $(seq 1 ${tds_count_total}); do
    mkdir -p tds-${tds_index}/general
done

# Setting up the tdc overview file
echo -e "\n\n\n"
echo " General Settings" | tee tdc.ov # overwrites existing file if present
echo "---------------------------------------------------------------" | tee -a tdc.ov
echo " nbeads: ${nbeads}"  | tee -a tdc.ov
echo " tdw_count_total: ${tdw_count_total}" | tee -a tdc.ov
echo " tds_count_total: ${tds_count_total}" | tee -a tdc.ov
echo " tdw_count_es_transformation: ${tdw_count_es_transformation}" | tee -a tdc.ov
echo " tds_count_es_transformation: ${tds_count_es_transformation}" | tee -a tdc.ov
echo " tdw_count_msp_transformation: ${tdw_count_msp_transformation}" | tee -a tdc.ov
echo " tds_count_msp_transformation: ${tds_count_msp_transformation}" | tee -a tdc.ov
echo " tdcycle_es_transformation_tds_configurations: ${tdcycle_es_transformation_tds_configurations}" | tee -a tdc.ov
echo -e "\n" | tee -a tdc.ov
if [ "${tdcycle_msp_transformation_type}" == "lambda" ]; then
    printf " %13s %32s %22s %28s %27s\n" "TDS ID" "ES Transformation ID" "ES Scalingfactor" "MSP Transformation ID" "MSP Configuration" | tee -a tdc.ov
    echo "--------------------------------------------------------------------------------------------------------------------------------------" | tee -a tdc.ov
elif [ "${tdcycle_msp_transformation_type}" == "hq" ]; then
    printf " %13s %32s %22s %28s %27s %35s\n" 'TDS ID' 'ES Transformation ID' 'ES Scalingfactor' 'MSP Transformation ID' 'MSP Configuration' 'Associated Lambda Configuration' | tee -a tdc.ov
    echo "---------------------------------------------------------------------------------------------------------------------------------------------------------------------" | tee -a tdc.ov
fi
echo -e "\n\n\n"
# Determining the TDS msp transformation configurations
# Determining the TDS independent msp transformation variables
if [ "${tdcycle_msp_transformation_type}" == "hq" ]; then

    # Variables
    bead_step_size_basic=$((${nbeads}/${tdw_count_msp_transformation}))
    bead_step_size_remainder=$((${nbeads}%${tdw_count_msp_transformation}))

elif [ "${tdcycle_msp_transformation_type}" == "lambda" ]; then

    # Variables
    lambda_stepsize=$(echo "print(1/${tdw_count_msp_transformation})" | python3)
fi
# Determining the TDS dependent msp transformation variables
for tds_msp_transformation_index in $(seq 1 ${tds_count_msp_transformation}); do

    # Checking which type of TDC
    if [ "${tdcycle_msp_transformation_type}" == "hq" ]; then

        # Determining the bead step size
        if [ "${tds_msp_transformation_index}" == "1" ]; then
            bead_count1="${nbeads}"
            bead_step_size=0
        elif    [ "${bead_step_size_remainder}" -gt "0" ]; then
            bead_step_size="$((bead_step_size_basic+1))"
            bead_step_size_remainder="$((bead_step_size_remainder-1))"
        else
            bead_step_size="${bead_step_size_basic}"
        fi
        bead_count1="$(( bead_count1 - bead_step_size ))" # Previous bead count minus the step size
        bead_count2="$(( nbeads - bead_count1 ))"
        # If there are less beads than tdw_msp_transformation, then we use nbeads as a reference for computing associated lambda values
        if [ "${nbeads}" -lt "${tdw_count_msp_transformation}" ]; then
            if [ "${tds_msp_transformation_index}" -le "${nbeads}" ]; then
                lambda=$(echo "$((tds_msp_transformation_index-1))/${nbeads}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
            else
                lambda="1.000"
            fi
        else
            lambda=$(echo "$((tds_msp_transformation_index-1))/${tdw_count_msp_transformation}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        fi
        tds_msp_configuration_local[${tds_msp_transformation_index}]="k_${bead_count1}_${bead_count2}"     # Called local not because it is in this loop but the index is relative to the msp transformations only
        tds_msp_configuration_local_associated_lambda[${tds_msp_transformation_index}]="lambda_${lambda}"
    elif [ "${tdcycle_msp_transformation_type}" == "lambda" ]; then

        # Variables
        lambda=$(echo "$((tds_msp_transformation_index-1))/${tdw_count_msp_transformation}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        tds_msp_configuration_local[${tds_msp_transformation_index}]=lambda_${lambda}
    fi
done

# Determining the TDS es transformation configurations
array_temp=(${tdcycle_es_transformation_tds_configurations//:/ })
for tds_es_transformation_index in $(seq 1 ${tds_count_es_transformation}); do

    # Shifting the array indices by 1 and adding the prefix 'sf' for scaling-factor
    tds_es_configuration_local[${tds_es_transformation_index}]=sf_${array_temp[$((tds_es_transformation_index-1))]} # Called local not because it is in this loop but the index is relative to the es transformations only
done

# Creating the TDS configurations and associated configuration files
for tds_index in $(seq 1 ${tds_count_total}); do

    # Determining the tds_es_configuration
    if [[ "${tds_index}" -le "${tds_count_es_transformation}" ]]; then
        tds_es_transformation_index="${tds_index}"          # es and msp transformation indices are always relative to their type of transformation, i.e. local, thus we don't need this information in the variable name
    elif [[ "${tds_index}" -ge "$((tds_count_total-tds_count_es_transformation+1))" ]]; then
        tds_es_transformation_index="$((tds_count_total-tds_index+1))"
    else
        tds_es_transformation_index="${tds_count_es_transformation}"
    fi
    tds_to_es_transformation_index[${tds_index}]=${tds_es_transformation_index}
    tds_es_configuration[${tds_index}]=${tds_es_configuration_local[${tds_es_transformation_index}]}

    # Determining the tds_msp_configuration
    if [[ "${tds_index}" -le "${tds_count_es_transformation}" ]]; then
        tds_msp_transformation_index="1"
        tds_to_msp_transformation_index[${tds_index}]="1"          # Called local not because it is in this loop but the index is relative to the msp transformations only
    elif [[ "${tds_index}" -ge "$((tds_count_es_transformation-1+tds_count_msp_transformation))" ]]; then
        tds_msp_transformation_index="${tds_count_msp_transformation}"
    else
        tds_msp_transformation_index="$((tds_index-tds_count_es_transformation+1))"
    fi
    tds_to_msp_transformation_index[${tds_index}]=${tds_msp_transformation_index}
    tds_msp_configuration[${tds_index}]=${tds_msp_configuration_local[${tds_msp_transformation_index}]}
    if [ "${tdcycle_msp_transformation_type}" = "hq" ]; then
        tds_msp_configuration_associated_lambda[${tds_index}]=${tds_msp_configuration_local_associated_lambda[${tds_msp_transformation_index}]}
    fi

    # Storing the configurations in text files
    echo "tds_es_transformation_index=${tds_es_transformation_index}" > tds-${tds_index}/general/configuration.txt
    echo "tds_es_configuration=${tds_es_configuration[${tds_index}]}" >> tds-${tds_index}/general/configuration.txt
    echo "tds_msp_transformation_index=${tds_msp_transformation_index}" >> tds-${tds_index}/general/configuration.txt
    echo "tds_msp_configuration=${tds_msp_configuration[${tds_index}]}" >> tds-${tds_index}/general/configuration.txt
    if [ "${tdcycle_msp_transformation_type}" = "hq" ]; then
        echo "tds_msp_configuration_associated_lambda=${tds_msp_configuration_associated_lambda[${tds_index}]/lambda_}" >> tds-${tds_index}/general/configuration.txt
    fi
    if [ "${tdcycle_msp_transformation_type}" = "lambda" ]; then
        printf " %10s %25s %25.3f %25s %32s\n" "${tds_index}" "${tds_es_transformation_index}" "${tds_es_configuration[${tds_index}]//sf_}" "${tds_msp_transformation_index}" "${tds_msp_configuration[${tds_index}]}" | tee -a tdc.ov
    elif [ "${tdcycle_msp_transformation_type}" = "hq" ]; then
        printf " %10s %25s %25.3f %25s %32s %27.3f\n" "${tds_index}" "${tds_es_transformation_index}" "${tds_es_configuration[${tds_index}]//sf_}" "${tds_msp_transformation_index}" "${tds_msp_configuration[${tds_index}]}" "${tds_msp_configuration_associated_lambda[${tds_index}]/lambda_}" | tee -a tdc.ov
    fi
done

# Creating the dummy atom indices files for the msp transformation
if [ "${tdcycle_si_activate^^}" == "TRUE" ]; then
    hqh_fes_prepare_tds_si_dummies.py system1 system1.cp2k.psf system1.prm ${tdw_count_msp_transformation} ${tdcycle_si_hydrogen_single_step} ${tdcycle_si_separate_neighbors} ${tdcycle_si_consider_branches} decreasing system1.tds_msp_transformation-
    hqh_fes_prepare_tds_si_dummies.py system2 system2.cp2k.psf system2.prm ${tdw_count_msp_transformation} ${tdcycle_si_hydrogen_single_step} ${tdcycle_si_separate_neighbors} ${tdcycle_si_consider_branches} increasing system2.tds_msp_transformation-
fi


# Preparing the dummy indices including the bonded atoms (neighbors)
echo -n "" > system1.dummies_and_neighbors.indices
echo -n "" > system2.dummies_and_neighbors.indices
hqh_fes_prepare_dummy_neighbors.py system1 system1.cp2k.psf system1.dummy.indices system1.dummies_and_neighbors.indices
hqh_fes_prepare_dummy_neighbors.py system2 system1.cp2k.psf system2.dummy.indices system2.dummies_and_neighbors.indices

# Preparing the files and folders
for tds_index in $(seq 1 ${tds_count_total}); do

    # Creating the folders
    cd tds-${tds_index}/general/

    # Copying the basic files of the two systems of the MSP
    for system_ID in 1 2; do
        cp ../../system${system_ID}.pdb ./
        cp ../../system${system_ID}.prm ./
        cp ../../system${system_ID}.dummy.psf ./
    done

    # Checking if serial insertion is activated
    if [ "${tdcycle_si_activate^^}" == "TRUE" ]; then

        # Copying the dummy atom indices files (Not moving, parallel robustness, and convenience for us if we want to see all the files)
        cp ../../system1.tds_msp_transformation-${tds_to_msp_transformation_index[${tds_index}]}.dummy.indices system1.dummy.indices
        cp ../../system2.tds_msp_transformation-${tds_to_msp_transformation_index[${tds_index}]}.dummy.indices system2.dummy.indices

        # Carrying out the electrostatic transformation of the entire system
        es_configuration="${tds_es_configuration[${tds_index}]}"
        if [ "${es_transformation_atoms_to_transform}" = "dao" ]; then
            hqh_fes_psf_transform_into_dummies.py ../../system1.cp2k.psf "$(cat ../../system1.dummy.indices)" "${es_configuration/sf_}" "false" system1.cp2k.psf
            hqh_fes_psf_transform_into_dummies.py ../../system2.cp2k.psf "$(cat ../../system2.dummy.indices)" "${es_configuration/sf_}" "false" system2.cp2k.psf
        elif [ "${es_transformation_atoms_to_transform}" = "dawn" ]; then
            hqh_fes_psf_transform_into_dummies.py ../../system1.cp2k.psf "$(cat ../../system1.dummies_and_neighbors.indices)" "${es_configuration/sf_}" "false" system1.cp2k.psf
            hqh_fes_psf_transform_into_dummies.py ../../system2.cp2k.psf "$(cat ../../system2.dummies_and_neighbors.indices)" "${es_configuration/sf_}" "false" system2.cp2k.psf
        elif [ "${es_transformation_atoms_to_transform}" = "ligand" ]; then
            hqh_fes_psf_transform_into_dummies.py ../../system1.cp2k.psf "ligand" "${es_configuration/sf_}" "false" system1.cp2k.psf
            hqh_fes_psf_transform_into_dummies.py ../../system2.cp2k.psf "ligand" "${es_configuration/sf_}" "false" system2.cp2k.psf
        else
            # Printing error message
            echo "Error: The variable es_transformation_atoms_to_transform has an unsupported value (${es_transformation_atoms_to_transform}). Exiting..."

            # Exiting
            exit 1
        fi

        # Carrying out the transformation of some atoms into complete dummy atoms (atoms types to DUM in psf file, used by prm file)
        hqh_fes_psf_transform_into_dummies.py system1.cp2k.psf "$(cat system1.dummy.indices)" "0" "true" system1.cp2k.psf.tmp
        hqh_fes_psf_transform_into_dummies.py system2.cp2k.psf "$(cat system2.dummy.indices)" "0" "true" system2.cp2k.psf.tmp
        mv system1.cp2k.psf.tmp system1.cp2k.psf
        mv system2.cp2k.psf.tmp system2.cp2k.psf
        hqh_fes_prm_transform_into_dummies.py system1 system1.cp2k.psf system1.dummy.indices system1.prm
        hqh_fes_prm_transform_into_dummies.py system2 system2.cp2k.psf system2.dummy.indices system2.prm

        # Preparing the CP2K dummy atom files for the dummy system
        hqh_fes_prepare_cp2k_dummies.py system1 ../../system1.cp2k.psf ../../system1.prm system1.dummy.indices
        hqh_fes_prepare_cp2k_dummies.py system2 ../../system2.cp2k.psf ../../system2.prm system2.dummy.indices
    else

        # Copying the basic files of the two systems of the MSP
        for system_ID in 1 2; do
            cp ../../system${system_ID}.dummy.indices ./
            cp ../../system${system_ID}.dummy.psf ./
            cp ../../system${system_ID}.cp2k.psf ./
            cp ../../cp2k.in.bonds.system${system_ID} ./
            cp ../../cp2k.in.angles.system${system_ID} ./
            cp ../../cp2k.in.dihedrals.system${system_ID} ./
            cp ../../cp2k.in.impropers.system${system_ID} ./
            cp ../../cp2k.in.lj.system${system_ID} ./
        done
    fi

    # Changing to the original directory
    cd ../../
done
