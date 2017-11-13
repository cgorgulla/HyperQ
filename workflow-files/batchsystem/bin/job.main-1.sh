#!/usr/bin/env bash


### Basic setup ###

# Printing some information
echo
echo "                                                      *** Job Output ***                                                         "
echo "*********************************************************************************************************************************"
echo

# Shell options
shopt -s nullglob       # Required for our code

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity_runtime=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Basic variables
starting_time="$(date)"
start_time_seconds="$(date +%s)"
export HQ_STARTDATE="$(date +%Y%m%d%m%S-%N)"
batchsystem="$(grep -m 1 "^batchsystem=" input-files/config.txt| awk -F '=' '{print tolower($2)}' | tr -d '[:space:]')"

# Creating the runtime error
mkdir -p runtime/${HQ_STARTDATE}

# Checking the version of BASH, we need at least 4.3 (wait -n)
bash_version=${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}
if [ ${bash_version} -lt 43 ]; then
    # Printing some information
    echo
    echo "Error: BASH version seems to be too old. At least version 4.3 is required."
    echo "Exiting..."
    echo
    echo
    exit 1
fi


### Functions ###

# Determining the control file
determine_control_file() {

    # Variables
    controlfile=""

    # Loop for each file of priority 1 (highest priority)
    for file in batchsystem/control/*-*:*-*.ctrl; do

        # Variables
        file_basename=$(basename $file)
        jtl_range=$(echo ${file_basename} | awk -F '[:.]' '{print $1}')
        jtl_range_start=${jtl_range/-*}
        jtl_range_end=${jtl_range/*-}
        jid_range=$(echo ${file_basename} | awk -F '[:.]' '{print $2}')
        jid_range_start=${jid_range/-*}
        jid_range_end=${jid_range/*-}

        # Checking if the jtl range values are valid using Base36 to compare the characters
        if ! [ "$((36#${jtl_range_start}))" -le "$((36#${jtl_range_end}))" ]; then

            # The filename seems to be of an invalid format
            echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..."
            continue
        fi

        # Checking if the jid range values are valid
        if ! [ "${jid_range_start}" -le "${jid_range_end}" ]; then

            # The file seems to be of an invalid format
            echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..."
            continue
        fi

        # Checking if our jid is contained in the specified jid range of the file
        if [[ "${jid_range_start}" -le "${HQ_JID}" && "${HQ_JID}" -le "${jid_range_end}" ]]; then

            # Checking if our jtl is contained in the specified jtl range of the file
            if [[ "$((36#${jtl_range_start}))" -le "$((36#${HQ_JTL}))" && "$((36#${HQ_JTL}))" -le "$((36#${jtl_range_end}))" ]]; then

                # Setting the control file
                controlfile=${file}

                # We are all set
                return
            fi
        fi
    done

    # Loop for each file of priority 2
    for file in batchsystem/control/all:*-*.ctrl; do

        # Variables
        file_basename=$(basename $file)
        jid_range=$(echo ${file_basename} | awk -F '[:.]' '{print $2}')
        jid_range_start=${jid_range/-*}
        jid_range_end=${jid_range/*-}

        # Checking if the jid range values are valid
        if ! [ "${jid_range_start}" -le "${jid_range_end}" ]; then

            # The file seems to be of an invalid format
            echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..."
            continue
        fi

        # Checking if our jid is contained in the specified jid range of the file
        if [[ "${jid_range_start}" -le "${HQ_JID}" && "${HQ_JID}" -le "${jid_range_end}" ]]; then

            # Setting the control file
            controlfile=${file}

            # We are all set
            return
        fi
    done

    # Loop for each file of priority 3
    for file in batchsystem/control/*-*.all.ctrl; do

        # Variables
        file_basename=$(basename $file)
        jtl_range=$(echo ${file_basename} | awk -F '[:.]' '{print $1}')
        jtl_range_start=${jtl_range/-*}
        jtl_range_end=${jtl_range/*-}

        # Checking if the jtl range values are valid using Base36 to compare the characters
        if ! [ "$((36#${jtl_range_start}))" -le "$((36#${jtl_range_end}))" ]; then

            # The filename seems to be of an invalid format
            echo "Warning: The control file $file seems to have an unsupported filename. Ignoring this file..."
            continue
        fi

        # Checking if our jtl is contained in the specified jtl range of the file
        if [[ "$((36#${jtl_range_start}))" -le "$((36#${HQ_JTL}))" && "$((36#${HQ_JTL}))" -le "$((36#${jtl_range_end}))" ]]; then

            # Setting the control file
            controlfile=${file}

            # We are all set
            return
        fi
    done

    # If we have still not found any control file, then the general all:all.ctrl file is responsible for us
    # Checking if it is there
    if [ -f batchsystem/control/all:all.ctrl ]; then
        controlfile="batchsystem/control/all:all.ctrl"
    else

        # Printing some information before exiting...
        echo -e "Error: No control file could be found. Exiting...\n\n"
        exit 1
    fi
}

# Syncing control variables
sync_control_parameters() {

    # Determining the control file responsible for us
    determine_control_file

    # Getting the control parameters
    job_success_actions="$(grep -m 1 "^job_success_actions=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    prevent_new_job_submissions="$(grep -m 1 "^prevent_new_job_submissions=" ${controlfile} | awk -F '=' '{print tolower($2)}' | tr -d '[:space:]')"
    signals_type1="$(grep -m 1 "^signals_type1=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type2="$(grep -m 1 "^signals_type2=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type3="$(grep -m 1 "^signals_type3=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type1_response="$(grep -m 1 "^signals_type1_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type2_response="$(grep -m 1 "^signals_type2_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type3_response="$(grep -m 1 "^signals_type3_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    internal_error_response="$(grep -m 1 "^internal_error_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    HQ_TASK_ERROR_RESPONSE="$(grep -m 1 "^task_error_response=" ${controlfile} | awk -F '=' '{print tolower($2)}' | tr -d '[:space:]')"
    internal_error_new_job_jtl="$(grep -m 1 "^internal_error_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type1_new_job_jtl="$(grep -m 1 "^signals_type1_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type2_new_job_jtl="$(grep -m 1 "^signals_type2_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type3_new_job_jtl="$(grep -m 1 "^signals_type3_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    job_success_new_job_jtl="$(grep -m 1 "^job_success_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

    # Exporting relevant parameters
    export HQ_TASK_ERROR_RESPONSE

    # Checking and adjusting the new job type letters
    for jtl_name in internal_error_new_job_jtl signals_type1_new_job_jtl signals_type2_new_job_jtl signals_type3_new_job_jtl job_success_new_job_jtl; do

        # Variables
        jtl_value=${!jtl_name}                              # indirect variable expansion

        # Checking the type of the value and if the value is valid
        if [[ "${jtl_value}" =~ ^[abcdefghij]$ ]]; then

            # Nothing to do, but the value is valid
            :
        elif [[ "${jtl_value}" == "same" ]]; then

            # Setting the new jtl
            eval ${jtl_name}=${HQ_JTL}
        elif [[ "${jtl_value}" == "next" ]]; then

            # Increasing the new jtl to the next letter in the alphabet
            eval ${jtl_name}=$(echo ${HQ_JTL} | tr abcdefghi 012345678 | awk '{print $1+1}' | tr 0123456789 abcdefghij)              #$((36#${HQ_JTL}-9))    https://stackoverflow.com/questions/27489170/assign-number-value-to-alphabet-in-shell-bash
        else

            # Printing some error message before exiting
            echo -e "\n * Error: The input argument '${jtl_name}' has an unsupported value (${jtl_value}). Exiting...\n\n"
            exit 1
        fi
    done
}


# Preparing the new jobfile
prepare_new_job() {

    # Variables
    new_job_jtl=${1}

    # Updating the job file
    hqh_bs_jobfile_increase_jsn.sh ${new_job_jtl} ${HQ_JID}
}


# Start new job
submit_new_job() {

    # Variables
    new_job_jtl=${1}

    # Checking if the next job should really be submitted
    if [[ "${prevent_new_job_submissions}" == "false" ]]; then

        # Checking how much time has passed since the job has been started
        end_time_seconds="$(date +%s)"
        time_diff="$((end_time_seconds - start_time_seconds))"
        time_difference_threshold=60
        if [ "${time_diff}" -le "${time_difference_threshold}" ]; then
            echo "Since the beginning of the job less than ${time_difference_threshold} seconds have passed."
            echo "Sleeping for some while to prevent a job submission home run..."
            sleep 60
        fi

        # Submitting the next job
        hq_bs_start_jobs.sh ${new_job_jtl} ${HQ_JID} ${HQ_JID} false false 1
    fi
}


# Printing final job information
print_job_infos_end() {
    # Job information
    echo
    echo "                                                     *** Final Job Information ***                                               "
    echo "*********************************************************************************************************************************"
    echo
    echo "Starting time:" $starting_time
    echo "Ending time:  " $(date)
    echo
}


#### Traps ###

# Syncing the control parameters here to get the signal types for the various traps
sync_control_parameters

# Standard internal error response
internal_error_response() {

    # Printing basic error information
    echo
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${internal_error_response}" == *"ignore"* ]]; then

        # Nothing to do, continuing script execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signal and error responses
        trap '' 1 2 3 9 10 12 15 18 ERR

        #  Variables
        new_job_jtl="${internal_error_new_job_jtl}"

        if [[ "${internal_error_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job ${new_job_jtl}
        fi
        if [[ "${internal_error_response}" == *"submit_new_job"* ]]; then
            submit_new_job ${new_job_jtl}
        fi
    fi

    # Exiting (only reached if signal response is not 'ignore')
    exit 1
}
trap 'internal_error_response $LINENO' ERR


# Type 1 signal handling
signals_type1_response() {

    # Immediately deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' ${signals_type1//:/ }

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${signals_type1_response}" == *"ignore"* ]]; then

        # Restoring the original signal trap trap
        trap 'signals_type1_response' ${signals_type1//:/ }

        # Continuing job execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signal and error responses
        trap '' 1 2 3 9 10 12 15 18 ERR

        #  Variables
        new_job_jtl="${signals_type1_new_job_jtl}"

        if [[ "${signals_type1_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job ${new_job_jtl}
        fi
        if [[ "${signals_type1_response}" == *"submit_new_job"* ]]; then
            submit_new_job ${new_job_jtl}
        fi
    fi

    # Exiting (only reached if signal response is not 'ignore')
    exit 0
}
if [[ -n "${signals_type1}" ]]; then
    trap 'signals_type1_response' ${signals_type1//:/ }
fi


# Type 2 signal handling
signals_type2_response() {

    # Immediately deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' ${signals_type2//:/ }

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${signals_type2_response}" == *"ignore"* ]]; then

        # Restoring the original signal trap trap
        trap 'signals_type2_response' ${signals_type2//:/ }

        # Continuing job execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signal and error responses
        trap '' 1 2 3 9 10 12 15 18 ERR

        #  Variables
        new_job_jtl="${signals_type2_new_job_jtl}"

        if [[ "${signals_type2_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job ${new_job_jtl}
        fi
        if [[ "${signals_type2_response}" == *"submit_new_job"* ]]; then
            submit_new_job ${new_job_jtl}
        fi
    fi

    # Exiting (only reached if signal response is not 'ignore')
    exit 0
}
if [[ -n "${signals_type2}" ]]; then
    trap 'signals_type2_response' ${signals_type2//:/ }
fi


# Type 3 signal handling
signals_type3_response() {

    # Immediately deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' ${signals_type3//:/ }

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${signals_type3_response}" == *"ignore"* ]]; then

        # Restoring the original signal trap trap
        trap 'signals_type3_response' ${signals_type3//:/ }

        # Continuing job execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signal and error responses
        trap '' 1 2 3 9 10 12 15 18 ERR

        #  Variables
        new_job_jtl="${signals_type3_new_job_jtl}"

        if [[ "${signals_type3_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job ${new_job_jtl}
        fi
        if [[ "${signals_type3_response}" == *"submit_new_job"* ]]; then
            submit_new_job ${new_job_jtl}
        fi
    fi

    # Exiting (only reached if signal response is not 'ignore')
    exit 0
}
if [[ -n "${signals_type3}" ]]; then
    trap 'signals_type3_response' ${signals_type3//:/ }
fi

terminate_processes() {

    # Printing some information
    echo " * Terminating remaining processes..."

    # Trapping ERR and other signals to prevent errors and other traps
    trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

    # Terminating remaining background jobs
    kill $(jobs -p)

    # Terminating everything else which is still running and which was started by this script
    pkill -P $$ || true

    # Terminating the entire process group
    kill -SIGTERM -$$ || true

    # Giving the processes some time to wrap up everthing
    sleep 15
}

# Exit trap
exit_response() {

    # Terminating remaining processes
    terminate_processes

    # Printing final information
    print_job_infos_end
}
trap 'exit_response' EXIT

### Preparing folders ###
# Preparing the output folder for the batchsystem log files
mkdir -p batchsystem/output-files


### Running the subjobs ###
source batchsystem/job-files/subjob-lists/jtl-${HQ_JTL}.jid-${HQ_JID}.sh

# Waiting for the subjobs to finish
wait

# Sleeping some time because sometimes the processes/tasks of this job might respond to job signals earlier than this script, which might be interpreted by the script as successful completion of the job (happened on the HLRN)
sleep 60

# Checking if the job was successful
if [ -f runtime/${HQ_STARTDATE}/error ]; then

    # There was an internal HQ error not propagated by the tasks, causing the error response now
    false

fi


### Finalizing the job (success case) ###

# Syncing the control parameters
sync_control_parameters

# Variables
new_job_jtl="${job_success_new_job_jtl}"

# Checking if the error should be ignored
if [[ "${job_success_actions}" == *"prepare_new_job"* ]]; then
    prepare_new_job ${new_job_jtl}
fi
if [[ "${job_success_actions}" == *"submit_new_job"* ]]; then
    submit_new_job ${new_job_jtl}
fi

# Exiting
exit 0
