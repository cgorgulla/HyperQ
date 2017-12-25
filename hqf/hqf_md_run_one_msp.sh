#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_md_run_one_msp.sh <tds_range>

<tds_range>: Possible values:
                      * all : Will cover all simulations of the MSP
                      * startindex:endindex : The index starts at 1 (w.r.t. to the MD folders present)

Has to be run in the simulation main folder."

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

# Standard error response 
error_response_std() {
    # Printing some information
    echo
    echo "An error was trapped" 1>&2
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE_BS}/error.pipeline
            exit 1
        else
            cd ..
        fi
    done

    # Printing some information
    echo "Error: Cannot find the input-files directory..."
    exit 1
}
trap 'error_response_std $LINENO' ERR SIGINT SIGTERM SIGQUIT

clean_exit() {

    echo
    echo " * Cleaning up..."

    # Terminating all processes
    echo " * Terminating remaining processes..."
    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Removing the socket files if still existent
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.* 1>/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 6
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

        # Removing the socket files if still existent (again because sometimes a few are still left)
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.* 1>/dev/null 2>&1 || true

        # Terminating the main processes
        kill ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true


        # Removing the socket files if still existent (again because sometimes a few are still left)
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.md.* 1>/dev/null 2>&1 || true

        # Terminating everything else which is still running and which was started by this script, which will include the current exit-code
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true
    " &> /dev/null || true
}
trap 'clean_exit' EXIT

# Bash options
set -o pipefail

# Config file setup
if [[ -z "${HQ_CONFIGFILE_MSP}" ]]; then

    # Printing some information
    echo " * Info: The variable HQ_CONFIGFILE_MSP was unset. Setting it to input-files/config/general.txt"

    # Setting and exporting the variable
    HQ_CONFIGFILE_MSP=input-files/config/general.txt
    export HQ_CONFIGFILE_MSP
fi

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n\n *** Starting the MD simulations (hqf_md_run_one_msp.sh) ***\n"

# Variables
tds_range="${1}"
tdcycle_msp_transformation_type="$(grep -m 1 "^tdcycle_msp_transformation_type=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
fes_md_parallel_max="$(grep -m 1 "^fes_md_parallel_max_${subsystem}=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
command_prefix_md_run_one_md="$(grep -m 1 "^command_prefix_md_run_one_md=" ../../../${HQ_CONFIGFILE_MSP} | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count_total="$(grep -m 1 "^tdw_count_total=" ../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count_total="$((tdw_count_total + 1))"

# Setting the range indices
tds_index_first=${tds_range/:*}
tds_index_last=${tds_range/*:}
if [ "${tds_index_last}" == "K" ]; then
    tds_index_last=${tds_count_total}
fi

# Checking if the range indices have valid values
if ! [ "${tds_index_first}" -le "${tds_index_first}" ]; then
    echo " * Error: The input variable tds_range was not specified correctly. Exiting..."
    exit 1
fi

# Loop for each TDS in the specified tds range
for tds_index in $(seq ${tds_index_first} ${tds_index_last}); do

    # Variables
    tdsname=tds-${tds_index}

    # Loop for allowing only the specified number of parallel runs
    while [ "$(jobs | { grep -v Done || true; } | wc -l)" -ge "${fes_md_parallel_max}" ]; do
        sleep 0.$RANDOM
    done;

    # Starting the simulation
    cd ${tdsname}/
    echo -e " * Starting the MD simulation of TDS ${tds_index}"
    ${command_prefix_md_run_one_md} hq_md_run_one_tds.sh &
    pid=$!
    pids[i]=$pid
    cd ../
    i=$((i+1))
done

# Waiting for each process separately to be able to respond to the exit code of everyone of them
for pid in ${pids[@]}; do
    wait -n
done

echo -e " * All simulations have been completed."
