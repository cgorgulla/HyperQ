#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_opt_pp_one_tds.sh <original pdb filename> <psf filename> <trajectory filename> <output filename>

Has to be run in the subsystem folder."

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "4" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 4"
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
            touch runtime/${HQ_STARTDATE}/error.hq
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
HQ_VERBOSITY="$(grep -m 1 "^verbosity_runtime=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Variables
original_pdb_filename=${1}
psf_filename=${2}  # only needed for vmd
trajectory_filename=${3}
output_filename=${4}
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
opt_programs="$(grep -m 1 "^opt_programs_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
opt_continue="$(grep -m 1 "^opt_continue=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Checking if the optimization is in continuation mode
if [[ "${opt_continue^^}" == "TRUE" ]] && [[ -f ${output_filename} ]]; then
    echo -e "\n * The output file already exists and the optimization is in continuation mode. Nothing to do...\n\n"
    exit 0
fi

# Extracting the last snapshot
echo -e "\n * Preparing the extraction of the last snapshot from the trajectory file"
if [[ "${opt_programs}" == "cp2k" ]]; then

    # Checking if trajectory file exists and contains proper coordinates
    echo -n " * Checking the trajectory file... "
    if [[ -f ${trajectory_filename} ]]; then
        word_count=$(grep -m 1 "^ATOM" ${trajectory_filename} | wc -w)
        if [[ "${word_count}" -ne "9" ]] ; then
            echo "failed"
            echo" * Error: The file ${trajectory_filename} does exist but does not seem to contain data in a compatible format. Exiting..."
            exit 1
        fi
    else
        echo "failed"
        echo " * Error: The file ${trajectory_filename} does not exist. Exiting..."
        exit 1
    fi
    echo "OK"

    # Getting the last snapshot, only the atom entries
    echo -e " * Extraction of the last snapshot from the trajectory file"
    tac ${trajectory_filename} | grep -m 1 REMARK -B 1000000 | tac | grep -E "^(ATOM|HETATM)" > ${output_filename}.tmp || true
elif [[ "${opt_programs}" == "namd" ]]; then
    cc_vmd_dcd2pdb_lastframe.sh ${psf_filename} ${trajectory_filename} ${output_filename}.tmp2
    grep -E "^(ATOM|HETATM)" ${output_filename}.tmp2 > ${output_filename}.tmp
    rm ${output_filename}.tmp2
fi

# Getting the atom entries of the original file as a template
echo -e " * Preparing the template for the optimized pdb file"
grep -B 1000 -E -m 1 "^(ATOM|HETATM)" ${original_pdb_filename} | head -n -1 > ${output_filename}
# Creating a new pdb file based on the original pdb file but with the new coordinates
echo -e " * Creating a new pdb file based on the original pdb file but with the new coordinates"s
paste -d "" <(while read line; do printf "%-85s\n" "$line" | grep "^ATOM"; done < ${original_pdb_filename}) ${output_filename}.tmp | awk '{printf "%s%s%s\n", substr($0,1,30), substr($0,116,24), substr($0,55,26)}' >> ${output_filename}
echo "END" >> ${output_filename}
rm ${output_filename}.tmp

# Printing program completion information
echo -e "\n * The postprocessing of the specified TDS has been successfully completed\n\n"
