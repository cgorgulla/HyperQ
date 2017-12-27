#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_fec_pp_one_msp.sh

The script has to be run in fec folder of the system."

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
    echo "Expected arguments: 0"
    echo "Provided arguments: ${#}"
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

# Config file setup
if [[ -z "${HQ_CONFIGFILE_MSP}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_MSP was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_MSP=input-files/config/general.txt
    export HQ_CONFIGFILE_MSP
fi

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
system_1_basename="${msp_name/_*}"
system_2_basename="${msp_name/*_}"
fec_stride="$(grep -m 1 "^fec_stride_${subsystem}=" ../../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
date="$(date --rfc-3339=seconds | tr ": " "_")"

# Printing some information
echo -e "\n\n *** Postprocessing the FEC of MSP ${msp_name} ***\n"

# Basic files and folders
mkdir -p previous-runs/${date}/
echo -n "" > fec.out.ov

# Extracting the final results of each TD Window
tdw_index=1
for TDWindow in tds*/; do

    # Variables
    TDWindow=${TDWindow%/}
    tds_1="${TDWindow/_*}"
    tds_1_id="${tds_1/tds-}"
    tds_2="${TDWindow/*_}"
    tds_2_id="${tds_2/tds-}"

    # Creating the short results output file
    cat ${TDWindow}/bar.out.stride${fec_stride}.values | grep "Delta_F equation 2:" | awk '{print $4}' | tr -d "\n"  > fec.out.delta_F.window-${TDWindow}.stride${fec_stride}
    echo " kcal/mol" >> fec.out.delta_F.window-${TDWindow}.stride${fec_stride}

    # Writing information into the general overview file
    if [ "${tdw_index}" == "1" ]; then
        echo -e "--------------------------------------------- General --------------------------------------------" >> fec.out.ov
        echo "" >> fec.out.ov
        grep -E "C_min" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
        grep -E "C_max" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
        grep -E "tolerance" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
        grep -E "F_min" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
        grep -E "F_max" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
        grep -E "Temp" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
        grep -E "Reweighting" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
        echo "" >> fec.out.ov
        echo "Total free energy difference over all TDWs: " >> fec.out.ov
        echo "" >> fec.out.ov
        echo "" >> fec.out.ov
    fi
    echo -e "---------------------------------------------- TDW ${tdw_index} ---------------------------------------------" >> fec.out.ov
    echo "" >> fec.out.ov
    echo "Initial TDS ID: ${tds_1_id}" >> fec.out.ov
    echo "Final TDS ID: ${tds_2_id}" >> fec.out.ov
    grep -E "n_|Delta_" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
    echo "" >> fec.out.ov
    echo "" >> fec.out.ov

    # Increasing the TDW-index
    tdw_index="$((tdw_index+1))"
done

# Computing the total FE difference involving all the TD windows and writing the information to files
total_FE_difference="$(awk '{print $1}' fec.out.delta_F.window-*.stride${fec_stride} | xargs printf "%.5f+" | sed "s/+$/\n/"  | bc -l) kcal/mol"         # bc -l requires a new line at the end
echo "${total_FE_difference}" > fec.out.delta_F.total.stride${fec_stride}
sed -i "s|all TDWs: |all TDWs: ${total_FE_difference}|g" fec.out.ov

# Copying all the files and folders to the backup/history folder
cp -r tds* previous-runs/${date}/
cp fec.out.* previous-runs/${date}/
