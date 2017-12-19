#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_ce_run_one_msp.sh

Has to be run in the subsystem folder."

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
    echo "Reason: The wrong number of arguments was provided when calling the script."
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
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder (during an error we could have been in a different folder than the starting WD)
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

trap 'error_response_std $LINENO' ERR SIGINT SIGQUIT SIGTERM

clean_up() {

    # Printing some information
    echo
    echo " * Cleaning up..."

    # Removing remaining empty folders if there should some (ideally not)
    sleep 3
    find ./ -empty -delete

    # Terminating all remaining processes.
    echo " * Terminating all remaining processes..."

    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Removing the socket files if still existent
        rm /tmp/ipi_${workflow_id}.${HQ_STARTDATE_ONEPIPE}.ce.* >/dev/null 2>&1 || true
        # Removing remaining empty folders if there should some (ideally not)
        find ./ -empty -delete

        # Terminating everything which is still running and which was started by this script, which will also terminite the current exit code
        # We are not killing all processes individually because it might be thousands and the pids might have been recycled in the meantime
        pkill -9 -P $$ || true &
        sleep 1
        pkill -9 -P $$ || true &
    " &> /dev/null || true
}
trap 'clean_up' EXIT

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n *** Starting the cross evaluations (hqf_ce_run_one_msp.sh) ***"

# Variables
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
system_name="$(pwd | awk -F '/' '{print     $(NF-1)}')"
fes_ce_parallel_max="$(grep -m 1 "^fes_ce_parallel_max_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ce_continue="$(grep -m 1 "^ce_continue=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_type="$(grep -m 1 "^tdcycle_type=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
workflow_id="$(grep -m 1 "^workflow_id=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
command_prefix_ce_run_one_snapshot="$(grep -m 1 "^command_prefix_ce_run_one_snapshot=" ../../../input-files/config.txt | awk -F '[=#]' '{print $2}')"

# Getting the energy eval folders
if [ "${tdcycle_type}" == "hq" ]; then
    crosseval_folders="$(ls -vrd tds*-*/)"
elif [ "${tdcycle_type}" == "lambda" ]; then
    crosseval_folders="$(ls -vd tds*-*/)"
fi
crosseval_folders=${crosseval_folders//\/}

# Running the MD simulations
i=0
for crosseval_folder in ${crosseval_folders}; do

    cd ${crosseval_folder}
    echo -e "\n ** Running the cross evaluations of folder ${crosseval_folder}"

    # Testing whether at least one snapshot exists at all
    if stat -t snapshot* >/dev/null 2>&1; then
        for snapshot_folder in $(ls -v | grep snapshot); do

            # Checking if the workflow is run by the BS module
            if [ -n "${HQ_BS_JOBNAME}" ]; then

                # Determining the control file responsible for us
                cd ../../../../
                controlfile="$(hqh_bs_controlfile_determine.sh ${HQ_BS_JTL} ${HQ_BS_JID} || true)"
                echo ${controlfile}

                # Getting the relevant value
                terminate_current_job="$(hqh_gen_inputfile_getvalue.sh ${controlfile} terminate_current_job true || true)"
                echo ${terminate_current_job}
                cd -

                # Checking the value
                if [ "${terminate_current_job^^}" == "TRUE" ]; then

                    # Printing some information
                    echo " * According to the controlfile ${controlfile} the current batchsystem job should be terminated immediately. Stopping this simulation and exiting..."

                    # Exiting
                    exit 0
                fi
            fi

            # Checking if the snapshot was computed already
            if [ "${ce_continue^^}" == "TRUE" ]; then

                # Variables
                restart_ID=${snapshot_folder/*-}

                # Checking if the snapshot has already been completed successfully
                if energy_line_old="$(grep "^ ${restart_ID}" ce_potential_energies.txt &> /dev/null)"; then

                    # Printing some information
                    echo -e " * Info: There is already an entry in the common energy file for this snapshot: ${energy_line_old}"

                    # Checking if the entry contains two words
                    if [ "$(echo ${energy_line_old} | wc -w)" == "2" ]; then

                        # Printing some information
                        echo -e " * Info: This entry does seem to be valid. Removing the existing folder and continuing with next snapshot..."

                        # Removing the folder
                        rm -r snapshot-${restart_ID} 1> /dev/null || true

                        # Skipping the snapshot
                        continue
                    else

                        # Printing some information
                        echo -e " * Info: This entry does seem to be invalid. Removing this entry from the common energy file and continuing with next snapshot..."
                        sed -i "/^ ${restart_ID} /d" ce_potential_energies.txt
                    fi
                fi
            fi

            # Loop for allowing only the specified number of parallel runs
            while [ "$(jobs | wc -l)" -ge "${fes_ce_parallel_max}" ]; do
                jobs
                echo -e " * Waiting for a free slot to start the cross evaluation of snapshot ${snapshot_folder/*-} of folder ${crosseval_folder} (hqf_ce_run_one_msp.sh)"
                sleep 1.$RANDOM
                echo
            done;

            # Starting the cross evaluation
            sleep 0.$RANDOM
            cd ${snapshot_folder}/
            echo -e "\n * Running the cross evaluation of snapshot ${snapshot_folder/*-}"
            trap '' ERR
            ${command_prefix_ce_run_one_snapshot} hqf_ce_run_one_snapshot.sh &
            pid=$!
            pids[i]=$pid
            trap 'error_response_std $LINENO' ERR
            i=$((i+1))
            cd ..

            # Removing empty remaining folders if there should some (ideally not)
            find ${snapshot_folder} -empty -delete

        done
    else
        echo -e " * Warning: No snapshots found in folder ${crosseval_folder}, skipping."
    fi

    cd ../
done

wait

echo -e " * All cross evaluations have been completed"
