#!/usr/bin/env bash 

# Usage infomation
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
    echo "Reason: The wrong number of arguments were provided when calling the script."
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
verbosity="$(grep -m 1 "^verbosity=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
fec_stride="$(grep -m 1 "^fec_stride=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Bash options
set -u

# Variables
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
system_1_basename="${msp_name/_*}"
system_2_basename="${msp_name/*_}"
date="$(date --rfc-3339=seconds | tr ": " "_")"

# Printing some information
echo -e "\n *** Postprocessing the FEC between the systems ${system_1_basename} and ${system_2_basename} ***"


# Folders
mkdir -p previous-runs/${date}/

# Extracting the final results of each TD Window
for TDWindow in m*/; do
    TDWindow=${TDWindow%/}
    cat ${TDWindow}/bar.out.stride${fec_stride}.values | grep "Delta_F equation 2:" | awk '{print $4}' | tr -d "\n"  > fec.out.delta_F.window-${TDWindow}.stride${fec_stride}
    echo " kcal/mol" >> fec.out.delta_F.window-${TDWindow}.stride${fec_stride}
    #cat ${TDWindow}/fec.out.results.all | grep "Delta_F equation 2:"| awk '{print $4}' > fec.out.delta_F.window.${TDWindow}.all

    # Copying the files and folders
    cp -r ${TDWindow} previous-runs/${date}/${TDWindow}
    cp fec.out.delta_F.window-${TDWindow}.stride${fec_stride} previous-runs/${date}/fec.out.delta_F.window-${TDWindow}.stride${fec_stride}
done

# Computing the total FE difference including all the TD windows
awk '{print $1}' fec.out.delta_F.window-*.stride${fec_stride} | paste -sd+ | bc | tr -d "\n" > fec.out.delta_F.total.stride${fec_stride}
echo " kcal/mol" >> fec.out.delta_F.total.stride${fec_stride}
cp fec.out.delta_F.total.stride${fec_stride} previous-runs/${date}/fec.out.delta_F.total.stride${fec_stride}