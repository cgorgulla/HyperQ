#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_ce_prepare_one_fes.py

<msp_name> <subsystem> <pipeline_type>

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
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
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
set -u
#set -xeuo pipefail

# Variables
system_1_basename="${1}"
system_2_basename="${2}"
subsystem="${3}"
msp_name="${system_1_basename}_${system_2_basename}"
md_folder="md/${msp_name}/${subsystem}"
ce_folder="ce/${msp_name}/${subsystem}"
fec_folder="fec/AFE/${msp_name}/${subsystem}"
c_values_min=$(grep -m 1 "^c_values_min=" input-files/config.txt | awk -F '=' '{print $2}')
c_values_max=$(grep -m 1 "^c_values_max=" input-files/config.txt | awk -F '=' '{print $2}')
c_values_count=$(grep -m 1 "^c_values_count=" input-files/config.txt | awk -F '=' '{print $2}')
stride_fec=$(grep -m 1 "^stride_fec=" input-files/config.txt | awk -F '=' '{print $2}')

# Printing some information
echo -e "\n *** Preparing the FEC between the systems ${system_1_basename} and ${system_2_basename}"

# Creating required folders
if [ -d ${fec_folder} ]; then         
    rm -r ${fec_folder}
fi
mkdir -p ${fec_folder}

# Loop for each TD Window
while read line; do 
    md_folder_1="$(echo -n ${line} | awk '{print $1}')"
    md_folder_2="$(echo -n ${line} | awk '{print $2}')"    
    crosseval_folder_fw="${md_folder_2}-${md_folder_1}"     # md folder1 (positions) is evaluated at folder two's potential: potentialfolder-positionfolder
    crosseval_folder_bw="${md_folder_1}-${md_folder_2}"     # Opposite of fw
    
    # Variables 
    stride_ipi_properties=$(grep "potential" ${md_folder}/${md_folder_1}/ipi/ipi.in.md.xml | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')
    stride_ipi_trajectory=$(grep "<checkpoint" ${md_folder}/${md_folder_1}/ipi/ipi.in.md.xml | tr -s " " "\n" | grep "stride" | awk -F '=' '{print $2}' | tr -d '"')
    stride_ipi=$((stride_ipi_trajectory  / stride_ipi_properties))
    stride_fec=$(grep -m 1 "^stride_fec=" input-files/config.txt | awk -F '=' '{print $2}')
    TD_window=${md_folder_1}-${md_folder_2}

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

    mkdir ${fec_folder}/${TD_window} 

    # Loop for the each snapshot pair
    snapshotCount=$(ls ${ce_folder}/${crosseval_folder_fw} | wc -l)
    for snapshot_ID in $(seq 0 $((snapshotCount -1))); do
        snapshot_folder=snapshot-${snapshot_ID}

        # Foward direction
        # Extracting the free energies of system 1 evaluated at system 2
        energy_fw_U2_U1="$(grep -v "^#" ${ce_folder}/${crosseval_folder_fw}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"
        # Extracting the free energies of system 1 evaluated at system 1
        energy_fw_U1_U1="$(grep -v "^#" ${md_folder}/${md_folder_1}/ipi/ipi.out.properties | awk '{print $4}' | tail -n+$((snapshot_ID +1)) | head -n 1)"

        if [[ "${energy_fw_U2_U1}" == *[0-9]* ]] && [[ "${energy_fw_U1_U1}" == *[0-9]* ]]; then
            echo "${energy_fw_U2_U1}" >>  ${fec_folder}/${TD_window}/U2_U1
            echo "${energy_fw_U1_U1}" >>  ${fec_folder}/${TD_window}/U1_U1
        fi
    done
    snapshotCount=$(ls ${ce_folder}/${crosseval_folder_bw} | wc -l)
    for snapshot_ID in $(seq 0 $((snapshotCount -1))); do
        snapshot_folder=snapshot-${snapshot_ID}

        # Backward direction
        # Extracting the free energies of system 2 evaluated at system 1
        energy_bw_U1_U2="$(grep -v "^#" ${ce_folder}/${crosseval_folder_bw}/${snapshot_folder}/ipi/ipi.out.properties | awk '{print $4}')"
        # Extracting the free energies of system 2 evaluated at system 2
        energy_bw_U2_U2="$(grep -v "^#" ${md_folder}/${md_folder_2}/ipi/ipi.out.properties | awk '{print $4}' | tail -n+$((snapshot_ID +1)) | head -n 1)"

        # Checking if the energies were computed and extracted successfully, which is usually the case if there is a number in the value
        #if [[ "${energy_bw_U1_U2}" == *[0-9]* ]] && [[ "${energy_bw_U2_U2}" == *[0-9]* ]] && [[ "${energy_fw_U2_U1}" == *[0-9]* ]] && [[ "${energy_fw_U1_U1}" == *[0-9]* ]]; then
        #    echo "${energy_fw_U2_U1}" >>  ${fec_folder}/${TD_window}/U2_U1
        #    echo "${energy_fw_U1_U1}" >>  ${fec_folder}/${TD_window}/U1_U1
        #    echo "${energy_bw_U1_U2}" >>  ${fec_folder}/${TD_window}/U1_U2
        #    echo "${energy_bw_U2_U2}" >>  ${fec_folder}/${TD_window}/U2_U2
        #fi
        if [[ "${energy_bw_U1_U2}" == *[0-9]* ]] && [[ "${energy_bw_U2_U2}" == *[0-9]* ]]; then
            echo "${energy_bw_U1_U2}" >>  ${fec_folder}/${TD_window}/U1_U2
            echo "${energy_bw_U2_U2}" >>  ${fec_folder}/${TD_window}/U2_U2
        fi
    done
    
    # Applying the fec stride (additional stride)
    sed -n "0~${stride_fec}p" ${fec_folder}/${TD_window}/U1_U1 > ${fec_folder}/${TD_window}/U1_U1_stride${stride_fec}
    sed -n "0~${stride_fec}p" ${fec_folder}/${TD_window}/U1_U2 > ${fec_folder}/${TD_window}/U1_U2_stride${stride_fec}
    sed -n "0~${stride_fec}p" ${fec_folder}/${TD_window}/U2_U1 > ${fec_folder}/${TD_window}/U2_U1_stride${stride_fec}
    sed -n "0~${stride_fec}p" ${fec_folder}/${TD_window}/U2_U2 > ${fec_folder}/${TD_window}/U2_U2_stride${stride_fec}
    
    # Computing the free energy differences delta U (mainly for Mobley pymbar code)
    paste ${fec_folder}/${TD_window}/U1_U2 ${fec_folder}/${TD_window}/U2_U2 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U2-U2_U2
    paste ${fec_folder}/${TD_window}/U2_U1 ${fec_folder}/${TD_window}/U1_U1 | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U1-U1_U1
    paste ${fec_folder}/${TD_window}/U1_U2_stride${stride_fec} ${fec_folder}/${TD_window}/U2_U2_stride${stride_fec} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U1_U2-U2_U2_stride${stride_fec}
    paste ${fec_folder}/${TD_window}/U2_U1_stride${stride_fec} ${fec_folder}/${TD_window}/U1_U1_stride${stride_fec} | awk '{print $2 - $1}' > ${fec_folder}/${TD_window}/U2_U1-U1_U1_stride${stride_fec}
    
    # Preparing the C-values
    hqh_fec_prepare_cvalues.py ${c_values_min} ${c_values_max} ${c_values_count} > ${fec_folder}/${TD_window}/C-values
    
done <${ce_folder}/TD_windows.list