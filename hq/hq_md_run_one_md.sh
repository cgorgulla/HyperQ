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
    # Printing some information
    echo
    echo "An error was trapped" 1>&2
    echo "The error occured in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occured on line $1" 1>&2
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then
            # Setting the error flag
            mkdir -p runtime
            echo "" > runtime/error
            exit 1
        else
            cd ..
        fi
    done

    # Printing some information
    echo "Error: Cannot find the input-files directory..."
}
trap 'error_response_std $LINENO' ERR

# Exit cleanup
cleanup_exit() {
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.${subsystem}.*.${md_name/md.}  > /dev/null 2>&1 || true

    # Terminating all child processes
    for pid in "${pids[@]}"; do
        kill "${pid}"  1>/dev/null 2>&1 || true
    done
    pkill -P $$ || true
    sleep 5
    for pid in "${pids[@]}"; do
        kill -9 "${pid}"  1>/dev/null 2>&1 || true
    done
    pkill -9 -P $$ || true
}
trap "cleanup_exit" EXIT

# Bash options
set -o pipefail

# Variables
system_name="$(pwd | awk -F '/' '{print     $(NF-2)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-1)}')"
md_name="$(pwd | awk -F '/' '{print $(NF)}')"
md_programs="$(grep -m 1 "^md_programs_${subsystem}=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
md_timeout="$(grep -m 1 "^md_timeout_${subsystem}=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
md_continue="$(grep -m 1 "^md_continue=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
runtimeletter="$(grep -m 1 "^runtimeletter=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
run=$(grep "output.*ipi.out.run" ipi/ipi.in.md.xml | grep -o "run[0-9]*" | grep -o "[0-9]*")
sim_counter=0

# Running ipi
if [[ "${md_programs}" == *"ipi"* ]]; then
    cd ipi
    echo " * Cleaning up the ipi folder"
    if [ ${md_continue^^} == "FALSE" ]; then
        rm ipi.out* > /dev/null 2>&1 || true
    fi
    rm ipi.out.run${run}* > /dev/null 2>&1 || true
    rm *RESTART* > /dev/null 2>&1 || true
    rm /tmp/ipi_ipi.${runtimeletter}.md.${system_name}.${subsystem}.*.${md_name/md.}  > /dev/null 2>&1 || true

    echo " * Starting ipi"
    stdbuf -oL ipi ipi.in.md.xml > ipi.out.run${run}.screen 2>> ipi.out.run${run}.err &
    pid=$!
    pids[${sim_counter}]=$pid
    echo "${pid} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/md
    sim_counter=$((sim_counter+1))
    cd ..
    sleep 10
fi

# Running CP2K
if [[ "${md_programs}" == *"cp2k"* ]]; then
    # Variables
    ncpus_cp2k_md="$(grep -m 1 "^ncpus_cp2k_md_${subsystem}=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    for bead_folder in $(ls cp2k/); do
        cd cp2k/${bead_folder}
        echo " * Cleaning up the cp2k folder"
        if [ ${md_continue^^} == "FALSE" ]; then
            rm cp2k.out* > /dev/null 2>&1 || true
        fi
        rm cp2k.out.run${run}* > /dev/null 2>&1 || true
        rm system* > /dev/null 2>&1 || true
        echo " * Starting cp2k (${bead_folder})"
        ${cp2k_command} -e cp2k.in.md > cp2k.out.run${run}.config 2>cp2k.out.run${run}.err
        OMP_NUM_THREADS=${ncpus_cp2k_md} ${cp2k_command} -i cp2k.in.md -o cp2k.out.run${run}.general > cp2k.out.run${run}.screen 2>cp2k.out.run${run}.err &
        pid=$!
        pids[${sim_counter}]=$pid
        echo "${pid} " >> ../../../../../../runtime/pids/${system_name}_${subsystem}/md
        sim_counter=$((sim_counter+1))
        cd ../../
        i=$((i+1))
        sleep 1
    done
fi

# Running i-QI
if [[ "${md_programs}" == *"iqi"* ]]; then
    cd iqi
    echo " * Cleaning up the iqi folder"
    if [ ${md_continue^^} == "FALSE" ]; then
        rm iqi.out.* > /dev/null 2>&1 || true
    fi
    rm iqi.out.run${run}* > /dev/null 2>&1 || true
    echo " * Starting iqi"
    stdbuf -oL iqi iqi.in.xml > iqi.out.run${run}.screen 2> iqi.out.run${run}.err &
    pid=$!
    pid_ipi=${pid}
    pids[${sim_counter}]=$pid
    echo "${pid} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/md
    sim_counter=$((sim_counter+1))
    cd ../
fi

# Running NAMD
if [[ "${md_programs}" == "namd" ]]; then
    cd namd
    # ncpus_namd_md="$(grep -m 1 "^ncpus_namd_md=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    namd_command="$(grep -m 1 "^namd_command=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    ${namd_command} namd.in.md > namd.out.run${run}.screen 2>namd.out.run${run}.err & # removed +idlepoll +p${ncpus_namd_md}
    pid=$!
    pids[${sim_counter}]=$pid
    echo "${pid} " >> ../../../../../runtime/pids/${system_name}_${subsystem}/md
    sim_counter=$((sim_counter+1))
    cd ..
fi

# Checking if the simulation is completed/crashed
stop_flag="false"
while true; do
    if [ -f ipi/ipi.out.run${run}.screen ]; then
        timeDiff=$(($(date +%s) - $(date +%s -r ipi/ipi.out.run${run}.screen)))
        if [ "${timeDiff}" -ge "${md_timeout}" ]; then
            stop_flag="true"
        else
            sleep 1 || true
        fi
    fi
    if [ -f ipi/ipi.out.run${run}.err ]; then
        error_count="$( ( grep -i error ipi/ipi.out.err || true ) | wc -l)"
        if [ ${error_count} -ge "1" ]; then
            echo -e "Error detected in the file ipi.out.run${run}.err"
            false
        fi
    fi
    for bead_folder in $(ls cp2k/); do
        if [ -f cp2k/${bead_folder}/cp2k.out.run${run}.err ]; then
            error_count="$( ( grep -i error cp2k/${bead_folder}/cp2k.out.run${run}.err || true ) | wc -l)"
            if [ ${error_count} -ge "1" ]; then
                echo -e "Error detected in the file cp2k/${bead_folder}/cp2k.out.run${run}.err"
                false
            fi
        fi
    done

    sleep 1 || true
    if [ "${stop_flag}" == "true" ]; then
        kill  %1 2>&1 1>/dev/null || true
        exit 0
    fi
done

# We only wait for ipi
wait ${pid_ipi}  #|| true