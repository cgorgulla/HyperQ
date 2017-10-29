#!/usr/bin/env bash
# ---------------------------------------------------------------------------

# Slurm Settings
###############################################################################

#SBATCH --job-name=runtimeletter-mainjob_id_placeholder
#SBATCH --mail-user=cgorgulla@crystal.harvard.edu
#SBATCH --mail-type=fail
#SBATCH --time=00-01:00:00
#SBATCH --mem-per-cpu=600
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=main
#SBATCH --output=batchsystem/output-files/job-mainjob_id_placeholder.main.%j.out           # File to which standard out will be written
#SBATCH --error=batchsystem/output-files/job-mainjob_id_placeholder.main.%j.out            # File to which standard err will be written
#SBATCH --signal=10@300 
##SBATCH --constraint="scratch2"


# Job Information
##################################################################################
echo
echo "                    *** Job Information ***                    "
echo "==============================================================="
echo 
echo "Environment variables"
echo "------------------------"
env
echo
echo
echo
echo "Job infos by scontrol"
echo "------------------------"
scontrol show job $SLURM_JOB_ID


# Running the Job - Screening of the Ligands
######################################################################
echo
echo "                    *** Job Output ***                    "
echo "==========================================================="
echo

# Functions
# Standard error response 
error_response_std() {
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo "Environment variables" 1>&2 
    echo "----------------------------------" 1>&2
    env 1>&2
}
trap 'error_response_std $LINENO' ERR

# Handling signals
time_near_limit() {
    echo "The script ${BASH_SOURCE[0]} caught a time limit signal. Trying to start a new job."
}
trap 'time_near_limit' 10

termination_signal() {
    echo "The script ${BASH_SOURCE[0]} caught a termination signal. Stopping job."
    exit 1
}
trap 'termination_signal' 1 2 3 9 12 15

# Printing final job information
print_job_infos_end() {
    # Job information
    echo
    echo "                     *** Final Job Information ***                    "
    echo "======================================================================"
    echo
    echo "Starting time:" $STARTINGTIME
    echo "Ending time:  " $(date)
    echo
}

# Work to be done by the job

#main_code_placeholder

wait


# Printing final information
print_job_infos_end
