#!/usr/bin/env bash

# Usage information
usage="Usage: hqf_gen_run_one_pipe.sh <msp> <subsystem> <pipeline_type> [<tds_range>]

Arguments:
    <subsystem>: Possible values: L, LS, RLS

    <MSP>: The molecular system pair (MSP) in form of system1_system2

    The pipeline can be composed of:
     Elementary components:
      _pro_: preparing the optimizations
      _rop_: running the optimizations
      _ppo_: postprocessing the optimizations
      _pre_: preparing the equilibrations
      _req_: running the equilibrations
      _ppe_: postprocessing the equilibrations
      _prm_: preparing MD simulation
      _rmd_: postprocessing MD simulation
      _prc_: preparing the crossevaluations
      _rce_: postprocessing the crossevaluations
      _prf_: preparing the free energy calculation
      _rfe_: postprocessing the free energy calculation
      _ppf_: postprocessing the free energy calculation

     Macro components:
      _allopt_: equals _pro_rop_ppo_
      _alleq_: equals _pre_req_ppe_
      _allmd_ : equals _prd_rmd_
      _allce_ : equals _prc_rce_
      _allfec_: equals _prf_rfe_ppf_
      _all_   : equals _allopt_alleq_allmd_allce_allfec_

    <tds_range>:
      * Format: startindex:endindex
      * The index starts at 1
      * The capital letter K can be used to indicate the end state of the thermodynamic path
      * Currently only relevant for opt, eq, md
      * If unset, 1:K will be used for the commands which need a range argument

The script has to be run in the root folder."
set -x
# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [[ "$#" -ne "3" ]] && [[ "$#" -ne "4" ]]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 3-4"
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
    echo "Exiting..."
    echo
    echo

    # Setting the file-based error flag for the batchsystem module
    touch runtime/${HQ_BS_STARTDATE}/error.pipeline
    exit 1
}
trap 'error_response_std $LINENO' ERR

user_abort() {

    echo "Info: User abort, cleaning up..."

    # Forwarding the signal to our child processess
    pkill -SIGINT -P $$ || true
    pkill -SIGTERM -P $$ || true
    pkill -SIGQUIT -P $$ || true

    # Giving the child processes enough time to exit gracefully
    sleep 5
    exit 1
}
trap 'user_abort' SIGINT

# Exit cleanup
cleanup_exit() {

    # Printing some information
    echo
    echo "Cleaning up..."

    # Removing remaining socket files
    rm /tmp/ipi_${workflow_id}.${HQ_PIPE_STARTDATE}.* 2>&1 > /dev/null

    # Terminating all remaining processes
    # Getting our process group id
    pgid=$(ps -o pgid= $$ | grep -o [0-9]*)
    # The pgid is supposed to be the pid since we are supposed to be the session leader, but due to the error we can't be sure

    # Terminating everything which was started by this script
    pkill -SIGTERM -P $$ || true
    sleep 1 || true

    # Terminating it in a new process group
    echo -e '\n * Terminating all remaining processes...\n\n'
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Terminating the entire process group
        kill -SIGTERM -$pgid 2>&1 1>/dev/null || true
        sleep 10 || true
        kill -9 -$pgid 2>&1 1>/dev/null || true
    " || true &> /dev/null
}
trap "cleanup_exit" EXIT

# Convert pid to pgid
pgid_from_pid() {

    # Variables
    pid=$1

    # Getting the pgid
    pgid_tmp=$(ps -o pgid= "$pid" 2>/dev/null | egrep -o "[0-9]+")

    # Printing/returning the pgid
    echo "${pgid_tmp}"
}

# Bash options
set -o pipefail
set +m                      # Making sure job control is deactivated so that everything remains in our PGID

# Checking the folder
if [ ! -d input-files ]; then
    echo
    echo -e " * Error: This script has to be run in the root folder. Exiting..."
    echo
    echo

    false
fi

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity_runtime=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" == "debug" ]; then
    set -x
fi

# Setting the start date of this pipeline
HQ_PIPE_STARTDATE="$(date +%Y%m%d%m%S-%N)"
export HQ_PIPE_STARTDATE

# Checking if the batchsystem job startdate is set, which is the case only if HQ is run in the batchsystem mode
if [ -z "${HQ_BS_STARTDATE}" ]; then

    # Setting the HQ_BS_STARTDATE to the HQ_PIPE_STARTDATE
    HQ_BS_STARTDATE=${HQ_PIPE_STARTDATE}
    export HQ_BS_STARTDATE
fi

# Human readable start date
#startdate_hr="$(date --rfc-3339=seconds | tr -s ": " "_")"

# Variables
msp_name="${1}"
subsystem="${2}"
pipeline_type="${3}"
system1="${msp_name/_*}"
system2="${msp_name/*_}"
workflow_id="$(grep -m 1 "^workflow_id=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
command_prefix_gen_run_one_pipe_sub="$(grep -m 1 "^command_prefix_gen_run_one_pipe_sub=" input-files/config.txt | awk -F '[=#]' '{print $2}')"
logfile_folder_root="log-files/${HQ_BS_STARTDATE}/${msp_name}_${subsystem}"

# TDS Range
if [ "${#}" == "4" ]; then
    tds_range="${4}"
else
    tds_range=1:K
fi

# Folders
mkdir -p ${logfile_folder_root}
mkdir -p runtime/${HQ_BS_STARTDATE}/

