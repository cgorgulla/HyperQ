#!/usr/bin/env bash

# Usage infomation
usage="Usage: hqf_gen_run_one_pipe.sh <msp_name> <subsystem> <pipeline_type>

The script has to be run in the root folder.

The pipeline can be composed of:
 Elementy elements:
  _pro_: prepare the optimization
  _rop_: run the optimization
  _ppo_: postprocess the optimization
  _prm_: prepare md simulation
  _rmd_: run md simulation
  _prc_: prepare the crossevaluation
  _rce_: run the crossevaluation
  _prf_: prepare the free energy calculation
  _rfe_: run the free energy calculation
  _ppf_: postprocess the free energy calculation

 Combined elements:
  _allopt_: equals _pro_rop_ppo_
  _allmd_ : equals _prd_rmd_
  _allce_ : equals _prc_rce_
  _allfec_: equals _prf_rfe_ppf_
  _all_   : equals _allopt_allmd_allce_allfec_ =  _pro_rop_ppo_prd_rmd_prc_rce_prf_rfe_ppf_
"

# Checking the input arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "3" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 3"
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
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Exit cleanup
cleanup_exit() {

    echo "Cleaning up..."

    # Changing to the root folder
    for i in {1..5}; do
        if [ -d input-files ]; then
            # Removing possible error files
            rm runtime/error 1>/dev/null 2>&1 || true
            break
        else
            cd ..
        fi
    done

    # Get our process group id
    pgid=$(ps -o pgid= $$ | grep -o [0-9]*)
    # Terminating it in a new process group
    echo -e '\n * Terminating all remaining processes...\n\n'
    sleep 1

    setsid bash -c "kill -- -$pgid 2>&1 1> /dev/null; sleep 5; kill -9 -$pgid 2>&1 1>/dev/null || true"  2>&1 > /dev/null ;
}
trap "cleanup_exit" EXIT

# Error indicator check
check_error_indicators() {
    sleep 5
    if [ -f "runtime/error" ]; then
        echo -e " * Error detected. Exiting...\n\n"
        exit 1
    fi
}

# Bash options
set -o pipefail

# Checking the folder
if [ ! -d input-files ]; then
    echo
    echo -e " * Error: This script has to be run in the root folder. Exiting..."
    echo
    echo
    exit 1
fi

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
msp_name="${1}"
subsystem="${2}"
pipeline_type="${3}"
system1="${msp_name/_*}"
system2="${msp_name/*_}"
date="$(date --rfc-3339=seconds | tr ": " "_")"

# Removing old  file
if [ -f runtime/error ]; then
    rm runtime/error
fi

# Folders
mkdir -p log-files/${date}/${msp_name}_${subsystem}
mkdir -p runtime
mkdir -p runtime/pids/${msp_name}_${subsystem}/

# Optimizations
if [[ "${pipeline_type}" == *"_pro_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    hqf_opt_prepare_one_msp.sh ${system1} ${system2} ${subsystem}  2>&1  | tee log-files/${date}/${msp_name}_${subsystem}/hqf_opt_prepare_one_msp_${system1}_${system2}_${subsystem}
    check_error_indicators
fi

# Running the optimizations
if [[ ${pipeline_type} == *"_rop_"* ]] || [[ "${pipeline_type}" == *"_allopt_"*  ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then

    if [ -d runtime/pids/${msp_name}_${subsystem}/opt ]; then
        rm -r runtime/pids/${msp_name}_${subsystem}/opt
    fi

    cd opt/${msp_name}/${subsystem}
    hqf_opt_run_one_msp.sh 2>&1  | tee ../../../log-files/${date}/${msp_name}_${subsystem}/hqf_opt_run_one_msp
    cd ../../../
    check_error_indicators
fi 

# Postprocessing the optimizations
if [[ ${pipeline_type} == *"_ppo_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd opt/${msp_name}/${subsystem}
    hqf_opt_pp_one_msp.sh 2>&1  | tee ../../../log-files/${date}/${msp_name}_${subsystem}/hqf_opt_pp_one_msp
    cd ../../../
    check_error_indicators
fi

# Preparing the md simulations
if [[ ${pipeline_type} == *"_prm_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    if [ -d runtime/pids/${msp_name}_${subsystem}/md ]; then
        rm -r runtime/pids/${msp_name}_${subsystem}/md
    fi
    hqf_md_prepare_one_msp.sh ${system1} ${system2} ${subsystem} 2>&1 | tee log-files/${date}/${msp_name}_${subsystem}/hqf_md_prepare_one_msp_${system1}_${system2}_${subsystem}
    check_error_indicators
fi

# Running the md simulations
if [[ ${pipeline_type} == *"_rmd_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd md/${msp_name}/${subsystem}
    hqf_md_run_one_msp.sh 2>&1 | tee ../../../log-files/${date}/${msp_name}_${subsystem}/hqf_md_run_one_msp
    cd ../../../
    check_error_indicators
fi

# Preparing the crossevaluations
if [[ ${pipeline_type} == *"_prc_"* ]] || [[ "${pipeline_type}" == *"_allce_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    hqf_ce_prepare_one_msp.sh ${system1} ${system2} ${subsystem} 2>&1 | tee log-files/${date}/${msp_name}_${subsystem}/hqf_ce_prepare_one_msp.sh_${system1}_${system2}_${subsystem}
    check_error_indicators
fi

# Running the crossevaluations
if [[ ${pipeline_type} == *"_rce_"* ]] || [[ "${pipeline_type}" == *"_allce_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    if [ -d runtime/pids/${msp_name}_${subsystem}/ce ]; then
        rm -r runtime/pids/${msp_name}_${subsystem}/ce
    fi
    cd ce/${msp_name}/${subsystem}
    hqf_ce_run_one_msp.sh 2>&1 | tee ../../../log-files/${date}/${msp_name}_${subsystem}/hqf_ce_run_one_msp
    cd ../../../
    check_error_indicators
fi

# Preparing the fec
if [[ ${pipeline_type} == *"_prf_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    hqf_fec_prepare_one_msp.sh ${system1} ${system2} ${subsystem} 2>&1 | tee log-files/${date}/${msp_name}_${subsystem}/hqf_fec_prepare_one_msp_${system1}_${system2}_${subsystem}
    check_error_indicators
fi

# Running the fec
if [[ ${pipeline_type} == *"_rfe_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd fec/AFE/${msp_name}/${subsystem}/
    hqf_fec_run_one_msp.sh 2>&1 | tee ../../../../log-files/${date}/${msp_name}_${subsystem}/hqf_fec_run_one_msp
    cd ../../../../
    check_error_indicators
fi

# Running the fec
if [[ ${pipeline_type} == *"_ppf_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd fec/AFE/${msp_name}/${subsystem}/
    hqf_fec_pp_one_msp.sh 2>&1 | tee ../../../../log-files/${date}/${msp_name}_${subsystem}/hqf_fec_pp_one_msp
    cd ../../../../
    check_error_indicators
fi