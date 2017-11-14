#!/usr/bin/env bash

#                                                                         SLURM Settings
####################################################################################################################################################################

#SBATCH --job-name=workflow_id_placeholder:jtl_placeholder.jid_placeholder.jsn_placeholder
#SBATCH --partition=serial_requeue
#SBATCH --time=07-00:00:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1000                                                   # Should be at least 60 seconds. Recommended value: 300 seconds
#SBATCH --signal=10@300
##SBATCH --constraint="scratch2"
##SBATCH --constraint="holyib"
#SBATCH --output=batchsystem/output-files/jtl-jtl_placeholder.jid-jid_placeholder.jsn-jsn_placeholder.main.bid-%j.out
#SBATCH --error=batchsystem/output-files/jtl-jtl_placeholder.jid-jid_placeholder.jsn-jsn_placeholder.main.bid-%j.out
#SBATCH --mail-user=cgorgulla@crystal.harvard.edu
#SBATCH --mail-type=none


#                                                                         HyperQ Variables
####################################################################################################################################################################

# Definition
HQ_JOBNAME=workflow_id_placeholder:jtl_placeholder.jid_placeholder.jsn_placeholder
HQ_WORKFLOW_ID=workflow_id_placeholder
HQ_JTL=jtl_placeholder
HQ_JID=jid_placeholder
HQ_JSN=jsn_placeholder
HQ_BID=${SLURM_JOB_ID}          # BID: Batchsystem ID

# Exportation
export HQ_JOBNAME
export HQ_WORKFLOW_ID
export HQ_JTL
export HQ_JID
export HQ_JSN
export HQ_BID


#                                                                  Printing Basic Job Information
####################################################################################################################################################################

echo
echo "                                                  *** Job Information ***                                                        "
echo "*********************************************************************************************************************************"
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
echo
echo


#                                                                          Main Job Work
####################################################################################################################################################################

# Cluster/Batchsystem specific preparations (e.g. module loading)
module load python/3.4.1-fasrc01                            # Provides the python3 executable needed by HQ
PATH="$HOME/anaconda2/bin:$PATH"                            # Restores the correct order of our PATH variable (which was changed by the python 3 module)

# Sourcing the common main section of the job files
source batchsystem/bin/job.main-1.sh
