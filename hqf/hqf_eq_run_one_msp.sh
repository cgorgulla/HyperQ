#!/usr/bin/env bash

# Usage information
usage="Usage: hqf_eq_run_one_msp.sh <tds_range>

Arguments:
    <tds_range>: Range of the thermodynamic states
      * Format: startindex:endindex
      * The index starts at 1
      * The capital letter K can be used to indicate the end state of the thermodynamic path

Has to be run in the subsystem folder."

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
            touch runtime/${HQ_BS_STARTDATE}/error.hq
            exit 1
        else
            cd ..
        fi
    done

    # Printing some information
    echo "Error: Cannot find the input-files directory..."
    exit 1
}
trap 'error_response_std $LINENO' ERR SIGINT SIGQUIT SIGTERM

# Exit cleanup
cleanup_exit() {

    echo
    echo " * Cleaning up..."

    # Terminating all processes
    echo " * Terminating remaining processes..."
    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Terminating the main processes
        kill ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 6 || true
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1 || true
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

        # Terminating everything else which is still running and which was started by this script, which will include the current exit-code
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true
    " &> /dev/null || true
}
trap "cleanup_exit" EXIT


# Bash options
set -o pipefail

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity_runtime=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Checking the version of BASH, we need at least 4.3 (wait -n)
bash_version=${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}
if [ ${bash_version} -lt 43 ]; then
    # Printing some information
    echo
    echo "Error: The Bash version seems to be too old. At least version 4.3 is required."
    echo "Exiting..."
    echo
    echo
    exit 1
fi

# Printing some information
echo -e "\n *** Running the geometry equilibrations ${1}(hq_eq_run_one_msp.sh)"

# Variables
tds_range="${1}"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
fes_eq_parallel_max="$(grep -m 1 "^fes_eq_parallel_max_${subsystem}" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
eq_programs="$(grep -m 1 "^eq_programs_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
command_prefix_eq_run_one_eq="$(grep -m 1 "^command_prefix_eq_run_one_eq=" ../../../input-files/config.txt | awk -F '[=#]' '{print $2}')"
tdcycle_type="$(grep -m 1 "^tdcycle_type=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
tdw_count="$(grep -m 1 "^tdw_count="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads="  ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count="$((tdw_count + 1))"


# Checking if the variables nbeads and tdw_count are compatible
if [ "${tdcycle_type}" == "hq" ]; then
    echo -e -n " * Checking if the variables <nbeads> and <tdw_count> are compatible... "
    trap '' ERR
    mod="$(expr ${nbeads} % ${tdw_count})"
    trap 'error_response_std $LINENO' ERR
    if [ "${mod}" != "0" ]; then
        echo "Check failed"
        echo " * The variables <nbeads> and <tdw_count> are not compatible. <nbeads> has to be divisible by <tdw_count>."
        exit 1
    fi
    echo " OK"
fi

# Setting the range indices
tds_index_first=${tds_range/:*}
tds_index_last=${tds_range/*:}
if [ "${tds_index_last}" == "K" ]; then
    tds_index_last=${tds_count}
fi

# Loop for each equilibration in the specified tds range
for tds_index in $(seq ${tds_index_first} ${tds_index_last}); do

    # Determining the eq folder
    if [ "${tdcycle_type}" == "hq" ]; then

        # Variables
        bead_step_size=$(expr $nbeads / $tdw_count)
        bead_count1="$(( nbeads - (tds_index-1)*bead_step_size))"
        bead_count2="$(( (tds_index-1)*bead_step_size))"
        bead_configuration="k_${bead_count1}_${bead_count2}"
        tds_folder=tds.${bead_configuration}

    elif [ "${tdcycle_type}" == "lambda" ]; then

        # Variables
        lambda_current=$(echo "$((tds_index-1))/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        lambda_configuration=lambda_${lambda_current}
        tds_folder=tds.${lambda_configuration}
    fi

    # Loop for allowing only the specified number of parallel runs
    while [ "$(jobs | wc -l)" -ge "${fes_eq_parallel_max}" ]; do
        sleep 1;
    done;

    # Starting the equilibration
    cd ${tds_folder}
    echo -e " * Starting the equilibration ${tds_folder}"
    ${command_prefix_eq_run_one_eq} hqf_eq_run_one_tds.sh &
    pids[i]=$!
    tds_index=$((tds_index+1))
    cd ..
done

# Waiting for each process separately to be able to respond to the exit code of everyone of them
for pid in ${pids[@]}; do
    wait -n
done

# Printing script completion information
echo -e "\n * The equilibration runs of all the specified TDSs (${tds_range}) of this MSP (${msp_name}) have been completed.\n\n"