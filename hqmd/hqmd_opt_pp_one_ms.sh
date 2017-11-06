#!/usr/bin/env bash 

usage="Usage: hq_opt_pp_one_molecule.sh

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
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Printing information
echo -e "\n *** Postprocessing the optimizations (hqmd_opt_pp_one_ms.sh)"

# For each folder in geopt (each k value) prepare a pdb coordinate file
folder=opt
original_pdb_filename="system1.pdb"
psf_filename="system1.psf"
output_filename="system1.opt.out.pdb"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

if [ "${opt_programs}" == "cp2k" ]; then
    hq_opt_pp_one_opt.sh ${original_pdb_filename} ${psf_filename} ${folder}/cp2k/cp2k.out.trajectory.pdb ${output_filename}
elif [ "${opt_programs}" == "namd" ]; then
    hq_opt_pp_one_opt.sh ${original_pdb_filename} ${psf_filename} ${folder}/namd/namd.out.dcd ${output_filename}
fi