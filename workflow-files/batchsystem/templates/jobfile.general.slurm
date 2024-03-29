#!/usr/bin/env bash

#                                                                         SLURM Settings
####################################################################################################################################################################

#SBATCH --job-name=workflow_id_placeholder:jtl_placeholder.jid_placeholder.jsn_placeholder
#SBATCH --partition=main
#SBATCH --time=07-00:00:00
#SBATCH --nodes=1       # Todo: extension to multiple tasks (-n option) (we don't need it personally)
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
HQ_BS_JOBNAME=workflow_id_placeholder:jtl_placeholder.jid_placeholder.jsn_placeholder
HQ_WORKFLOW_ID=workflow_id_placeholder
HQ_BS_JTL=jtl_placeholder
HQ_BS_JID=jid_placeholder
HQ_BS_JSN=jsn_placeholder
HQ_BS_BID=${SLURM_JOB_ID}          # BID: Batchsystem ID

# Exportation
export HQ_BS_JOBNAME
export HQ_WORKFLOW_ID
export HQ_BS_JTL
export HQ_BS_JID
export HQ_BS_JSN
export HQ_BS_BID


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

# Sourcing the common main section of the job files
source batchsystem/bin/job.main-1.sh
