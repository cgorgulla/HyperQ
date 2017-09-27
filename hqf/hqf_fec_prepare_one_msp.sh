#!/usr/bin/env bash 

# Usage infomation
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

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Bash options
#set -o pipefail

# Variables
system_1_basename="${1}"
system_2_basename="${2}"
subsystem="${3}"
msp_name="${system_1_basename}_${system_2_basename}"
md_folder="md/${msp_name}/${subsystem}"
ce_folder="ce/${msp_name}/${subsystem}"
fec_folder="fec/AFE/${msp_name}/${subsystem}"
fec_stride=$(grep -m 1 "^fec_stride_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')
fec_first_snapshot_index=$(grep -m 1 "^fec_first_snapshot_index_${subsystem}=" input-files/config.txt | awk -F '=' '{print $2}')
umbrella_sampling=$(grep -m 1 "^umbrella_sampling=" input-files/config.txt | awk -F '=' '{print $2}')
md_folder="md/${msp_name}/${subsystem}"

# Printing some information
echo -e "\n *** Preparing the FEC between the systems ${system_1_basename} and ${system_2_basename}"

# Checking if the md_folder exists
if [ ! -d "${md_folder}" ]; then
    echo -e "\nError: The folder ${md_folder} does not exist. Exiting\n\n" 1>&2
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
    md_folder_1="$(echo -n ${line} | awk '{print $1}')"
    md_folder_2="$(echo -n ${line} | awk '{print $2}')"
    crosseval_folder_fw="${md_folder_1}-${md_folder_2}"     # md folder1 (positions) is evaluated at folder two's potential: samplingfolder-potentialfolder
    crosseval_folder_bw="${md_folder_2}-${md_folder_1}"     # Opposite of fw
    stride_ipi_properties=$(grep "potential" ${md_folder}/${md_folder_1}/ipi/ipi.in.md.xml | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')
    stride_ipi_trajectory=$(grep "<checkpoint" ${md_folder}/${md_folder_1}/ipi/ipi.in.md.xml | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')
    #stride_ipi=$((stride_ipi_trajectory  / stride_ipi_properties))
    TD_window="${md_folder_1}-${md_folder_2}"

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

   # # Uniting all the ipi property files
   # rm ${md_folder}/${md_folder_1}/ipi/ipi.out.all_runs.properties 2>&1 1>/dev/null || true
   # rm ${md_folder}/${md_folder_2}/ipi/ipi.out.all_runs.properties 2>&1 1>/dev/null || true
   # property_files=$(ls -1v ${md_folder}/${md_folder_1}/ipi/* | grep properties)
   # cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ${md_folder}/${md_folder_1}/ipi/ipi.out.all_runs.properties
   # property_files=$(ls -1v ${md_folder}/${md_folder_2}/ipi/* | grep properties)
   # cat ${property_files} | grep -v "^#" | grep -v "^ *0.00000000e+00" > ${md_folder}/${md_folder_2}/ipi/ipi.out.all_runs.properties

    # Loop for the each snapshot pair of the forward direction
    echo " * Preparing the snapshots of the forward direction"
    snapshot_counter=1
    for snapshot_folder in $(ls -v ${ce_folder}/${crosseval_folder_fw}); do


        # Variables
        snapshot_ID=${snapshot_folder/*\-}

        # Checking if this snapshout should be skipped
        if [ "${snapshot_counter}" -lt "${fec_first_snapshot_index}" ]; then
            echo " * Skipping snapshot ${snapshot_ID} due to the setting fec_first_snapshot_index=${fec_first_snapshot_index}"
            snapshot_counter=$((snapshot_counter+1))
            continue
        fi

        # Extracting the free energies of system 1 evaluated at system 2
        energy_bw_U1_U2="$(grep -v "^#" ${ce_folder}/${crosseval_folder_fw}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"

        # Extracting the free energies of system 1 evaluated at system 1
        # Checking if reweighting should not be used
        if [ "${umbrella_sampling^^}" == "FALSE" ]; then

            # Extracting the free energies of system 1 evaluated at system 1
            energy_bw_U1_U1="$(awk '{print $4}' ${md_folder}/${md_folder_1}/ipi/ipi.out.all_runs.properties | tail -n+${snapshot_ID} | head -n 1)"

            # Checking if the energies were computed and extracted successfully, which is usually the case if there is a number in the value
            if [[ "${energy_bw_U1_U2}" == *[0-9]* ]] && [[ "${energy_bw_U1_U1}" == *[0-9]* ]]; then
                echo "${energy_bw_U1_U2}" >> ${fec_folder}/${TD_window}/U1_U2
                echo "${energy_bw_U1_U1}" >> ${fec_folder}/${TD_window}/U1_U1
            fi
            snapshot_counter=$((snapshot_counter+1))

        # Checking if reweighting should be used
        elif [ "${umbrella_sampling^^}" == "TRUE" ]; then

            # Checking if the required stationary evaluatioin file exists
            if [ -f ${ce_folder}/${md_folder_1}-${md_folder_1}/${snapshot_folder}/ipi/ipi.out.properties ]; then

                # Extracting the energy values
                energy_bw_U1_U1="$(grep -v "^#" ${ce_folder}/${md_folder_1}-${md_folder_1}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"
                energy_bw_U1_U1biased="$(awk '{print $4}' ${md_folder}/${md_folder_1}/ipi/ipi.out.all_runs.properties | tail -n+${snapshot_ID} | head -n 1)"

            else
                echo "Warning: The postprocessing of snapshot ${snapshot_ID} in the forward direction of TD window ${TD_window} will be skipped due non-existent stationary snapshot files."
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
        snapshot_ID=${snapshot_folder/*\-}

        # Checking if this snapshout should be skipped
        if [ "${snapshot_counter}" -lt "${fec_first_snapshot_index}" ]; then
            echo " * Skipping snapshot ${snapshot_ID} due to the setting fec_first_snapshot_index=${fec_first_snapshot_index}"
            snapshot_counter=$((snapshot_counter+1))
            continue
        fi

        # Extracting the free energies of system 2 evaluated at system 1
        energy_bw_U2_U1="$(grep -v "^#" ${ce_folder}/${crosseval_folder_bw}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"

        # Extracting the free energies of system 1 evaluated at system 1
        # Checking if reweighting should not be used
        if [ "${umbrella_sampling^^}" == "FALSE" ]; then

            # Extracting the free energies of system 2 evaluated at system 2
            energy_bw_U2_U2="$(awk '{print $4}' ${md_folder}/${md_folder_2}/ipi/ipi.out.all_runs.properties | tail -n+${snapshot_ID} | head -n 1)"

            # Checking if the energies were computed and extracted successfully, which is usually the case if there is a number in the value
            if [[ "${energy_bw_U2_U1}" == *[0-9]* ]] && [[ "${energy_bw_U2_U2}" == *[0-9]* ]]; then
                echo "${energy_bw_U2_U1}" >> ${fec_folder}/${TD_window}/U2_U1
                echo "${energy_bw_U2_U2}" >> ${fec_folder}/${TD_window}/U2_U2
            fi
            snapshot_counter=$((snapshot_counter+1))

        # Checking if reweighting should be used
        elif [ "${umbrella_sampling^^}" == "TRUE" ]; then

            # Checking if the required stationary evaluatioin file exists
            if [ -f ${ce_folder}/${md_folder_2}-${md_folder_2}/${snapshot_folder}/ipi/ipi.out.properties ]; then

                # Extracting the energy values
                energy_bw_U2_U2="$(grep -v "^#" ${ce_folder}/${md_folder_2}-${md_folder_2}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"
                energy_bw_U2_U2biased="$(awk '{print $4}' ${md_folder}/${md_folder_2}/ipi/ipi.out.all_runs.properties | tail -n+${snapshot_ID} | head -n 1)"

            else
                echo "Warning: The postprocessing of snapshot ${snapshot_ID} in the backward direction of TD window ${TD_window} will be skipped due non-existent stationary snapshot files."
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

    # Preparing the C-values
    #hqh_fec_prepare_cvalues.py ${c_values_min} ${c_values_max} ${c_values_count} > ${fec_folder}/${TD_window}/C-values

    # Drawing histograms
    hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}.plot"
    hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}.plot"
    hqh_fec_plot_two_hist.py "${fec_folder}/${TD_window}/U1_U2-U1_U1_stride${fec_stride}" "${fec_folder}/${TD_window}/U2_U2-U2_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/delta_1_U,delta_2_U_stride${fec_stride}.plot"
    if [ "${umbrella_sampling^^}" == "TRUE" ]; then
        hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U1_U1biased-U1_U1_stride${fec_stride}.plot"
        hqh_fec_plot_hist.py "${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}" "normal" "${fec_folder}/${TD_window}/U2_U2biased-U2_U2_stride${fec_stride}.plot"
    fi
    
done <${ce_folder}/TD_windows.list
