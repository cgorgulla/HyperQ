#!/usr/bin/env bash

#                                                                  Printing Basic Subjob Information
####################################################################################################################################################################

echo
echo "                                                  *** Job Information ***                                                        "
echo "*********************************************************************************************************************************"
echo
echo "Environment variables"
echo "------------------------"
env
echo
echo


#                                                                           Basic Setup
####################################################################################################################################################################

# Shell options
set -m                  # Allowing each task to be in its own process group (HQ assumes that, though it will check and work around if this should not be the case)

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Standard error response
error_response_std() {

    # Printing basic error information
    echo
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo

    # Syncing the control parameters
    sync_control_parameters

    if [ "${HQ_TASK_ERROR_RESPONSE}" == "internal_error" ]; then

        # Printing some information
        echo -e " * The entire subjob will be terminated, causing an internal job error.,,"

        # Exiting
        exit 1
    else

        # Printing some information
        echo -e " * The error will be ignored, and the remaining tasks are allowed to continue to run."
    fi
}
trap 'error_response_std $LINENO' ERR

terminate_processes() {

    # Printing some information
    echo " * Terminating remaining processes..."

    # Trapping ERR and other signals to prevent errors and other traps
    trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

    # Terminating remaining background jobs
    kill $(jobs -p)

    # Terminating everything which is still running and which was started by this script
    pkill -P $$ || true

    # Terminating the entire process group
    kill -SIGTERM -$$ || true
}

# Exit trap
exit_response() {

    # Terminating remaining processes
    terminate_processes

}
trap 'exit_response' EXIT

#                                                                         Running the tasks
#####################################################################################################################################################################

# List of tasks
#task_placeholder

# Waiting for each process separately to be able to respond to the exit code of everyone of them
job_count=$(jobs | wc -l)
for pid in $(seq 1 ${job_count}); do
    wait -n
done