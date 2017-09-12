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

# Bash options
set -o pipefail

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
fec_stride="$(grep -m 1 "^fec_stride=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
temperature="$(grep -m 1 "^temperature=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
delta_F_min="$(grep -m 1 "^delta_F_min=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
delta_F_max="$(grep -m 1 "^delta_F_max=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
C_absolute_tolerance="$(grep -m 1 "^C_absolute_tolerance=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"

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
rm *.out.* >/dev/null 2>&1 || true

# Running the FEM on all the TD windows
for TDWindow in m*/; do
    cd ${TDWindow}
    rm bar.out.* >/dev/null  2>&1 || true
    #hqf_fec_run_bar.py U1_U1 U1_U2 U2_U1 U2_U2 C-values bar.out.results.all 2>&1 1> bar.out.screen.all
    hqf_fec_run_bar.py U1_U1_stride${fec_stride} U1_U2_stride${fec_stride} U2_U1_stride${fec_stride} U2_U2_stride${fec_stride} ${delta_F_min} ${delta_F_max} bar.out.stride${fec_stride} ${temperature} ${C_absolute_tolerance}
    cd ..
done