#!/usr/bin/env bash

# Printing some information
echo
echo "                                                      *** Job Output ***                                                         "
echo "*********************************************************************************************************************************"
echo

# Shell options
shopt -s nullglob

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
    job_success_actions="$(grep -m 1 "^job_success_actions=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    prevent_new_job_submissions="$(grep -m 1 "^prevent_new_job_submissions=" ${controlfile} | awk -F '=' '{print tolower($2)}' | tr -d '[:space:]')"
    signals_type1="$(grep -m 1 "^signals_type1=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type2="$(grep -m 1 "^signals_type2=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type3="$(grep -m 1 "^signals_type3=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type1_response="$(grep -m 1 "^signals_type1_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type2_response="$(grep -m 1 "^signals_type2_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type3_response="$(grep -m 1 "^signals_type3_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    internal_error_response="$(grep -m 1 "^internal_error_response=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    internal_error_new_job_jtl="$(grep -m 1 "^internal_error_new_job_jtl=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type1_new_job_jtl="$(grep -m 1 "^signals_type1_new_job_jtl=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type2_new_job_jtl="$(grep -m 1 "^signals_type2_new_job_jtl=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    signals_type3_new_job_jtl="$(grep -m 1 "^signals_type3_new_job_jtl=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"
    job_success_new_job_jtl="$(grep -m 1 "^job_success_new_job_jtl=" ${controlfile} | awk -F '=' '{print $2}' | tr -d '[:space:]')"

    # Checking and adjusting the new job type letter
    if [[ "${new_job_jtl}" =~ [abcdefghij] ]]; then

        # Nothing to do
        :
    elif [[ "${new_job_jtl}" == "same" ]]; then

        # Setting the new jtl
        new_job_jtl="${HQ_JTL}"
    elif [[ "${new_job_jtl}" == "next" ]]; then

        # Increasing the new jtl to the next letter in the alphabet
        new_job_jtl=$(echo ${HQ_JTL} | tr abcdefghi 012345678 | awk '{print $1+1}' | tr 0123456789 abcdefghij)              #$((36#${HQ_JTL}-9))    https://stackoverflow.com/questions/27489170/assign-number-value-to-alphabet-in-shell-bash
    else
        echo -e "\n * Error: The input argument 'job type letter' has an unsupported value. Exiting...\n\n"
        exit 1
    fi
}


# Preparing the new jobfile
prepare_new_job() {

    # Updating the job file
    hqh_bs_jobfile_increase_sn.sh ${new_job_jtl} ${HQ_JID}
}


# Start new job
submit_new_job() {

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
        hqh_bs_submit.sh batchsystem/job-files/main/jtl-${new_job_jtl}.jid-${HQ_JID}.${batchsystem}
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

    #  Variables
    new_job_jtl="${signals_type1_new_job_jtl}"

    # Checking if the error should be ignored
    if [[ "${internal_error_response}" == *"ignore"* ]]; then
        return
    else
        if [[ "${internal_error_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${internal_error_response}" == *"submit_new_job"* ]]; then
            submit_new_job
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

    #  Variables
    new_job_jtl="${signals_type1_new_job_jtl}"

    # Checking if the error should be ignored
    if [[ "${signals_type1_response}" == *"ignore"* ]]; then
        return
    else
        if [[ "${signals_type1_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${signals_type1_response}" == *"submit_new_job"* ]]; then
            submit_new_job
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

    #  Variables
    new_job_jtl="${signals_type2_new_job_jtl}"

    # Checking if the error should be ignored
    if [[ "${signals_type2_response}" == *"ignore"* ]]; then
        return
    else
        if [[ "${signals_type2_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${signals_type2_response}" == *"submit_new_job"* ]]; then
            submit_new_job
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

    #  Variables
    new_job_jtl="${signals_type3_new_job_jtl}"

    # Checking if the error should be ignored
    if [[ "${signals_type3_response}" == *"ignore"* ]]; then
        return
    else
        if [[ "${signals_type3_response}" == *"prepare_new_job"* ]]; then
            prepare_new_job
        fi
        if [[ "${signals_type3_response}" == *"submit_new_job"* ]]; then
            submit_new_job
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
source batchsystem/job-files/subjobs/jtl-${HQ_JTL}.jid-${HQ_JID}.sh

# Waiting for the subjobs to finish
wait

### Finalizing the job ###
# Syncing the control parameters
sync_control_parameters

#  Variables
new_job_jtl="${job_success_new_job_jtl}"

# Checking if the error should be ignored
if [[ "${job_success_actions}" == *"prepare_new_job"* ]]; then
    prepare_new_job
fi
if [[ "${job_success_actions}" == *"submit_new_job"* ]]; then
    submit_new_job
fi

# Exiting
exit 0
