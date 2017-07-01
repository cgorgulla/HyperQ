#!/usr/bin/env bash 

usage="Usage: hq_md_pp_one_molecule.sh

Has to be run in the specific simulation root folder."

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

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Printing information
echo -e "\n *** Postprocessing the md simulations (hqmd_md_pp_one_ms.sh)"

# Variables
folder=md
md_programs="$(grep -m 1 "^md_programs=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
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
