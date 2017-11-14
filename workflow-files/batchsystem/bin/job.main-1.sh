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
    echo "Error: The Bash version seems to be too old. At least version 4.3 is required."
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
    HQ_SIGNAL_TYPE1="$(grep -m 1 "^signals_type1=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    HQ_SIGNAL_TYPE2="$(grep -m 1 "^signals_type2=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    HQ_SIGNAL_TYPE3="$(grep -m 1 "^signals_type3=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type1_response="$(grep -m 1 "^signals_type1_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type2_response="$(grep -m 1 "^signals_type2_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type3_response="$(grep -m 1 "^signals_type3_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    errors_hq_response="$(grep -m 1 "^errors_hq_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    HQ_ERRORS_SUBJOB_RESPONSE="$(grep -m 1 "^errors_subjob_response=" ${controlfile} | awk -F '=' '{print tolower($2)}' | tr -d '[:space:]')"
    errors_job_response="$(grep -m 1 "^errors_job_response=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type1_new_job_jtl="$(grep -m 1 "^signals_type1_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type2_new_job_jtl="$(grep -m 1 "^signals_type2_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    signals_type3_new_job_jtl="$(grep -m 1 "^signals_type3_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    errors_hq_new_job_jtl="$(grep -m 1 "^errors_hq_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    errors_subjob_new_job_jtl="$(grep -m 1 "^errors_subjob_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    errors_job_new_job_jtl="$(grep -m 1 "^errors_job_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    job_success_new_job_jtl="$(grep -m 1 "^job_success_new_job_jtl=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

    # Exporting relevant parameters
    export HQ_SIGNAL_TYPE1
    export HQ_SIGNAL_TYPE2
    export HQ_SIGNAL_TYPE3
    export HQ_ERRORS_SUBJOB_RESPONSE

    # Checking and adjusting the new job type letters (also replacing terms like 'same' or 'next' with the corresponding numerical value)
    for jtl_name in errors_job_new_job_jtl errors_subjob_new_job_jtl errors_hq_new_job_jtl signals_type1_new_job_jtl signals_type2_new_job_jtl signals_type3_new_job_jtl job_success_new_job_jtl; do

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

