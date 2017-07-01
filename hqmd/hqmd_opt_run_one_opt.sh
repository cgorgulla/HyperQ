#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqmd_opt_run_one_opt.sh

Has to be run in the opt root folder of the system."

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

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
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
set -o pipefail

# Exit cleanup
cleanup_exit() {
    # Stopping orphaned processes (e.g. hanging cp2k)
    kill 0 1>/dev/null 2>&1 || true
}
trap "cleanup_exit" EXIT

# Variables
opt_programs=$(grep -m 1 "^opt_programs=" ../../../input-files/config.txt | awk -F '=' '{print $2}')
opt_timeout=$(grep -m 1 "^opt_timeout=" ../../../input-files/config.txt | awk -F '=' '{print $2}')

# Running the optimization
# CP2K
if [[ "${opt_programs}" == "cp2k" ]] ;then
    cd opt/cp2k
    # Cleaning the folder
    rm cp2k.out* 1>/dev/null 2>&1 || true
    rm system*  1>/dev/null 2>&1 || true
    ncpus_cp2k_opt="$(grep -m 1 "^ncpus_cp2k_opt=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp2k -e cp2k.in.opt > cp2k.out.config
    export OMP_NUM_THREADS=${ncpus_cp2k_opt}
    # timeout ${opt_timeout} cp2k -i cp2k.in.opt -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
    cp2k -i cp2k.in.opt -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &

    # Checking if the file system-r-1.out does already exist.
    while [ ! -f cp2k.out.general ]; do
        echo " * The file system.out.general does not exist yet. Waiting..."
        sleep 1
    done
    echo " * The file system.out.general detected. Continuing..."
    cd ../..

elif [[ "${opt_programs}" == *"namd"* ]]; then
    cd opt/namd
    # Cleaning the folder
    rm namd.out* 1>/dev/null 2>&1 || true
    rm system*  1>/dev/null 2>&1 || true
    # ncpus_namd_opt="$(grep -m 1 "^ncpus_namd_md=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    namd_command="$(grep -m 1 "^namd_command=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    ${namd_command} namd.in.opt > namd.out.screen 2>namd.out.err & # removed +idlepoll +p${ncpus_namd_md}
    cd ../..
fi

wait
