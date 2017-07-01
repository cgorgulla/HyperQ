#!/usr/bin/env bash

usage="Usage: hqmd_gen_run_one_pipe.sh <system_name> <subsystem> <pipeline_type>

The script has to be run in the root folder.\n\nThe pipeline can be composed of:
Elementy elements:
   _pro_: prepare the optimization
   _rop_: run the optimization
   _ppo_: postprocess the optimization
   _prm_: prepare md simulation
   _rmd_: run md simulation

Combined elements:
   _allopt_: equals _pro_rop_ppo_
   _allmd_ : equals _prd_rmd_
   _all_   : equals _allopt_allmd_ = _pro_rop_ppo_prd_rmd_"

#Checking the input arguments
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
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    exit 1 
}
trap 'error_response_std $LINENO' ERR

# Exit cleanup
cleanup_exit() {
    kill 0  1>/dev/null 2>&1 || true # Stops the proccesses of the same process group as the calling process
    #kill $(pgrep -f $DAEMON | grep -v ^$$\$)
    #return
}
trap "cleanup_exit" EXIT

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
system=${1}
subsystem=${2}
pipeline_type=${3}

# Printing information
echo -e "\n **** Running one pipeline (${pipeline_type}) for the system ${system} where the subsystem is ${subsystem} ****"

# Optimizations
if [[ "${pipeline_type}" == *"_pro_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    hqmd_opt_prepare_one_ms.sh ${system} ${subsystem}
fi

# Running the optimizations
if [[ ${pipeline_type} == *"_rop_"* ]] || [[ "${pipeline_type}" == *"_allopt_"*  ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd opt/${system}/${subsystem}
    hqmd_opt_run_one_ms.sh
    cd ../../../
fi 

# Postprocessing the optimizations
if [[ ${pipeline_type} == *"_ppo_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd opt/${system}/${subsystem}
    hqmd_opt_pp_one_ms.sh
    cd ../../../
fi

# Preparing the md simulations
if [[ ${pipeline_type} == *"_prm_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    hqmd_md_prepare_one_ms.sh ${system} ${subsystem}
fi

# Running the md simulations
if [[ ${pipeline_type} == *"_rmd_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd md/${system}/${subsystem}
    hqmd_md_run_one_ms.sh
    cd ../../../
fi

# Postprocessing the md simulations
if [[ ${pipeline_type} == *"_ppm_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd md/${system}/${subsystem}
    hqmd_md_pp_one_ms.sh
    cd ../../../
fi