# Checking if we are the session leader
pgid=$(pgid_from_pid $$)
if [ "$$" != "${pgid}" ]; then

    # Sleeping shortly to prevent an infinite loop overload, just in case
    sleep 1

    # Changing the PGID of this process to our own PID (but out PID will remain the same - process replacement)
    # Exit traps will not be executed anymore, thus no need to suppress them (since they would kill the entire process group)
    exec setsid hqf_gen_run_one_pipe.sh $@

    # If the above command would have worked we would not have reached this line
    echo -e " * Failed to make this script a process group leader. Exiting..."

    # Deactivating the default exit trap since it would terminate the entire process group, while we are not the group leader
    trap '' EXIT

    # Exiting
    exit 0
fi

# Logging the output of this script
exec &> >(tee ${logfile_folder_root}/hqf_gen_run_one_pipe.sh_${pipeline_type})

# Preparing the optimizations
if [[ "${pipeline_type}" == *"_pro_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    ${command_prefix_gen_run_one_pipe_sub} hqf_opt_prepare_one_msp.sh ${system1} ${system2} ${subsystem} ${tds_range} 2>&1 | tee ${logfile_folder_root}/hqf_opt_prepare_one_msp_${tds_range}
fi

# Running the optimizations
if [[ ${pipeline_type} == *"_rop_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd opt/${msp_name}/${subsystem}
    ${command_prefix_gen_run_one_pipe_sub} hqf_opt_run_one_msp.sh ${tds_range} 2>&1 | tee ../../../${logfile_folder_root}/hqf_opt_run_one_msp_${tds_range}
    cd ../../../
fi

# Postprocessing the optimizations
if [[ ${pipeline_type} == *"_ppo_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd opt/${msp_name}/${subsystem}
    ${command_prefix_gen_run_one_pipe_sub} hqf_opt_pp_one_msp.sh ${tds_range} 2>&1 | tee ../../../${logfile_folder_root}/hqf_opt_pp_one_msp_${tds_range}
    cd ../../../
fi

# Preparing the equilibrations
if [[ "${pipeline_type}" == *"_pre_"* ]] || [[ "${pipeline_type}" == *"_alleq_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    ${command_prefix_gen_run_one_pipe_sub} hqf_eq_prepare_one_msp.sh ${system1} ${system2} ${subsystem} ${tds_range} 2>&1 | tee ${logfile_folder_root}/hqf_eq_prepare_one_msp_${tds_range}
fi

# Running the equilibrations
if [[ ${pipeline_type} == *"_req_"* ]] || [[ "${pipeline_type}" == *"_alleq_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd eq/${msp_name}/${subsystem}
    ${command_prefix_gen_run_one_pipe_sub} hqf_eq_run_one_msp.sh ${tds_range} 2>&1 | tee ../../../${logfile_folder_root}/hqf_eq_run_one_msp_${tds_range}
    cd ../../../
fi

# Postprocessing the equilibrations
if [[ ${pipeline_type} == *"_ppe_"* ]] || [[ "${pipeline_type}" == *"_alleq_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd eq/${msp_name}/${subsystem}
    ${command_prefix_gen_run_one_pipe_sub} hqf_eq_pp_one_msp.sh ${tds_range} 2>&1 | tee ../../../${logfile_folder_root}/hqf_eq_pp_one_msp_${tds_range}
    cd ../../../
fi

# Preparing the MD simulations
if [[ ${pipeline_type} == *"_prm_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    ${command_prefix_gen_run_one_pipe_sub} hqf_md_prepare_one_msp.sh ${system1} ${system2} ${subsystem} ${tds_range} 2>&1 | tee ${logfile_folder_root}/hqf_md_prepare_one_msp_${tds_range}
fi

# Running the MD simulations
if [[ ${pipeline_type} == *"_rmd_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd md/${msp_name}/${subsystem}
    ${command_prefix_gen_run_one_pipe_sub} hqf_md_run_one_msp.sh ${tds_range} 2>&1 | tee ../../../${logfile_folder_root}/hqf_md_run_one_msp_${tds_range}
    cd ../../../
fi

# Preparing the crossevaluations
if [[ ${pipeline_type} == *"_prc_"* ]] || [[ "${pipeline_type}" == *"_allce_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    ${command_prefix_gen_run_one_pipe_sub} hqf_ce_prepare_one_msp.sh ${system1} ${system2} ${subsystem} 2>&1 | tee ${logfile_folder_root}/hqf_ce_prepare_one_msp
fi

# Running the crossevaluations
if [[ ${pipeline_type} == *"_rce_"* ]] || [[ "${pipeline_type}" == *"_allce_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd ce/${msp_name}/${subsystem}
    ${command_prefix_gen_run_one_pipe_sub} hqf_ce_run_one_msp.sh 2>&1 | tee ../../../${logfile_folder_root}/hqf_ce_run_one_msp
    cd ../../../
fi

# Preparing the fec
if [[ ${pipeline_type} == *"_prf_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    ${command_prefix_gen_run_one_pipe_sub} hqf_fec_prepare_one_msp.sh ${system1} ${system2} ${subsystem} 2>&1 | tee ${logfile_folder_root}/hqf_fec_prepare_one_msp
fi

# Running the fec
if [[ ${pipeline_type} == *"_rfe_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd fec/AFE/${msp_name}/${subsystem}/
    ${command_prefix_gen_run_one_pipe_sub} hqf_fec_run_one_msp.sh 2>&1 | tee ../../../../${logfile_folder_root}/hqf_fec_run_one_msp
    cd ../../../../
fi

# Postprocessing the fec
if [[ ${pipeline_type} == *"_ppf_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    cd fec/AFE/${msp_name}/${subsystem}/
    ${command_prefix_gen_run_one_pipe_sub} hqf_fec_pp_one_msp.sh 2>&1 | tee ../../../../${logfile_folder_root}/hqf_fec_pp_one_msp
    cd ../../../../
fi
