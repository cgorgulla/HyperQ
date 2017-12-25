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

# Config file setup
if [[ -z "${HQ_CONFIGFILE_GENERAL}" ]]; then

    # Printing some information
    echo " * Info: The variable HQ_CONFIGFILE_GENERAL was unset. Setting it to input-files/config/general.txt"

    # Setting and exporting the variable
    HQ_CONFIGFILE_GENERAL=input-files/config/general.txt
    export HQ_CONFIGFILE_GENERAL
fi

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Subjob error response (default error response)
errors_subjob_response() {

    # Printing basic error information
    echo
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the job error response. Exiting..."; exit 1' ERR

    # Checking if the error should be ignored
    if [[ "${HQ_BS_ERRORS_SUBJOB_RESPONSE}" == *"ignore"* ]]; then

        # Restoring the default error response
        trap 'errors_subjob_response $LINENO' ERR

        # Printing some information
        echo -e " * The subjob error will be ignored, and the remaining tasks are allowed to continue to run."

        # Nothing to do, continuing script execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signals responses
        trap '' 1 2 3 9 10 12 15 18 ${HQ_BS_SIGNAL_TYPE1//:/ } ${HQ_BS_SIGNAL_TYPE2//:/ } ${HQ_BS_SIGNAL_TYPE3//:/ }

        # Creating signal flag file
        touch runtime/${HQ_STARTDATE_BS}/error.subjob

        # Exiting
        exit 0
    fi
}
trap 'errors_subjob_response $LINENO' ERR

# Type 1 signal handling
signals_type1_response() {

    # Deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' 1 2 3 9 10 12 15 18 ${HQ_BS_SIGNAL_TYPE1//:/ } ${HQ_BS_SIGNAL_TYPE2//:/ } ${HQ_BS_SIGNAL_TYPE3//:/ }

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the signal response. Exiting..."; exit 1' ERR

    # Creating signal flag file
    touch runtime/${HQ_STARTDATE_BS}/signal.type1

    # Exiting
    exit 0
}
if [[ -n "${HQ_BS_SIGNAL_TYPE1}" ]]; then
    trap 'signals_type1_response' ${HQ_BS_SIGNAL_TYPE1//:/ }
fi

# Type 2 signal handling
signals_type2_response() {

    # Deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' 1 2 3 9 10 12 15 18 ${HQ_BS_SIGNAL_TYPE1//:/ } ${HQ_BS_SIGNAL_TYPE2//:/ } ${HQ_BS_SIGNAL_TYPE3//:/ }

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the signal response. Exiting..."; exit 1' ERR

    # Creating signal flag file
    touch runtime/${HQ_STARTDATE_BS}/signal.type2

    # Exiting
    exit 0
}
if [[ -n "${HQ_BS_SIGNAL_TYPE2}" ]]; then
    trap 'signals_type2_response' ${HQ_BS_SIGNAL_TYPE2//:/ }
fi

# Type 3 signal handling
signals_type3_response() {

    # Deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' 1 2 3 9 10 12 15 18 ${HQ_BS_SIGNAL_TYPE1//:/ } ${HQ_BS_SIGNAL_TYPE2//:/ } ${HQ_BS_SIGNAL_TYPE3//:/ }

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the signal response. Exiting..."; exit 1' ERR

    # Creating signal flag file
    touch runtime/${HQ_STARTDATE_BS}/signal.type3

    # Exiting
    exit 0
}
if [[ -n "${HQ_BS_SIGNAL_TYPE3}" ]]; then
    trap 'signals_type3_response' ${HQ_BS_SIGNAL_TYPE3//:/ }
fi

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
minimum_task_time=$(grep -m 1 "^minimum_task_time=" ${HQ_CONFIGFILE_MSP} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')
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
    wait -n || true
done


# Reactivating the error trap
trap 'errors_subjob_response $LINENO' ERR


# Checking the runtime
task_ending_time=$(date +%s)
if [ $((task_ending_time-task_starting_time-waiting_time)) -lt $((task_count*minimum_task_time)) ]; then
    echo -e "Error: Task finished too early. Raising a task error..."
    false
fi
