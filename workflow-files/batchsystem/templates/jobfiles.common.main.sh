#!/usr/bin/env bash

# Printing some information
echo
echo "                                                      *** Job Output ***                                                         "
echo "*********************************************************************************************************************************"
echo

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}' | tr -d '[:space:]')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi

# Setting up basic variables
starting_time="$(date)"
start_time_seconds="$(date -s)"
export HQF_STARTDATE="$(date +%Y%m%d%m%S-%N)"
batchsystem="$(grep -m 1 "^batchsystem=" input-files/config.txt| awk -F '=' '{print tolower($2})' | tr -d '[:space:]')"

# Syncing the control parameters
sync_control_parameters


### Functions ###
# Syncing control variables
sync_control_parameters() {

    # Determining the controlfile
    controlfile=""
    for file in batchsystem/control/*-*; do
        file_basename=$(basename $file)
        jid_range=${file_basename/.*}
        jid_start=${jid_range/-*}
        jid_end=${jid_range/*-}
        if [[ "${HQ_JID}" -ge "${jid_start}" && "${HQ_JID}" -le "${jid_end}" ]]; then
            controlfile="${file}"
            break
        fi
    done
    if [ -z "${controlfile}" ]; then
        controlfile="batchsystem/control/all.ctrl"
    fi

    # Getting the control parameters
    job_success_actions="$(grep -m 1 "^job_success_actions=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    prevent_new_job_submissions="$(grep -m 1 "^prevent_new_job_submissions=" ${controlfile} | awk -F '=' '{print tolower($2)}' | tr -d '[:space:]')"
    signals_type1="$(grep -m 1 "^signals_type1=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type2="$(grep -m 1 "^signals_type2=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type3="$(grep -m 1 "^signals_type3=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type1_response="$(grep -m 1 "^signals_type1_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type2_response="$(grep -m 1 "^signals_type2_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type3_response="$(grep -m 1 "^signals_type3_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    internal_error_response="$(grep -m 1 "^internal_error_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
}


# Preparing the new jobfile
prepare_new_job() {

    # Updating the job file
    hqh_bs_jobfile_increase_sn.sh ${HQ_JID}
}


# Start new job
start_new_job() {

    # Checking if the next job should really be submitted
    if [[ "${prevent_new_job_submissions}" == "false" ]]; then

        # Checking how much time has passed since the job has been started
        end_time_seconds="$(date +%s)"
        time_diff="$((end_time_seconds - start_time_seconds))"
        time_difference_treshhold=600
        if [ "${time_diff}" -le "${time_difference_treshhold}" ]; then
            echo "Since the beginning of the job less than ${time_difference_treshhold} seconds have passed."
            echo "Sleeping for some while to prevent a job submission run..."
            sleep 10
        fi

        # Submitting the next job
        hqh_bs_submit.sh batchsystem/job-files/main/${HQ_JID}.${batchsystem}
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
# Internal error response
error_response_std() {

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
        return
    else
        if [[ "${internal_error_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${internal_error_response}" == *"start_new_job"* ]]; then
            start_new_job
        fi
    fi

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR


# Type 1 signal handling
signals_type1_response() {

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${signals_type1_response}" == *"ignore"* ]]; then
        return
    else
        if [[ "${signals_type1_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${signals_type1_response}" == *"start_new_job"* ]]; then
            start_new_job
        fi
    fi

    # Exiting
    exit 0
}
if [[ -n "${signals_type1}" ]]; then
    trap 'signals_type1_response' ${signals_type1//:/ }
fi


# Type 2 signal handling
signals_type2_response() {

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${signals_type2_response}" == *"ignore"* ]]; then
        return
    else
        if [[ "${signals_type2_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${signals_type2_response}" == *"start_new_job"* ]]; then
            start_new_job
        fi
    fi

    # Exiting
    exit 0
}
if [[ -n "${signals_type1}" ]]; then
    trap 'signals_type2_response' ${signals_type2//:/ }
fi


# Type 3 signal handling
signals_type3_response() {

    # Syncing the control parameters
    sync_control_parameters

    # Checking if the error should be ignored
    if [[ "${signals_type3_response}" == *"ignore"* ]]; then
        return
    else
        if [[ "${signals_type3_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${signals_type3_response}" == *"start_new_job"* ]]; then
            start_new_job
        fi
    fi

    # Exiting
    exit 0
}
if [[ -n "${signals_type1}" ]]; then
    trap 'signals_type3_response' ${signals_type3//:/ }
fi


# Exit trap
exit_response() {

    # Printing final information
    print_job_infos_end
}


### Preparing folders ###
# Preparing the output folder for the batchsystem log files
mkdir -p batchsystem/output-files


### Running the subjobs ###
source batchsystem/job-files/subjobs/jid-${HQ_JID}.sh

# Waiting for the subjobs to finish
wait

### Finalizing the job ###
# Syncing the control parameters
sync_control_parameters

# Checking if the error should be ignored
if [[ "${job_success_actions}" == *"prepare_new_job"* ]]; then
    prepare_new_job
fi
if [[ "${job_success_actions}" == *"start_new_job"* ]]; then
    start_new_job
fi

# Exiting
exit 0
