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
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
stride_fec="$(grep -m 1 "^stride_fec=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
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
date=$(date | tr -s ' :' '_')

# Printing some information
echo -e "\n *** Postprocessing the FEC between the systems ${system_1_basename} and ${system_2_basename} ***"


# Folders
mkdir -p previous-runs/${date}/

# Extracting the final results of each TD Window
for TDWindow in m*/; do
    TDWindow=${TDWindow%/}
    cat ${TDWindow}/bar.out.stride${stride_fec}.values | grep "Delta_F equation 2:" | awk '{print $4}' | tr -d "\n"  > fec.out.delta_F.window-${TDWindow}.stride${stride_fec}
    echo " kcal/mol" >> fec.out.delta_F.window-${TDWindow}.stride${stride_fec}
    #cat ${TDWindow}/fec.out.results.all | grep "Delta_F equation 2:"| awk '{print $4}' > fec.out.delta_F.window.${TDWindow}.all

    # Copying the files and folders
    cp -r ${TDWindow} previous-runs/${date}/${TDWindow}
    cp fec.out.delta_F.window-${TDWindow}.stride${stride_fec} previous-runs/${date}/fec.out.delta_F.window-${TDWindow}.stride${stride_fec}
done

# Computing the total FE difference including all the TD windows
awk '{print $1}' fec.out.delta_F.window-*.stride${stride_fec} | paste -sd+ | bc | tr -d "\n" > fec.out.delta_F.total.stride${stride_fec}
echo " kcal/mol" >> fec.out.delta_F.total.stride${stride_fec}
cp fec.out.delta_F.total.stride${stride_fec} previous-runs/${date}/fec.out.delta_F.total.stride${stride_fec}