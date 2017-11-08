#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_fec_prepare_one_msp.sh <system 1 basename> <system 2 basename> <subsystem>

The script has to be run in the root folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo -e "$usage"
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

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Bash options
#set -o pipefail

# Variables
system_1_basename="${1}"
system_2_basename="${2}"
subsystem="${3}"
msp_name="${system_1_basename}_${system_2_basename}"
subsystem_folder="md/${msp_name}/${subsystem}"
ce_folder="ce/${msp_name}/${subsystem}"
fec_folder="fec/AFE/${msp_name}/${subsystem}"
fec_stride=$(grep -m 1 "^fec_stride_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')
fec_first_snapshot_index=$(grep -m 1 "^fec_first_snapshot_index_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')
umbrella_sampling=$(grep -m 1 "^umbrella_sampling=" input-files/config.txt | awk -F '=' '{print $2}')
subsystem_folder="md/${msp_name}/${subsystem}"
cutoff=1000

# Printing some information
echo -e "\n *** Preparing the FEC between the systems ${system_1_basename} and ${system_2_basename}"

# Checking if the subsystem_folder exists
if [ ! -d "${subsystem_folder}" ]; then
    echo -e "\nError: The folder ${subsystem_folder} does not exist. Exiting\n\n" 1>&2
    exit 1
fi

# Checking if the ce_folder exists
if [ ! -d "${ce_folder}" ]; then
    echo "\nError: The folder ${ce_folder} does not exist. Exiting\n\n" 1>&2
    exit 1
fi

# If we want to change the filenames of the sampling potential according to the reweighting modus
## Setting the sampling potential names
#if [ ${umbrella_sampling^^} == "FALSE" ]; then
#     sampling_potential_1="U1"
#     sampling_potential_2="U2"
#elif [ ${umbrella_sampling^^} == "TRUE" ]; then
#     sampling_potential_1="U1b"
#     sampling_potential_2="U2b"
#fi

# Loop for each TD Window
while read line; do
    
    # Variables
    tds_folder_1="$(echo -n ${line} | awk '{print $1}')"
    tds_folder_2="$(echo -n ${line} | awk '{print $2}')"
    crosseval_folder_fw="${tds_folder_1}-${tds_folder_2}"     # TDS folder1 (positions) is evaluated at folder two's potential: samplingfolder-potentialfolder
    crosseval_folder_bw="${tds_folder_2}-${tds_folder_1}"     # Opposite of fw
    stride_ipi_properties=$(grep "potential" ${subsystem_folder}/${tds_folder_1}/ipi/ipi.in.main.xml | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')
    stride_ipi_trajectory=$(grep "<checkpoint" ${subsystem_folder}/${tds_folder_1}/ipi/ipi.in.main.xml | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')
    #stride_ipi=$((stride_ipi_trajectory  / stride_ipi_properties))
    TD_window="${tds_folder_1}-${tds_folder_2}"

    # Checking if the checkpoint and potential in the ipi input file are equal
    if [ "${stride_ipi_properties}" -ne "${stride_ipi_trajectory}" ]; then
        echo -n "Error: the checkpoint and potential need to have the same stride in the ipi input file\.n\n"
        exit 1
    fi

    # Creating required folders
    if [ -d ${fec_folder}/${TD_window} ]; then
        rm -r ${fec_folder}/${TD_window}
    fi
    mkdir -p ${fec_folder}/${TD_window}

    # Checking if the ipi-input-file <variables stride_ipi_properties> and <stride_ipi_trajectory> are compatible
    echo -e -n " * Checking if the ipi-input-file variables <stride_ipi_properties> and <stride_ipi_trajectory> are compatible... "
    trap '' ERR
    mod="$(( ${stride_ipi_trajectory} % ${stride_ipi_properties}))"
    trap 'error_response_std $LINENO' ERR
    if [ ! "${mod}" == "0" ]; then
        echo " * The variables <stride_ipi_trajectory> and <stride_ipi_properties> are not compatible. <stride_ipi_trajectory> % <stride_ipi_properties> should be zero..."
        echo " * But it was found that ${stride_ipi_trajectory} % ${stride_ipi_properties} = ${mod}"
        exit 1
    fi
    echo "OK"

   # # Uniting all the ipi property files (moved to ce_prepare_one_msp)
   # rm ${subsystem_folder}/${tds_folder_1}/ipi/ipi.out.all_runs.properties 2>&1 1>/dev/null || true
   # rm ${subsystem_folder}/${tds_folder_2}/ipi/ipi.out.all_runs.properties 2>&1 1>/dev/null || true
   # property_files=$(ls -1v ${subsystem_folder}/${tds_folder_1}/ipi/* | grep properties)
   # cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ${subsystem_folder}/${tds_folder_1}/ipi/ipi.out.all_runs.properties
   # property_files=$(ls -1v ${subsystem_folder}/${tds_folder_2}/ipi/* | grep properties)
   # cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ${subsystem_folder}/${tds_folder_2}/ipi/ipi.out.all_runs.properties

    # Loop for the each snapshot pair of the forward direction
    echo " * Preparing the snapshots of the forward direction"
    snapshot_counter=1
    for snapshot_folder in $(ls -v ${ce_folder}/${crosseval_folder_fw}); do


        # Variables
        snapshot_id=${snapshot_folder/*\-}

        # Checking if this snapshout should be skipped
        if [ "${snapshot_counter}" -lt "${fec_first_snapshot_index}" ]; then
            echo " * Skipping snapshot ${snapshot_id} due to the setting fec_first_snapshot_index=${fec_first_snapshot_index}"
            snapshot_counter=$((snapshot_counter+1))
            continue
        fi

        # Extracting the free energies of system 1 evaluated at system 2
        energy_bw_U1_U2="$(grep -v "^#" ${ce_folder}/${crosseval_folder_fw}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"

        # Extracting the free energies of system 1 evaluated at system 1
        # Checking if reweighting should not be used
        if [ "${umbrella_sampling^^}" == "FALSE" ]; then

            # Extracting the free energies of system 1 evaluated at system 1
            energy_bw_U1_U1="$(awk '{print $4}' ${subsystem_folder}/${tds_folder_1}/ipi/ipi.out.all_runs.properties | tail -n +${snapshot_id} | head -n 1)"

            # Checking if the energies were computed and extracted successfully, which is usually the case if there is a number in the value
            if [[ "${energy_bw_U1_U2}" == *[0-9]* ]] && [[ "${energy_bw_U1_U1}" == *[0-9]* ]]; then
                echo "${energy_bw_U1_U2}" >> ${fec_folder}/${TD_window}/U1_U2
                echo "${energy_bw_U1_U1}" >> ${fec_folder}/${TD_window}/U1_U1
            fi
            snapshot_counter=$((snapshot_counter+1))

        # Checking if reweighting should be used
        elif [ "${umbrella_sampling^^}" == "TRUE" ]; then

            # Checking if the required stationary evaluatioin file exists
            if [ -f ${ce_folder}/${tds_folder_1}-${tds_folder_1}/${snapshot_folder}/ipi/ipi.out.properties ]; then

                # Extracting the energy values
                energy_bw_U1_U1="$(grep -v "^#" ${ce_folder}/${tds_folder_1}-${tds_folder_1}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"
                energy_bw_U1_U1biased="$(awk '{print $4}' ${subsystem_folder}/${tds_folder_1}/ipi/ipi.out.all_runs.properties | tail -n+${snapshot_id} | head -n 1)"

            else
                echo "Warning: The postprocessing of snapshot ${snapshot_id} in the forward direction of TD window ${TD_window} will be skipped due non-existent stationary snapshot files."
                echo "         This should not happen since both cross evaluation and stationary re-evaluation are based on the same snapshots."
                snapshot_counter=$((snapshot_counter+1))
                continue
            fi

            # Checking if the energies were computed and extracted successfully, which is usually the case if there is a number in the value
            if [[ "${energy_bw_U1_U2}" == *[0-9]* ]] && [[ "${energy_bw_U1_U1}" == *[0-9]* ]] && [[ "${energy_bw_U1_U1biased}" == *[0-9]* ]]; then
                echo "${energy_bw_U1_U2}" >> ${fec_folder}/${TD_window}/U1_U2
                echo "${energy_bw_U1_U1}" >> ${fec_folder}/${TD_window}/U1_U1
                echo "${energy_bw_U1_U1biased}" >> ${fec_folder}/${TD_window}/U1_U1biased
            fi
            snapshot_counter=$((snapshot_counter+1))

        else
            echo -e "Error: The parameter umbrella_sampling has an unsupported value (${umbrella_sampling}). Exiting...\n\n"
            exit 1
        fi
    done

    # Loop for the each snapshot pair of the backward direction
    echo " * Preparing the snapshots of the backward direction"
    snapshot_counter=1
    for snapshot_folder in $(ls -v ${ce_folder}/${crosseval_folder_bw}); do

        # Variables
        snapshot_id=${snapshot_folder/*\-}

        # Checking if this snapshout should be skipped
        if [ "${snapshot_counter}" -lt "${fec_first_snapshot_index}" ]; then
            echo " * Skipping snapshot ${snapshot_id} due to the setting fec_first_snapshot_index=${fec_first_snapshot_index}"
            snapshot_counter=$((snapshot_counter+1))
            continue
        fi

        # Extracting the free energies of system 2 evaluated at system 1
        energy_bw_U2_U1="$(grep -v "^#" ${ce_folder}/${crosseval_folder_bw}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"

        # Extracting the free energies of system 1 evaluated at system 1
        # Checking if reweighting should not be used
        if [ "${umbrella_sampling^^}" == "FALSE" ]; then

            # Extracting the free energies of system 2 evaluated at system 2
            energy_bw_U2_U2="$(awk '{print $4}' ${subsystem_folder}/${tds_folder_2}/ipi/ipi.out.all_runs.properties | tail -n +${snapshot_id} | head -n 1)"

            # Checking if the energies were computed and extracted successfully, which is usually the case if there is a number in the value
            if [[ "${energy_bw_U2_U1}" == *[0-9]* ]] && [[ "${energy_bw_U2_U2}" == *[0-9]* ]]; then
                echo "${energy_bw_U2_U1}" >> ${fec_folder}/${TD_window}/U2_U1
                echo "${energy_bw_U2_U2}" >> ${fec_folder}/${TD_window}/U2_U2
            fi
            snapshot_counter=$((snapshot_counter+1))

        # Checking if reweighting should be used
        elif [ "${umbrella_sampling^^}" == "TRUE" ]; then

            # Checking if the required stationary evaluatioin file exists
            if [ -f ${ce_folder}/${tds_folder_2}-${tds_folder_2}/${snapshot_folder}/ipi/ipi.out.properties ]; then

                # Extracting the energy values
                energy_bw_U2_U2="$(grep -v "^#" ${ce_folder}/${tds_folder_2}-${tds_folder_2}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"
                energy_bw_U2_U2biased="$(awk '{print $4}' ${subsystem_folder}/${tds_folder_2}/ipi/ipi.out.all_runs.properties | tail -n +${snapshot_id} | head -n 1)"

            else
                echo "Warning: The postprocessing of snapshot ${snapshot_id} in the backward direction of TD window ${TD_window} will be skipped due non-existent stationary snapshot files."
                echo "         This should not happen since both cross evaluation and stationary re-evaluation are based on the same snapshots."
                snapshot_counter=$((snapshot_counter+1))
                continue
            fi

            # Checking if the energies were computed and extracted successfully, which is usually the case if there is a number in the value
            if [[ "${energy_bw_U2_U1}" == *[0-9]* ]] && [[ "${energy_bw_U2_U2}" == *[0-9]* ]] && [[ "${energy_bw_U2_U2biased}" == *[0-9]* ]]; then
                echo "${energy_bw_U2_U1}" >> ${fec_folder}/${TD_window}/U2_U1
                echo "${energy_bw_U2_U2}" >> ${fec_folder}/${TD_window}/U2_U2
                echo "${energy_bw_U2_U2biased}" >> ${fec_folder}/${TD_window}/U2_U2biased
            fi
            snapshot_counter=$((snapshot_counter+1))

        else
            echo -e "Error: The parameter umbrella_sampling has an unsupported value (${umbrella_sampling}). Exiting...\n\n"
            exit 1
        fi
    done

    # Applying the fec stride (additional stride)
    if [ "${fec_stride}" -gt "1" ]; then
        awk -v fec_stride=${fec_stride} 'NR % fec_stride == 1' ${fec_folder}/${TD_window}/U1_U1 > ${fec_folder}/${TD_window}/U1_U1_stride${fec_stride}
        awk -v fec_stride=${fec_stride} 'NR % fec_stride == 1' ${fec_folder}/${TD_window}/U1_U2 > ${fec_folder}/${TD_window}/U1_U2_stride${fec_stride}
        awk -v fec_stride=${fec_stride} 'NR % fec_stride == 1' ${fec_folder}/${TD_window}/U2_U1 > ${fec_folder}/${TD_window}/U2_U1_stride${fec_stride}
        awk -v fec_stride=${fec_stride} 'NR % fec_stride == 1' ${fec_folder}/${TD_window}/U2_U2 > ${fec_folder}/${TD_window}/U2_U2_stride${fec_stride}
        if [ "${umbrella_sampling^^}" == "TRUE" ]; then
            awk -v fec_stride=${fec_stride} 'NR % fec_stride == 1' ${fec_folder}/${TD_window}/U1_U1biased > ${fec_folder}/${TD_window}/U1_U1biased_stride${fec_stride}
            awk -v fec_stride=${fec_stride} 'NR % fec_stride == 1' ${fec_folder}/${TD_window}/U2_U2biased > ${fec_folder}/${TD_window}/U2_U2biased_stride${fec_stride}
        fi

    elif [ "${fec_stride}" -eq "1" ]; then
        cp ${fec_folder}/${TD_window}/U1_U1 ${fec_folder}/${TD_window}/U1_U1_stride${fec_stride}
        cp ${fec_folder}/${TD_window}/U1_U2 ${fec_folder}/${TD_window}/U1_U2_stride${fec_stride}
        cp ${fec_folder}/${TD_window}/U2_U1 ${fec_folder}/${TD_window}/U2_U1_stride${fec_stride}
        cp ${fec_folder}/${TD_window}/U2_U2 ${fec_folder}/${TD_window}/U2_U2_stride${fec_stride}
        if [ "${umbrella_sampling^^}" == "TRUE" ]; then
            cp ${fec_folder}/${TD_window}/U1_U1biased ${fec_folder}/${TD_window}/U1_U1biased_stride${fec_stride}
            cp ${fec_folder}/${TD_window}/U2_U2biased ${fec_folder}/${TD_window}/U2_U2biased_stride${fec_stride}
        fi
    else
        echo -e "\nError: The variable fec_stride is not set correctly in the configuration file. Exiting...\n\n"
        exit 1
    fi

    # Creating cutoff versions
    awk '{if($1==$1+0 && $1<1000 && $1>-1000)print $1}' ${fec_folder}/${TD_window}/U1_U1_stride${fec_stride} > ${fec_folder}/${TD_window}/U1_U1_stride${fec_stride}_cutoff1000
    awk '{if($1==$1+0 && $1<1000 && $1>-1000)print $1}' ${fec_folder}/${TD_window}/U1_U2_stride${fec_stride} > ${fec_folder}/${TD_window}/U1_U2_stride${fec_stride}_cutoff1000
    awk '{if($1==$1+0 && $1<1000 && $1>-1000)print $1}' ${fec_folder}/${TD_window}/U2_U1_stride${fec_stride} > ${fec_folder}/${TD_window}/U2_U1_stride${fec_stride}_cutoff1000
    awk '{if($1==$1+0 && $1<1000 && $1>-1000)print $1}' ${fec_folder}/${TD_window}/U2_U2_stride${fec_stride} > ${fec_folder}/${TD_window}/U2_U2_stride${fec_stride}_cutoff1000
    if [ "${umbrella_sampling^^}" == "TRUE" ]; then
        awk '{if($1==$1+0 && $1<1000 && $1>-1000)print $1}' ${fec_folder}/${TD_window}/U1_U1biased_stride${fec_stride} > ${fec_folder}/${TD_window}/U1_U1biased_stride${fec_stride}_cutoff1000
        awk '{if($1==$1+0 && $1<1000 && $1>-1000)print $1}' ${fec_folder}/${TD_window}/U2_U2biased_stride${fec_stride} > ${fec_folder}/${TD_window}/U2_U2biased_stride${fec_stride}_cutoff1000
    fi

    # Computing the free energy differences delta U without stride (mainly for Mobley pymbar code)
    paste ${fec_folder}/${TD_window}/U1_U1 ${fec_folder}/${TD_window}/U1_U2 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U2-U1_U1 # (U2-U1)_1 -> for our IP method implementation, and for original BAR equation of Bennett (denominator) and our implementation
    paste ${fec_folder}/${TD_window}/U2_U1 ${fec_folder}/${TD_window}/U2_U2 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U2-U2_U1 # (U2-U1)_2 -> for our IP method implemenation
    paste ${fec_folder}/${TD_window}/U2_U2 ${fec_folder}/${TD_window}/U2_U1 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U1-U2_U2 # for our original BAR equation of Bennett (nominator) implemenation
    paste ${fec_folder}/${TD_window}/U1_U2 ${fec_folder}/${TD_window}/U1_U1 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U1-U1_U2 # for our original BAR equation of Bennett (nominator) implemenation
    if [ "${umbrella_sampling^^}" == "TRUE" ]; then
        paste ${fec_folder}/${TD_window}/U1_U1biased ${fec_folder}/${TD_window}/U1_U1 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U1biased-U1_U1
        paste ${fec_folder}/${TD_window}/U2_U2biased ${fec_folder}/${TD_window}/U2_U2 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U2biased-U2_U2
    fi

    # Computing the free energy differences delta U with stride applied (mainly for Mobley pymbar code)
    paste ${fec_folder}/${TD_window}/U2_U2_stride${fec_stride} ${fec_folder}/${TD_window}/U2_U1_stride${fec_stride} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U1-U2_U2_stride${fec_stride}
    paste ${fec_folder}/${TD_window}/U1_U1_stride${fec_stride} ${fec_folder}/${TD_window}/U1_U2_stride${fec_stride} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}
    paste ${fec_folder}/${TD_window}/U2_U1_stride${fec_stride} ${fec_folder}/${TD_window}/U2_U2_stride${fec_stride} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}
    paste ${fec_folder}/${TD_window}/U1_U2_stride${fec_stride} ${fec_folder}/${TD_window}/U1_U1_stride${fec_stride} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U1-U1_U2_stride${fec_stride}
    if [ "${umbrella_sampling^^}" == "TRUE" ]; then
        paste ${fec_folder}/${TD_window}/U1_U1biased_stride${fec_stride} ${fec_folder}/${TD_window}/U1_U1_stride${fec_stride} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}
        paste ${fec_folder}/${TD_window}/U2_U2biased_stride${fec_stride} ${fec_folder}/${TD_window}/U2_U2_stride${fec_stride} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}
    fi

    # Creating cutoff versions of the difference files
    awk -v cutoff="${cutoff}" '{if($1==$1+0 && $1<cutoff && $1>-cutoff)print $1}' ${fec_folder}/${TD_window}/U2_U1-U2_U2_stride${fec_stride} > ${fec_folder}/${TD_window}/U2_U1-U2_U2_stride${fec_stride}_cutoff${cutoff}
    awk -v cutoff="${cutoff}" '{if($1==$1+0 && $1<cutoff && $1>-cutoff)print $1}' ${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride} > ${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}_cutoff${cutoff}
    awk -v cutoff="${cutoff}" '{if($1==$1+0 && $1<cutoff && $1>-cutoff)print $1}' ${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride} > ${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}_cutoff${cutoff}
    awk -v cutoff="${cutoff}" '{if($1==$1+0 && $1<cutoff && $1>-cutoff)print $1}' ${fec_folder}/${TD_window}/U1_U1-U1_U2_stride${fec_stride} > ${fec_folder}/${TD_window}/U1_U1-U1_U2_stride${fec_stride}_cutoff${cutoff}
    if [ "${umbrella_sampling^^}" == "TRUE" ]; then
        awk -v cutoff="${cutoff}" '{if($1==$1+0 && $1<cutoff && $1>-cutoff)print $1}' ${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride} > ${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}_cutoff${cutoff}
        awk -v cutoff="${cutoff}" '{if($1==$1+0 && $1<cutoff && $1>-cutoff)print $1}' ${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride} > ${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}_cutoff${cutoff}
    fi

    # Drawing histograms
    hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}.plot"
    hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}.plot"
    hqh_fec_plot_two_hist.py "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}" "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/delta_1_U,delta_2_U_stride${fec_stride}.plot"
    if [[ -s "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}_cutoff${cutoff}" ]]; then
        hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}_cutoff${cutoff}" "normal" "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}_cutoff${cutoff}.plot"
    fi
    if [[ -s "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}_cutoff${cutoff}" ]]; then
        hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}_cutoff${cutoff}" "normal" "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}_cutoff${cutoff}.plot"
    fi
    if [[ -s "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}_cutoff${cutoff}" && -s "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}_cutoff${cutoff}" ]]; then
        hqh_fec_plot_two_hist.py "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}_cutoff${cutoff}" "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}_cutoff${cutoff}" "normal" "${fec_folder}/${TD_window}/delta_1_U,delta_2_U_stride${fec_stride}_cutoff${cutoff}.plot"
    fi
    if [ "${umbrella_sampling^^}" == "TRUE" ]; then
        hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}.plot"
        hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}.plot"
        if [[ -s "${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}_cutoff${cutoff}" ]]; then
            hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}_cutoff${cutoff}" "normal" "${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}_cutoff${cutoff}.plot"
        fi
        if [[ -s "${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}_cutoff${cutoff}" ]]; then
            hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}_cutoff${cutoff}" "normal" "${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}_cutoff${cutoff}.plot"
        fi
    fi
done <${ce_folder}/TD_windows.list
