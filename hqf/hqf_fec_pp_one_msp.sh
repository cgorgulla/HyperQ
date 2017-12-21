#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_pp_run_one_msp.py

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

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
system_1_basename="${msp_name/_*}"
system_2_basename="${msp_name/*_}"
fec_stride="$(grep -m 1 "^fec_stride_${subsystem}=" ../../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
date="$(date --rfc-3339=seconds | tr ": " "_")"

# Printing some information
echo -e "\n *** Postprocessing the FEC between the systems ${system_1_basename} and ${system_2_basename} ***"

# Basic files and folders
mkdir -p previous-runs/${date}/
echo -n "" > fec.out.ov

# Extracting the final results of each TD Window
tdw_index=1
for TDWindow in tds*/; do
    TDWindow=${TDWindow%/}
    cat ${TDWindow}/bar.out.stride${fec_stride}.values | grep "Delta_F equation 2:" | awk '{print $4}' | tr -d "\n"  > fec.out.delta_F.window-${TDWindow}.stride${fec_stride}
    echo " kcal/mol" >> fec.out.delta_F.window-${TDWindow}.stride${fec_stride}
    #cat ${TDWindow}/fec.out.results.all | grep "Delta_F equation 2:"| awk '{print $4}' > fec.out.delta_F.window.${TDWindow}.all

    # Copying the files and folders
    cp -r ${TDWindow} previous-runs/${date}/${TDWindow}
    cp fec.out.delta_F.window-${TDWindow}.stride${fec_stride} previous-runs/${date}/fec.out.delta_F.window-${TDWindow}.stride${fec_stride}

    # Increasing the TDW-index
    tdw_index="$((tdw_index+1))"

    # Writing information into the overview file
    echo -e "-------------------------------- TDW ${tdw_index} -------------------------------" >> fec.out.ov
    echo "Initial TDS ID: ${TDWindow/_*}" >> fec.out.ov
    echo "Final TDS ID: ${TDWindow/*_}" >> fec.out.ov
    grep -E "n_|Delta_" ${TDWindow}/bar.out.stride1.values >> fec.out.ov
done

# Computing the total FE difference including all the TD windows
awk '{print $1}' fec.out.delta_F.window-*.stride${fec_stride} | paste -sd+ | bc | tr -d "\n" > fec.out.delta_F.total.stride${fec_stride}
echo " kcal/mol" >> fec.out.delta_F.total.stride${fec_stride}
cp fec.out.delta_F.total.stride${fec_stride} previous-runs/${date}/fec.out.delta_F.total.stride${fec_stride}