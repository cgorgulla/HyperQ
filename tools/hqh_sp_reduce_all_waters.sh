#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_reduce_all_waters.sh <subsystem>

Should be run in the root folder.
Possible subsystems are: L, LS, PLS."

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
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "1" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 1"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Variables
script_dir=$(dirname ${0})
subsystem=${1}

# Finding the minimum water number
i=0
for folder in input-files/systems/*; do
    waterCount[i]=$(grep "^ATOM" ${folder}/${subsystem}/system_complete.pdb | grep " OH2 " | wc -l)
    i=$((i+=1))
done
minimumWaterCount=${waterCount[0]}
for i in ${waterCount[@]}; do
    if [[ ${i} -lt ${minimumWaterCount} ]]; then
        minimumWaterCount="${i}"
    fi
done

for folder in $(ls input-files/systems); do
    if [ "${minimumWaterCount}" -eq "0" ]; then
        echo -e " * Minimum water count is 0. No water to reduce...\n"
        cp input-files/systems/${folder}/${subsystem}/system_complete.pdb input-files/systems/${folder}/${subsystem}/system_complete.reduced.pdb
        cp input-files/systems/${folder}/${subsystem}/system_complete.psf input-files/systems/${folder}/${subsystem}/system_complete.reduced.psf
    else
        # Reducing the number of water molecules in all the systems (which remained)
        cd input-files/systems/${folder}/${subsystem}/
            vmdc ${script_dir}/hq_sp_reduce_waters.vmd -args system_complete ${minimumWaterCount}
        cd ../../../..
    fi
done
