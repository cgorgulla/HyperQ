#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_md_run_one_md.sh

Has to be run in the simulation main folder."

# Checking the arguments
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "0" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Expected arguments: 0"
    echo "Provided arguments: ${#}"
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
#    trap - SIGTERM && kill -- -$$
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Exit cleanup
cleanup_exit() { 
    rm /tmp/ipi_ipi.ce.${msp_name}.*.${crosseval_folder}.snapshot-${snapshotCount}  > /dev/null 2>&1 || true
    kill 0  # Stops the proccesses of the same process group as the calling process
}
trap "cleanup_exit" EXIT

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
ncpus_cp2k_ce="$(grep ncpus_cp2k_ce ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-3)}')"
crosseval_folder="$(pwd | awk -F '/' '{print $(NF-1)}')"
snapshot_name="$(pwd | awk -F '/' '{print $(NF)}')"
snapshotCount=${snapshot_name/*-}
ce_type="$(grep -m 1 "^md_type=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
ce_timeout="$(grep -m 1 "^ce_timeout=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"

# ipi
cd ipi
echo -e " * Starting ipi"
rm ipi.out.* > /dev/null 2>&1 || true 
rm *RESTART* > /dev/null 2>&1 || true 
msp_name="$(pwd | awk -F '/' '{print $(NF-4)}')"
rm /tmp/ipi_ipi.ce.${msp_name}.*.${crosseval_folder}.snapshot-${snapshotCount}  > /dev/null 2>&1 || true
ipi ipi.in.ce.xml > ipi.out.screen 2> ipi.out.err &
pid_ipi=$!    
cd ..
sleep 5

# CP2K
sim_counter=0
for bead_folder in $(ls cp2k/); do 
    echo -e " * Starting cp2k (${bead_folder})"
    cd cp2k/${bead_folder}/
    rm cp2k.out* > /dev/null 2>&1 || true 
    rm system* > /dev/null 2>&1 || true
    cp2k -e cp2k.in.md > cp2k.out.config 2>cp2k.out.config.err
    export OMP_NUM_THREADS=${ncpus_cp2k_ce}
    # timeout -s SIGTERM ${ce_timeout} cp2k -i cp2k.in.md -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
    cp2k -i cp2k.in.md -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
    pids_cp2k[${sim_counter}]=$!
    cd ../../
    sim_counter=$((sim_counter+1))
done

# i-QI
if [ "${ce_type^^}" == "QMMM" ]; then    
    cd iqi
    echo -e " * Starting iqi"
    rm iqi.out.* > /dev/null 2>&1 || true 
    iqi iqi.in.xml > iqi.out.screen 2> iqi.out.err &
    pids_iqi[${sim_counter}]=$!
    sim_counter=$((sim_counter+1))
    cd ../
fi

# Checking if the simulation is completed/crashed
while true; do
    if [ -f ipi/ipi.out.screen ]; then
        timeDiff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.screen)))
        if [ "${timeDiff}" -ge "${ce_timeout}" ]; then
            kill  %1 2>&1 1>/dev/null|| true
            break
        else
            sleep 1
        fi
    else
        sleep 1
    fi
done

# We only wait for ipi
wait ${pid_ipi}  || true

echo " * Snapshot completed"
