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
    kill  0  1>/dev/null 2>&1 || true # Stops the proccesses of the same process group as the calling process
    #kill $(pgrep -f $DAEMON | grep -v ^$$\$)
}
trap "cleanup_exit" EXIT

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
ncpus_cp2k_opt="$(grep -m 1 "^ncpus_cp2k_opt" input-files/config.txt | awk -F '=' '{print $2}')"
ncpus_cp2k_md="$(grep -m 1 "^ncpus_cp2k_md" input-files/config.txt | awk -F '=' '{print $2}')"
ncpus_cp2k_ce="$(grep -m 1 "^ncpus_cp2k_ce" input-files/config.txt | awk -F '=' '{print $2}')"
nbeads=$(grep -m 1 "^nbeads" input-files/config.txt | awk -F '=' '{print $2}')
ntdsteps=$(grep -m 1 "^ntdsteps" input-files/config.txt | awk -F '=' '{print $2}')
stride_ce="$(grep -m 1 "^stride_ce" input-files/config.txt | awk -F '=' '{print $2}')"
msp_name=${1}
subsystem=${2}
pipeline_type=${3}
system1=${msp_name/_*}
system2=${msp_name/*_}

# Optimizations
if [[ "${pipeline_type}" == *"_pro_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"* ]]; then
    hqf_opt_prepare_one_msp.sh  ${nbeads} ${ntdsteps} ${system1} ${system2} ${subsystem}
fi

# Running the optimizations
if [[ ${pipeline_type} == *"_rop_"* ]] || [[ "${pipeline_type}" == *"_allopt_"*  ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd opt/${msp_name}/${subsystem}
    hqf_opt_run_one_msp.sh
    cd ../../../
fi 

# Postprocessing the optimizations
if [[ ${pipeline_type} == *"_ppo_"* ]] || [[ "${pipeline_type}" == *"_allopt_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd opt/${msp_name}/${subsystem}
    hqf_opt_pp_one_msp.sh
    cd ../../../
fi

# Preparing the md simulations
if [[ ${pipeline_type} == *"_prm_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    hqf_md_prepare_one_msp.sh ${system1} ${system2} ${subsystem} ${nbeads} ${ntdsteps}
fi

# Running the md simulations
if [[ ${pipeline_type} == *"_rmd_"* ]] || [[ "${pipeline_type}" == *"_allmd_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd md/${msp_name}/${subsystem}
    hqf_md_run_one_msp.sh
    cd ../../../
fi

# Preparing the crossevaluations
if [[ ${pipeline_type} == *"_prc_"* ]] || [[ "${pipeline_type}" == *"_allce_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    hqf_ce_prepare_one_msp.sh ${system1} ${system2} ${subsystem} ${nbeads} ${ntdsteps} ${stride_ce}
fi

# Running the crossevaluations
if [[ ${pipeline_type} == *"_rce_"* ]] || [[ "${pipeline_type}" == *"_allce_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd ce/${msp_name}/${subsystem}
    hqf_ce_run_one_msp.sh
    cd ../../../
fi

# Preparing the fec
if [[ ${pipeline_type} == *"_prf_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    hqf_fec_prepare_one_msp.sh ${system1} ${system2} ${subsystem}
fi

# Running the fec
if [[ ${pipeline_type} == *"_rfe_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd fec/AFE/${msp_name}/${subsystem}/
    hqf_fec_run_one_msp.sh
    cd ../../../../
fi

# Running the fec
if [[ ${pipeline_type} == *"_ppf_"* ]] || [[ "${pipeline_type}" == *"_allfec_"* ]] || [[ "${pipeline_type}" == *"_all_"*  ]]; then
    cd fec/AFE/${msp_name}/${subsystem}/
    hqf_fec_pp_one_msp.sh
    cd ../../../../
fi