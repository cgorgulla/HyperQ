#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_bs_jobfile_sync_controlfile.sh <job-type-letter> <job ID>

Determines the responsible control file and syncs the settings with the corresponding jobfile in the batchsystem/job-files/main/ folder.

Arguments:
    <job-type-letter>: The job-type-letter (JTL) corresponding to the jobs to be started (a lower case letter between a and j)

    <job ID>: Natural number

Has to be run in the root folder."

# Checking the input parameters
if [ "${1}" == "-h" ]; then

    # Printing user information
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "2" ]; then

    # Printing error information
    echo 1>&2
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Reason: The wrong number of arguments was provided when calling the script." 1>&2
    echo "Number of expected arguments: 2" 1>&2
    echo "Number of provided arguments: ${#}" 1>&2
    echo "Provided arguments: $@" 1>&2
    echo 1>&2
    echo -e "$usage" 1>&2
    echo 1>&2
    echo 1>&2
    exit 1
fi

# Verbosity
# Checking if standalone mode (-> non-runtime)
if [[ -z "${HQ_VERBOSITY_RUNTIME}" && -z "${HQ_VERBOSITY_NONRUNTIME}" ]]; then

    # Variables
    export HQ_VERBOSITY_NONRUNTIME="$(grep -m 1 "^verbosity_nonruntime=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

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

# Standard error response 
error_response_std() {

    # Printing some information
    echo 1>&2
    echo "An error was trapped" 1>&2
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
    echo "Working directory: $PWD"
    echo "Exiting..." 1>&2
    echo 1>&2
    echo 1>&2

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Variables
jtl=${1}
jid=${2}
batchsystem="$(hqh_gen_inputfile_getvalue.sh input-files/config.txt batchsystem true)"
controlfile="$(hqh_bs_controlfile_determine.sh ${jtl} ${jid})"
cpus_per_subjob="$(hqh_gen_inputfile_getvalue.sh ${controlfile} cpus_per_subjob true)"
nodes_per_job="$(hqh_gen_inputfile_getvalue.sh ${controlfile} nodes_per_job true)"
partition="$(hqh_gen_inputfile_getvalue.sh ${controlfile} partition true)"
walltime="$(hqh_gen_inputfile_getvalue.sh ${controlfile} walltime true)"
memory_per_cpu="$(hqh_gen_inputfile_getvalue.sh ${controlfile} memory_per_cpu true)"
memory_per_job="$(hqh_gen_inputfile_getvalue.sh ${controlfile} memory_per_job true)"


# Checking if the job type letter is valid
if ! [[ "${jtl}" =~ ^[abcdefghij]$ ]]; then
    echo -e "\n * Error: The input argument 'job type letter' has an unsupported value. Exiting...\n\n" 1>&2
    exit 1
fi

# Adjusting the number of CPUs per subjob
if [ "${batchsystem}" = "slurm" ]; then
    sed -i "s/^#SBATCH \+--cpus-per-task=.*/#SBATCH --cpus-per-task=${cpus_per_subjob}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "mtp" ]; then
    sed -i "s/ppn=[0-9]\+/ppn=${cpus_per_subjob}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "lsf" ]; then
    sed -i "s/^#BSUB \+-n .*/#BSUB -n ${cpus_per_subjob}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
fi

# Adjusting the partition
if [ "${batchsystem}" = "slurm" ]; then
    sed -i "s/^#SBATCH \+--partition=.*/#SBATCH --partition=${partition}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "mtp" ]; then
    sed -i "s/^#PBS \+-q .*/#PBS -q ${partition}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "lsf" ]; then
    sed -i "s/^#BSUB \+-q .*/#BSUB -q ${partition}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "sge" ]; then
    sed -i "s/^#\\$ -q .*/#\$ -q ${partition}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
fi

# Adjusting the walltime
if [ "${batchsystem}" = "slurm" ]; then
    sed -i "s/^#SBATCH \+--time=.*/#SBATCH --time=${walltime}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "mtp" ]; then
    sed -i "s/^#PBS \+-l \+walltime=.*/#PBS -l walltime=${walltime}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "lsf" ]; then
    sed -i "s/^#BSUB \+-W .*/#BSUB -W ${walltime}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "sge" ]; then
    sed -i "s/^#\\$ -l h_rt=.*/#\$ -l h_rt=${walltime}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
fi

# Adjusting the number of nodes
if [ "${batchsystem}" = "slurm" ]; then
    sed -i "s/^#SBATCH \+--nodes=.*/#SBATCH --nodes=${nodes_per_job}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "mtp" ]; then
    sed -i "s/^#PBS \+-l \+nodes=.*:ppn/#PBS -l nodes ${nodes_per_job}:ppn/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
fi

# Adjusting the memory
if [ "${batchsystem}" = "slurm" ]; then
    sed -i "s/^#SBATCH \+--mem-per-cpu=.*/#SBATCH --mem-per-cpu=${memory_per_cpu}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "mtp" ]; then
    sed -i "s/^#PBS \+-l mem=.*/#PBS -l mem=${memory_per_job}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "lsf" ]; then
    sed -i "s/mem=.*/mem=${memory_per_job}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
elif [ "${batchsystem}" = "sge" ]; then
    sed -i "s/^#\\$ -l h_vmem=.*/#\$ -l h_vmem=${memory_per_cpu}/g" batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem}
fi

# Printing final job information
echo -e "\n * The jobfile batchsystem/job-files/main/jtl-${jtl}.jid-${jid}.${batchsystem} has been synced with the controlfile ${controlfile}\n"
