#!/usr/bin/env bash 

# Usage information
usage="Usage: hq_md_run_one_md.sh

Has to be run in the md main folder."

# Checking the input arguments
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
    echo "Number of expected arguments: 0"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Standard error response
error_response_std() {
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    # kill -- -$$
    for pid in ${pids_cp2k[@]}; do
        kill $pid
    done
    kill ${pid_ipi}
    exit 1 
}
trap 'error_response_std $LINENO' ERR

# Exit cleanup
cleanup_exit() {
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.*.${md_name/md.k_}  > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.ipi  > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.iqi  > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.cp2k  > /dev/null 2>&1 || true    kill 0 1>/dev/null 2>&1 || true  # Stops the proccesses of the same process group as the calling process
    sleep 1
    kill -9 0 1>/dev/null 2>&1 || true  # Stops the proccesses of the same process group as the calling process
}
trap "cleanup_exit" EXIT

# Variables
system_name="$(pwd | awk -F '/' '{print     $(NF-2)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-1)}')"
md_name="$(pwd | awk -F '/' '{print $(NF)}')"
md_programs="$(grep -m 1 "^md_programs=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
md_timeout="$(grep -m 1 "^md_timeout=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"

# Running ipi
if [[ "${md_programs}" == *"ipi"* ]]; then
    cd ipi
    echo " * Starting ipi"
    rm ipi.out.* > /dev/null 2>&1 || true
    rm *RESTART* > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.*.${md_name/md.k_}  > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.ipi  > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.iqi  > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.cp2k  > /dev/null 2>&1 || true
    ipi ipi.in.md.xml > ipi.out.screen 2> ipi.out.err &
    pid_ipi=$!
    cd ..
    sleep 10
fi

# Running CP2K1
if [[ "${md_programs}" == *"cp2k"* ]]; then
    # Variables
    ncpus_cp2k_md="$(grep -m 1 "^ncpus_cp2k_md=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    bead_counter=0
    for bead_folder in $(ls cp2k/); do
        echo " * Starting cp2k (${bead_folder})"
        cd cp2k/${bead_folder}
        rm cp2k.out* > /dev/null 2>&1 || true
        rm system* > /dev/null 2>&1 || true
        ${cp2k_command} -e cp2k.in.md > cp2k.out.config 2>cp2k.out.config.err
        OMP_NUM_THREADS=${ncpus_cp2k_md} cp2k -i cp2k.in.md -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
        pids_cp2k[${bead_counter}]=$!
        cd ../../
        i=$((i+1))
    done
fi

# Running i-QI
if [[ "${md_programs}" == *"iqi"* ]]; then
    cd iqi
    echo " * Starting iqi"
    rm iqi.out.* > /dev/null 2>&1 || true
    iqi iqi.in.xml > iqi.out.screen 2> iqi.out.err &
    pid_iqi=$!
    sim_counter=$((sim_counter+1))
    cd ../
fi

# Running NAMD
if [[ "${md_programs}" == "namd" ]]; then
    cd namd
    # ncpus_namd_md="$(grep -m 1 "^ncpus_namd_md=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    namd_command="$(grep -m 1 "^namd_command=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    ${namd_command} namd.in.md > namd.out.screen 2>namd.out.err & # removed +idlepoll +p${ncpus_namd_md}    
    cd ..
fi

# Checking if the simulation is completed/crashed
while true; do
    if [ -f ipi/ipi.out.screen ]; then
        timeDiff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.screen)))
        if [ "${timeDiff}" -ge "${md_timeout}" ]; then
            kill  %1 2>&1 1>/dev/null|| true
            break
        else
            sleep 1
        fi
    fi
    if [ -f ipi/ipi.out.properties ]; then
        timeDiff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.properties)))
        if [ "${timeDiff}" -ge "${md_timeout}" ]; then
            kill  %1 2>&1 1>/dev/null|| true
            break
        else
            sleep 1
        fi
        sleep 1
    fi
done

# We only wait for ipi
wait ${pid_ipi}  #|| true