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
    rm /tmp/ipi_ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.*.${crosseval_folder}.restart-${snapshotCount} > /dev/null 2>&1 || true
    if [ "${verbosity}" = "debug" ]; then
        kill -9 0  || true # Stops the proccesses of the same process group as the calling process
    else
        kill -9 0 2>&1 1>/dev/null || true # Stops the proccesses of the same process group as the calling process
    fi
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
subsystem="$(pwd | awk -F '/' '{print $(NF-2)}')"
crosseval_folder="$(pwd | awk -F '/' '{print $(NF-1)}')"
snapshot_name="$(pwd | awk -F '/' '{print $(NF)}')"
snapshotCount=${snapshot_name/*-}
ce_type="$(grep -m 1 "^md_type=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
ce_timeout="$(grep -m 1 "^ce_timeout=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
snapshot_time_start=$(date +%s)

# ipi
cd ipi
echo -e " * Starting ipi"
rm ipi.out.* > /dev/null 2>&1 || true 
rm *RESTART* > /dev/null 2>&1 || true 
msp_name="$(pwd | awk -F '/' '{print $(NF-4)}')"
rm /tmp/ipi_ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.*.${crosseval_folder}.restart-${snapshotCount} > /dev/null 2>&1 || true
ipi ipi.in.ce.xml > ipi.out.screen 2> ipi.out.err &
pid_ipi=$!
echo "${pid_ipi} " >> ../../../../../../runtime/pids/${msp_name}_${subsystem}/ce
cd ..

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
    max_it=60
    iteration_no=0
    while true; do
        if [ -e "/tmp/ipi_ipi.${runtimeletter}.ce.${msp_name}.${subsystem}.cp2k.${crosseval_folder}.restart-${snapshotCount}" ]; then # -e for any fail, -f is only for regular files
            echo " * The socket file for snapshot ${snapshotCount} has been detected. Starting CP2K..."
            cp2k -i cp2k.in.md -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
            pids_cp2k[${sim_counter}]=$!
            echo "pids_cp2k[${sim_counter}] " >> ../../../../../../../runtime/pids/${msp_name}_${subsystem}/ce

            sim_counter=$((sim_counter+1))
            cd ../../
            break
        else
            if [ "$iteration_no" -lt "$max_it" ]; then
                echo " * The socket file for snapshot ${snapshotCount} does not yet exist. Waiting 1 second (iteration $iteration_no)..."
                sleep 1
                iteration_no=$((iteration_no+1))
            else
                echo " * The maxium number of iterations ($max_it) for snapshot ${snapshotCount} has been reached. Skipping this snapshot..."
                exit 1
            fi
        fi
    done
done

# i-QI
if [ "${ce_type^^}" == "QMMM" ]; then    
    cd iqi
    echo -e " * Starting iqi"
    rm iqi.out.* > /dev/null 2>&1 || true 
    iqi iqi.in.xml > iqi.out.screen 2> iqi.out.err &
    pids_iqi[${sim_counter}]=$!
    echo "pids_iqi[${sim_counter}] " >> ../../../../../../runtime/pids/${msp_name}_${subsystem}/ce
    sim_counter=$((sim_counter+1))
    cd ../
fi

# Checking if the simulation is completed/crashed
#while true; do
#    if [ -f ipi/ipi.out.screen ]; then
#        timeDiff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.screen)))
#        if [ "${timeDiff}" -ge "${ce_timeout}" ]; then
#            kill  %1 2>&1 1>/dev/null || true
#            break
#            exit 0
#        else
#            sleep 1
#        fi
#    else
#        sleep 1
#    fi
#done
waiting_time_start=$(date +%s)
while true; do
    if [ -f ipi/ipi.out.screen ]; then
        propertylines_count=$(grep -E "^ *[0-9]" ipi/ipi.out.properties | wc -l)
        if [ "${propertylines_count}" -eq "1" ]; then
             snapshot_time_total=$(($(date +%s) - ${snapshot_time_start}))
             echo " * Snapshot ${snapshotCount} completed after ${snapshot_time_total} seconds."
             exit 0
        fi
    fi
    waiting_time_diff=$(($(date +%s) - ${waiting_time_start}))
    if [ "${waiting_time_diff}" -ge "${ce_timeout}" ]; then
        echo " * CE-Timeout for snapshot ${snapshotCount} reached. Skipping this snapshot..."
        exit 1
    else
        sleep 1
    fi
done


## We only wait for ipi
#wait ${pid_ipi}  || true
#
#echo " * Snapshot completed"
