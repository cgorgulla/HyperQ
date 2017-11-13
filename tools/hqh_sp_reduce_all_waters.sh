#!/usr/bin/env bash 

# Usage information
usage="Usage: hqh_sp_reduce_all_waters.sh <subsystem>

Should be run in the root folder.
Possible subsystems are: L, LS, RLS."

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
            touch runtime/${HQ_STARTDATE}/error
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
if [ "${HQ_VERBOSITY}" = "debug" ]; then
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
    echo "Reason: The wrong number of arguments was provided when calling the script."
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
set +o pipefail # not used because if no water the pipe would file
i=0
for folder in $(find input-files/systems/ -type d -name ${subsystem}); do
    water_count[i]=$(grep "^ATOM" ${folder}/system_complete.pdb | grep " OH2 " | wc -l)
    i=$((i+=1))
done
set -o pipefail # not used because if no water the pipe would file

minimum_water_count=${water_count[0]}
for i in ${water_count[@]}; do
    if [[ ${i} -lt ${minimum_water_count} ]]; then
        minimum_water_count="${i}"
    fi
done

for folder in $(find input-files/systems/ -type d -name ${subsystem}); do
    if [ "${minimum_water_count}" -eq "0" ]; then
        echo -e " * Minimum water count is 0. No water to reduce...\n"
        cp input-files/systems/${folder}/${subsystem}/system_complete.pdb ${folder}/system_complete.reduced.pdb
        cp input-files/systems/${folder}/${subsystem}/system_complete.psf ${folder}/system_complete.reduced.psf
    else
        # Reducing the number of water molecules in all the systems (which remained)
        cd ${folder}
            vmdc ${script_dir}/hqh_sp_reduce_waters.vmd -args system_complete ${minimum_water_count}
        cd ../../../..
    fi
done