# Job error response (default error response)
errors_job_response() {

    # Printing basic error information
    echo
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the job error response. Exiting..."; exit 1' ERR

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${errors_job_response}" == *"ignore"* ]]; then

        # Restoring the default error response
        trap 'errors_job_response $LINENO' ERR

        # Nothing to do, continuing script execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signals responses
        trap '' 1 2 3 9 10 12 15 18 ${HQ_SIGNAL_TYPE1//:/ } ${HQ_SIGNAL_TYPE2//:/ } ${HQ_SIGNAL_TYPE3//:/ }

        #  Variables
        new_job_jtl="${errors_job_new_job_jtl}"

        # Checking if the next job should be prepared
        if [[ "${errors_job_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job ${new_job_jtl}
        fi

        # Checking if the next job should be submitted
        if [[ "${errors_job_response}" == *"submit_new_job"* ]]; then
            submit_new_job ${new_job_jtl}
        fi

        # Exiting
        exit 0
    fi
}
trap 'errors_job_response $LINENO' ERR

# Job error response (default error response)
errors_subjob_response() {

    # If subjob errors are ignored, we should not reach this point, except if the setting was changed during runtime

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the subjob error response. Exiting..."; exit 1' ERR

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${HQ_ERRORS_SUBJOB_RESPONSE}" == *"ignore"* ]]; then

        # Restoring the default error response
        trap 'errors_job_response $LINENO' ERR

        # Nothing to do, continuing script execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signals responses
        trap '' 1 2 3 9 10 12 15 18 ${HQ_SIGNAL_TYPE1//:/ } ${HQ_SIGNAL_TYPE2//:/ } ${HQ_SIGNAL_TYPE3//:/ }

        #  Variables
        new_job_jtl="${errors_subjob_new_job_jtl}"

        # Checking if the next job should be prepared
        if [[ "${HQ_ERRORS_SUBJOB_RESPONSE}" == *"prepare_new_job"* ]]; then
            prepare_new_job ${new_job_jtl}
        fi

        # Checking if the next job should be submitted
        if [[ "${HQ_ERRORS_SUBJOB_RESPONSE}" == *"submit_new_job"* ]]; then
            submit_new_job ${new_job_jtl}
        fi

        # Exiting
        exit 0
    fi
}

# HQ error response
errors_hq_response() {

    # Printing basic error information
    echo
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the hq error response. Exiting..."; exit 1' ERR

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${errors_hq_response}" == *"ignore"* ]]; then

        # Restoring the default error response
        trap 'errors_job_response $LINENO' ERR

        # Nothing to do, continuing script execution
        return

    # Error will not be ignored, leading to the script termination
    else

        # Deactivating further signals responses
        trap '' 1 2 3 9 10 12 15 18 ${HQ_SIGNAL_TYPE1//:/ } ${HQ_SIGNAL_TYPE2//:/ } ${HQ_SIGNAL_TYPE3//:/ }

        #  Variables
        new_job_jtl="${errors_hq_new_job_jtl}"

        # Checking if the next job should be prepared
        if [[ "${errors_hq_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job ${new_job_jtl}
        fi

        # Checking if the next job should be submitted
        if [[ "${errors_hq_response}" == *"submit_new_job"* ]]; then
            submit_new_job ${new_job_jtl}
        fi

        # Exiting
        exit 0
    fi
}

# Type 1 signal handling
signals_type1_response() {

    # Deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' 1 2 3 9 10 12 15 18 ${HQ_SIGNAL_TYPE1//:/ } ${HQ_SIGNAL_TYPE2//:/ } ${HQ_SIGNAL_TYPE3//:/ }

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the signal response. Exiting..."; exit 1' ERR

    # Syncing the control parameters
    sync_control_parameters

    #  Variables
    new_job_jtl="${signals_type1_new_job_jtl}"

    if [[ "${signals_type1_response}" == *"prepare_new_job"* ]]; then
        prepare_new_job ${new_job_jtl}
    fi
    if [[ "${signals_type1_response}" == *"submit_new_job"* ]]; then
        submit_new_job ${new_job_jtl}
    fi

    # Exiting
    exit 0
}
if [[ -n "${HQ_SIGNAL_TYPE1}" ]]; then
    trap 'signals_type1_response' ${HQ_SIGNAL_TYPE1//:/ }
fi


# Type 2 signal handling
signals_type2_response() {

    # Deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' 1 2 3 9 10 12 15 18 ${HQ_SIGNAL_TYPE1//:/ } ${HQ_SIGNAL_TYPE2//:/ } ${HQ_SIGNAL_TYPE3//:/ }

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the signal response. Exiting..."; exit 1' ERR

    # Syncing the control parameters
    sync_control_parameters

    #  Variables
    new_job_jtl="${signals_type2_new_job_jtl}"

    if [[ "${signals_type2_response}" == *"prepare_new_job"* ]]; then
        prepare_new_job ${new_job_jtl}
    fi
    if [[ "${signals_type2_response}" == *"submit_new_job"* ]]; then
        submit_new_job ${new_job_jtl}
    fi

    # Exiting
    exit 0
}
if [[ -n "${HQ_SIGNAL_TYPE2}" ]]; then
    trap 'signals_type2_response' ${HQ_SIGNAL_TYPE2//:/ }
fi


# Type 3 signal handling
signals_type3_response() {

    # Deactivating further signal responses since some batchsystems send an abundance of the same signal which would bring us into trouble when responding to every one of them in a recursive fashion (happened on the HLRN)
    trap '' 1 2 3 9 10 12 15 18 ${HQ_SIGNAL_TYPE1//:/ } ${HQ_SIGNAL_TYPE2//:/ } ${HQ_SIGNAL_TYPE3//:/ }

    # Setting up a new minimal ERR trap
    trap 'echo "Error during the signal response. Exiting..."; exit 1' ERR

    # Syncing the control parameters
    sync_control_parameters

    #  Variables
    new_job_jtl="${signals_type3_new_job_jtl}"

    if [[ "${signals_type3_response}" == *"prepare_new_job"* ]]; then
        prepare_new_job ${new_job_jtl}
    fi
    if [[ "${signals_type3_response}" == *"submit_new_job"* ]]; then
        submit_new_job ${new_job_jtl}
    fi

    # Exiting
    exit 0
}
if [[ -n "${HQ_SIGNAL_TYPE3}" ]]; then
    trap 'signals_type3_response' ${HQ_SIGNAL_TYPE3//:/ }
fi

# Function to check signals and errors
check_past_signals_errors() {

    # Order of precedence: signal_type1, signal_type2, signal_type3, internal errors

    # Checking for signals of type 1
    if [ -f runtime/${HQ_STARTDATE}/signal.type1 ]; then

        # Calling the corresponding function
        signals_type1_response
    fi

    # Checking for signals of type 2
    if [ -f runtime/${HQ_STARTDATE}/signal.type2 ]; then

        # Calling the corresponding function
        signals_type2_response
    fi

    # Checking for signals of type 3
    if [ -f runtime/${HQ_STARTDATE}/signal.type3 ]; then

        # Calling the corresponding function
        signals_type3_response
    fi

    # Checking for subjob errors
    if [ -f runtime/${HQ_STARTDATE}/error.subjob ]; then

        # Calling the corresponding function
        errors_subjob_response
    fi

    # Checking for hq errors
    if [ -f runtime/${HQ_STARTDATE}/error.hq ]; then

        # Calling the corresponding function
        errors_hq_response
    fi
}

# Function for terminating remaining processes
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

    ## Cleaning up files and folders
    #rm -r runtime/${HQ_STARTDATE} &>/dev/null || true

    # Printing final information
    print_job_infos_end
}
trap 'exit_response' EXIT

### Preparing folders ###
# Preparing the output folder for the batchsystem log files
mkdir -p batchsystem/output-files

###  Random sleep
# Sleeping a random amount of time to avoid race conditions when jobs are started simultaneously
# Relevant if the batchsystem starts pending jobs simultaneously. Not relevant for multiple tasks per subjob since we disperse them already in a controlled manner
job_initial_sleeping_time_max="$(grep -m 1 "^job_initial_sleeping_time_max=" ${controlfile} | awk -F '=' '{print tolower($2)}' | tr -d '[:space:]')"
dispersion_time=$(shuf -i 0-${job_initial_sleeping_time_max} -n1)
sleep ${dispersion_time}


### Running the subjobs ###

source batchsystem/job-files/subjob-lists/jtl-${HQ_JTL}.jid-${HQ_JID}.sh

# Waiting for the subjobs to finish
wait

# Sleeping some time to give the filesystem enough time to create possible error/signal files before checking them
sleep 5

# Checking if there were errors or signals during the job
check_past_signals_errors


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
