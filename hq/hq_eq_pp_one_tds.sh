#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_eq_pp_one_tds.sh <original pdb filename> <psf filename> <trajectory filename> <output filename>

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

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
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

# Bash options
set -o pipefail

# Variables
original_pdb_filename=${1}
psf_filename=${2}  # only needed for vmd
trajectory_filename=${3}
output_filename=${4}
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
eq_programs="$(grep -m 1 "^eq_programs_${subsystem}=" ../../../input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"
eq_continue="$(grep -m 1 "^eq_continue=" ../../../input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

# Checking if the equilibration is in continuation mode
if [[ "${eq_continue^^}" == "TRUE" ]] && [[ -f ${output_filename} ]]; then
    echo -e "\n * The output file already exists and the equilibration is in continuation mode. Nothing to do...\n\n"
    exit 0
fi

# Extracting the last snapshot
echo -e "\n * Preparing the extraction of the last snapshot from the trajectory file"
if [[ "${eq_programs}" == "cp2k" ]]; then

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
elif [[ "${eq_programs}" == "namd" ]]; then
    cc_vmd_dcd2pdb_lastframe.sh ${psf_filename} ${trajectory_filename} ${output_filename}.tmp2
    grep -E "^(ATOM|HETATM)" ${output_filename}.tmp2 > ${output_filename}.tmp
    rm ${output_filename}.tmp2
fi

# Getting the atom entries of the original file as a template
echo -e " * Creating a new pdb file with the equilibrated coordinates based on the original pdb file."
echo "TITLE positions{angstrom} cell{angstrom}" > ${output_filename}
tac ${trajectory_filename} | grep -m 1 REMARK -B 1000000 | tac | grep -m 1 "^CRYST1" >> ${output_filename} || true
paste -d "" <(while read line; do printf "%-85s\n" "$line" | grep "^ATOM"; done < ${original_pdb_filename}) ${output_filename}.tmp | awk '{printf "%s%s%s\n", substr($0,1,30), substr($0,116,24), substr($0,55,26)}' >> ${output_filename}
echo "END" >> ${output_filename}
# Ceiling the box size to the next 0.1 Angstrom unit (CP2K made problems one time when the box was too tight)
cryst_line="$(grep "^CRYST" ${output_filename})"
size_x_old=$(echo ${cryst_line:6:9} | tr -d "[[:space:]]")
size_y_old=$(echo ${cryst_line:15:9} | tr -d "[[:space:]]")
size_z_old=$(echo ${cryst_line:24:9} | tr -d "[[:space:]]")
size_x_new=$(awk -v x="${size_x_old}" 'BEGIN{printf("%9.1f", x+0.1)}')
size_y_new=$(awk -v y="${size_y_old}" 'BEGIN{printf("%9.1f", y+0.1)}')
size_z_new=$(awk -v z="${size_z_old}" 'BEGIN{printf("%9.1f", z+0.1)}')
cryst_line_new="$(printf "CRYST1%9.3f%9.3f%9.3f%7.2f%7.2f%7.2f P 1           1" ${size_x_new} ${size_y_new} ${size_z_new} 90 90 90)"
sed -i "s/CRYST.*/${cryst_line_new}/" ${output_filename}
rm ${output_filename}.tmp

# Printing some information
echo -e "\n * The postprocessing of the specified TDS has been successfully completed\n\n"
