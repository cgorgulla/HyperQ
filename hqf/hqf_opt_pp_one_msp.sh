#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_opt_pp_one_msp.sh

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
echo -e "\n *** Postprocessing the optimizations (hqf_opt_pp_one_msp.sh)"

# For each folder in geopt (each k value) prepare a pdb coordinate file
for folder in opt.*; do
    bead_config=${folder/opt.k_}
    bead_count1=${bead_config/_*}
    bead_count2=${bead_config/*_}
    nbeads=$((bead_count1 + bead_count2))
    original_pdb_filename="system.a1c1.pdb"
    original_psf_filename="system1.psf"
    output_filename="system.k_${bead_count1}_${bead_count2}.opt.pdb"
    opt_programs="$(grep -m 1 "^opt_programs=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

    echo -e " * Postprocessing folder ${folder}"
    if [ "${opt_programs}" == "cp2k" ]; then
        hq_opt_pp_one_opt.sh ${original_pdb_filename} ${original_psf_filename} ${folder}/cp2k/cp2k.out.trajectory.pdb ${output_filename}
    fi
done
