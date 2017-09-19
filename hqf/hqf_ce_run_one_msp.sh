#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_ce_run_one_msp.sh

Has to be run in the simulation main folder."

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
    exit 1
}
trap 'error_response_std $LINENO' ERR

clean_up() {

    echo
    echo " * Cleaning up..."

    # Terminating processes.
    echo " * Terminating remaining processes..."..
    # Terminating everything which is still running and which was started by this script
    # We are not killing all processes individually because it might be thousands and the pids might have been recycled in the meantime
    pkill -P $$ || true
    sleep 5
    pkill -9 -P $$ || true
}
trap 'clean_up' EXIT

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n *** Starting the cross evalutations (hqf_ce_run_one_msp.sh) ***"

# Variables
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"
fes_ce_parallel_max="$(grep -m 1 "^fes_ce_parallel_max_${subsystem}=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"
ce_continue="$(grep -m 1 "^ce_continue=" ../../../input-files/config.txt | awk -F '=' '{print $2}')"

# Running the md simulations
i=0
for energyeval_folder in $(ls -d */); do
    energyeval_folder=${energyeval_folder/\/}
    cd ${energyeval_folder}
    echo -e "\n ** Running the cross evaluations of folder ${energyeval_folder}"

    # Testing whether at least one snapshot exists at all
    if stat -t snapshot* >/dev/null 2>&1; then
        for snapshot_folder in snapshot*; do
            # Checking if the snapshot was computed already
            if [ "${ce_continue^^}" == "TRUE" ]; then
                if [ -f ${snapshot_folder}/ipi/ipi.out.properties ]; then
                    propertylines_word_count=$(grep "^ *[0-9]" ${snapshot_folder}/ipi/ipi.out.properties | wc -w)
                    if [ "${propertylines_word_count}" -ge "3" ]; then
                         echo " * The snapshot ${snapshot_folder/*-} has been computed already, skipping."
                         continue
                    fi
                fi
            fi
            while [ "$(jobs | wc -l)" -ge "${fes_ce_parallel_max}" ]; do
                jobs
                echo -e " * Waiting for a free slot to start cross evaluation of snapshot ${snapshot_folder/*-} of folder ${energyeval_folder} (hqf_ce_run_one_msp.sh)"
                sleep 1.$RANDOM
                echo
            done;
            sleep 0.$RANDOM
            cd ${snapshot_folder}/
            echo -e "\n * Running the cross evaluation of snaphot ${snapshot_folder/*-}"
            trap '' ERR
            hqf_ce_run_one_snapshot.sh &
            pid=$!
            pids[i]=$pid
            trap 'error_response_std $LINENO' ERR
            echo "${pid} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/ce
            i=$((i+1))
            cd ..
        done
    else
        echo -e " * Warning: No snapshots found in folder ${energyeval_folder}, skipping."
    fi

    cd ../
done

wait

echo -e " * All cross evaluations have been completed"
