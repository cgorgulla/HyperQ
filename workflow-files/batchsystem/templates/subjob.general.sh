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

    if [ "${HQ_TASK_ERROR_RESPONSE}" == "internal_error" ]; then

        # Printing some information
        echo -e " * The entire subjob will be terminated with exit code 1."

        # Exiting, exit code propagation is not ensured due to the subjob command (therefore we have our internal error handling backup mechanism in HQ)
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
    kill $(jobs -p) || true

    # Terminating everything which is still running and which was started by this script
    pkill -P $$ || true

    # Sleeping some time to give the processes time to terminate nicely
    sleep 10
}

# Exit trap
exit_response() {

    # Terminating remaining processes
    terminate_processes
}
trap 'exit_response' EXIT

#                                                                         Running the tasks
#####################################################################################################################################################################
echo
echo
echo "                                                    *** Task Output ***                                                          "
echo "*********************************************************************************************************************************"
echo

# Variables
task_starting_time=$(date +%s)
minimum_task_time=$(grep -m 1 "^minimum_task_time=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')
waiting_time=0
task_count=0


# Deactivating the error trap
trap '' ERR

# List of tasks
#task_placeholder



# Waiting for each process separately to be able to respond to the exit code of everyone of them (only needed for the parallel tasks mode, but does not interfere with the serial mode)
# We could use a simple wait as well due to the recent change that tasks always produce exit code 0, as we are capturing HQ errors with our own file-based error report mechanism
job_count=$(jobs | wc -l)
for pid in $(seq 1 ${job_count}); do
    wait -n
done


# Reactivating the error trap
trap 'error_response_std $LINENO' ERR


# Checking the runtime
task_ending_time=$(date +%s)
if [ $((task_ending_time-task_starting_time-waiting_time)) -lt $((task_count*minimum_task_time)) ]; then
    echo -e "Error: Task finished too early. Raising a task error..."
    false
fi
