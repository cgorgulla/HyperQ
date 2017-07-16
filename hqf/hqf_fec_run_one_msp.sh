#!/usr/bin/env bash

# Usage infomation
usage="Usage: hqf_fec_run_one_fes.py

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
    echo "Number of expected arguments: 0"
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

# Bash options
set -u
#set -xeuo pipefail

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
stride_fec="$(grep -m 1 "^stride_fec=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
temperature="$(grep -m 1 "^temperature=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
system_1_basename="${msp_name/_*}"
system_2_basename="${msp_name/*_}"

# Printing some information
echo -e "\n *** Running the FEC between the systems ${system_1_basename} and ${system_2_basename} ***"

# Tyding up
rm fec.out.* >/dev/null 2>&1 || true

# Running the FEM on all the TD windows
for TDWindow in */; do
    cd ${TDWindow}
    rm bar.out.* >/dev/null  2>&1 || true
    #hqf_fec_run_bar.py U1_U1 U1_U2 U2_U1 U2_U2 C-values bar.out.results.all 2>&1 1> bar.out.screen.all
    hqf_fec_run_bar.py U1_U1_stride${stride_fec} U1_U2_stride${stride_fec} U2_U1_stride${stride_fec} U2_U2_stride${stride_fec} C-values ${temperature} bar.out.stride${stride_fec} # bar.out.screen.stride${stride_fec}
    cd ..
done