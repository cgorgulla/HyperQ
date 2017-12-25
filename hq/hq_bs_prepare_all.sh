#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_bs_prepare_all.sh <msp list> <job-template> <subjob template> <subsystems> <job types> <to_prepare>

Summary: This script prepares the batchsystem files in a default mode:
         * One task per subjob, one subjob per job
         * One TDS per task for job types 'b' and 'c', one MSP per task for job type 'd'
         * Creates the task lists in the folder batchsystem, and names them all.<subsystem>.<pipeline_type>
         * The jobfiles start their numbering at 1 for LS, 1001 for RLS
         * Setting the cpus_per_task variable of batchsystem control files batchsystem/c-c:*.ctrl and d-d.*.ctrl to the number of beads

Arguments:
    <msp list>: One task per line, one task is represented by one command. No empty lines should be present.
    <subsystems>: Possible values: L, LS, RLS. Multiple types can be specified separated by a colon (e.g. LS:RLS).
    <job types>: Multiple types can be specified separated by a colon (e.g. a:b:c). Possible values are:
        b: _opt_eq_
        c: _md_
        d: _ce_fec_
    <to_prepare>: Possible values
        * tasks
        * jobs
        * all

Has to be run in the root folder."

# Checking the input paras
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "6" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 6"
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
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Config file setup
if [[ -z "${HQ_CONFIGFILE_GENERAL}" ]]; then

    # Printing some information
    echo " * Info: The variable HQ_CONFIGFILE_GENERAL was unset. Setting it to input-files/config/general.txt"

    # Setting and exporting the variable
    HQ_CONFIGFILE_GENERAL=input-files/config/general.txt
    export HQ_CONFIGFILE_GENERAL
fi

# Verbosity
# Checking if standalone mode (-> non-runtime)
if [[ -z "${HQ_VERBOSITY_RUNTIME}" && -z "${HQ_VERBOSITY_NONRUNTIME}" ]]; then

    # Variables
    export HQ_VERBOSITY_NONRUNTIME="$(grep -m 1 "^verbosity_nonruntime=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

    # Checking the value
    if [ "${HQ_VERBOSITY_NONRUNTIME}" = "debug" ]; then
        set -x
    fi

# It seems the script was called by another script (non-standalone mode)
else
    if [[ "${HQ_VERBOSITY_RUNTIME}" == "debug" || "${HQ_VERBOSITY_NONRUNTIME}" == "debug" ]]; then
        set -x
    fi
fi

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

# Variables
msp_list=$1
job_template=$2
subjob_template=$3
subsystems=$4
jobtypes=$5
toprepare=$6
nbeads="$(grep -m 1 "^nbeads=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Loop for each job type
for jobtype in ${jobtypes//:/ }; do

    # Jobtype c
    if [[ "${jobtype}" == "c" ]]; then

        # Adjusting the cpus_per_subjob variable
        sed -i "s/cpus_per_subjob=.*/cpus_per_subjob=${nbeads}/g" batchsystem/control/c-c:*.ctrl || true
    fi

    # Jobtype d
    if [[ "${jobtype}" == "d" ]]; then

        # Adjusting the cpus_per_subjob variable
        jtl_d_cpu_multipliactor=1
        sed -i "s/cpus_per_subjob=.*/cpus_per_subjob=$((nbeads*${jtl_d_cpu_multipliactor}))/g" batchsystem/control/d-d:*.ctrl || true
    fi
done

# Loop for each subsystem
for subsystem in ${subsystems//:/ }; do

    # Variables
    if [ "${subsystem}" == "L" ]; then
        first_jid=1001
    elif [ "${subsystem}" == "LS" ]; then
        first_jid=2001
    elif [ "${subsystem}" == "RLS" ]; then
        first_jid=3001
    fi

    # Loop for each job type
    for jobtype in ${jobtypes//:/ }; do

        # Job type b
        if [[ "${jobtype}" == "b" ]]; then

            # Preparing the tasks
            if  [[ "${toprepare}" == "tasks" ]] || [[ "${toprepare}" == "all" ]]; then
                hq_bs_prepare_all_tasks.sh input-files/mappings/msp.all "hqf_gen_run_one_pipe.sh MSP ${subsystem} _allopt_alleq_ TDS" batchsystem/task-lists/all.${subsystem}.opt_eq
            fi

            # Preparing the job files
            if  [[ "${toprepare}" == "jobs" ]] || [[ "${toprepare}" == "all" ]]; then
                hq_bs_prepare_jobfiles.sh batchsystem/task-lists/all.${subsystem}.opt_eq batchsystem/templates/jobfile.odyssey-requeue.slurm batchsystem/templates/subjob.general.sh b ${first_jid} 1 1 true true
            fi
        fi

        # Job type c
        if [[ "${jobtype}" == "c" ]]; then

            # Preparing the tasks
            if  [[ "${toprepare}" == "tasks" ]] || [[ "${toprepare}" == "all" ]]; then
                hq_bs_prepare_all_tasks.sh input-files/mappings/msp.all "hqf_gen_run_one_pipe.sh MSP ${subsystem} _allmd_ TDS" batchsystem/task-lists/all.${subsystem}.md
            fi

            # Preparing the job files
            if  [[ "${toprepare}" == "jobs" ]] || [[ "${toprepare}" == "all" ]]; then
                hq_bs_prepare_jobfiles.sh batchsystem/task-lists/all.${subsystem}.md batchsystem/templates/jobfile.odyssey-requeue.slurm batchsystem/templates/subjob.general.sh c ${first_jid} 1 1 true true
            fi
        fi

        # Job type d
        if [[ "${jobtype}" == "d" ]]; then

            # Preparing the tasks
            if  [[ "${toprepare}" == "tasks" ]] || [[ "${toprepare}" == "all" ]]; then
                hq_bs_prepare_all_tasks.sh input-files/mappings/msp.all "hqf_gen_run_one_pipe.sh MSP ${subsystem} _allce_allfec_" batchsystem/task-lists/all.${subsystem}.ce_fec
            fi

            # Preparing the job files
            if  [[ "${toprepare}" == "jobs" ]] || [[ "${toprepare}" == "all" ]]; then
                hq_bs_prepare_jobfiles.sh batchsystem/task-lists/all.${subsystem}.ce_fec batchsystem/templates/jobfile.odyssey-requeue.slurm batchsystem/templates/subjob.general.sh d ${first_jid} 1 1 true true
            fi
        fi
    done
done

# Printing final information
echo -e "\n * All batchsystem files have been prepared.\n\n"
