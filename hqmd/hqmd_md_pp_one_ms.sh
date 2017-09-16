#!/usr/bin/env bash 

usage="Usage: hqmd_md_pp_one_molecule.sh <subsystem>

Has to be run in the specific simulation root folder."

# Checking the input arguments
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
}
trap 'error_response_std $LINENO' ERR

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Printing information
echo -e "\n *** Postprocessing the md simulations (hqmd_md_pp_one_ms.sh)"

# Variables
subsystem="$1"
folder=md
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
md_pp_stride="$(grep -m 1 "^md_pp_stride=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

if [ "${md_pp_stride}" -ne "{md_pp_stride}" ]; then
    echo " * Warning: The variable md_pp_stride was not set in the config.txt file. Setting the value to 100."
    md_pp_stride=100
fi

if [ "${md_programs}" == "cp2k" ]; then
    echo " To implement"
elif [ "${md_programs}" == "namd" ]; then
    catdcd -o ${folder}/namd/namd.out.stride-${md_pp_stride}.dcd -s system1.opt.out.pdb -stride ${md_pp_stride} ${folder}/namd/namd.out.dcd
fi
