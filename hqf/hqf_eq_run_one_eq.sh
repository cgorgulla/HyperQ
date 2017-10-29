#!/usr/bin/env bash 

# Usage infomation
usage="Usage: hqf_eq_run_one_eq.sh

Has to be run in the eq root folder of the system."

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
    exit 1
}
trap 'error_response_std $LINENO' ERR SIGINT SIGQUIT SIGTERM

# Exit cleanup
cleanup_exit() {

    echo
    echo " * Cleaning up..."
    # Terminating all processes
    echo " * Terminating remaining processes..."
    # Terminating the child processes of the main processes
    for pid in ${pids[*]}; do
        pkill -P "${pid}" 1>/dev/null 2>&1 || true
    done
    sleep 3
    for pid in ${pids[*]}; do
        pkill -9 -P "${pid}"  1>/dev/null 2>&1 || true
    done
    # Terminating the main processes
    for pid in ${pids[*]}; do
        kill "${pid}" 1>/dev/null 2>&1 || true
    done
    sleep 3
    for pid in ${pids[*]}; do
        kill -9 "${pid}"  1>/dev/null 2>&1 || true
    done
    sleep 1
    # Terminating everything else which is still running and which was started by this script
    pkill -P $$ || true
    sleep 3
    pkill -9 -P $$ || true
}
trap "cleanup_exit" EXIT

# Bash options
set -o pipefail


# Verbosity
verbosity="$(grep -m 1 "^verbosity=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
export verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Variables
subsystem="$(pwd | awk -F '/' '{print $(NF-2)}')"
eq_programs=$(grep -m 1 "^eq_programs_${subsystem}=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')
eq_timeout=$(grep -m 1 "^eq_timeout_${subsystem}=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')
system_name="$(pwd | awk -F '/' '{print     $(NF-3)}')"
sim_counter=0

# Running the equilibration
# CP2K
if [[ "${eq_programs}" == "cp2k" ]] ;then
    # Cleaning the folder
    rm cp2k.out* 1>/dev/null 2>&1 || true
    rm system*  1>/dev/null 2>&1 || true
    ncpus_cp2k_eq="$(grep -m 1 "^ncpus_cp2k_eq_${subsystem}=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../../input-files/config.txt | awk -F '=' '{print $2}')"
    ${cp2k_command} -e cp2k.in.main 1> cp2k.out.config 2> cp2k.out.err
    export OMP_NUM_THREADS=${ncpus_cp2k_eq}
    ${cp2k_command} -i cp2k.in.main -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
    pid_cp2k=$!
    pids[sim_counter]=$pid_cp2k
    sim_counter=$((sim_counter+1))
    echo "${pid}" >> ../../../../../runtime/pids/${system_name}_${subsystem}/eq
    #echo "CP2K PID PPID: $pid $(ps -o ppid $pid | grep -o "[0-9]*")"
    #echo "Shell PID PPID: $$ $(ps -o ppid $$ | grep -o "[0-9]*")"

    # Checking if the file system-r-1.out does already exist.
    while [ ! -f cp2k.out.general ]; do
        echo " * The file system.out.general does not exist yet. Waiting..."
        sleep 1
    done
    echo " * The file system.out.general has been detected. Continuing..."
fi

# Checking if the simulation is completed
while true; do

    # Checking the condition of the ouptput files of CP2k
    if [ -f cp2k.out.general ]; then
        timeDiff=$(($(date +%s) - $(date +%s -r cp2k.out.general)))
        if [ "${timeDiff}" -ge "${eq_timeout}" ]; then
            echo " * CP2K seems to have completed the equilibration."
            break
        fi
    fi
    # Checking for memory error - happens often at the end of runs it seems, thus we treat it as a successful run
    if [ -f cp2k.out.err ]; then
        #pseudo_error_count="$( { grep -E "invalid memory reference|SIGABRT" cp2k.out.err || true; } | wc -l)"
        pseudo_error_count="$( { grep -E "invalid memory reference|corrupted double-linked|Caught|invalid size" cp2k.out.err || true; } | wc -l)"
        if [ "${pseudo_error_count}" -ge "1" ]; then
            echo " * CP2K seems to have completed the equilibration."
            break
        fi
    fi
    if [ -f cp2k.out.err ]; then
        error_count="$( { grep -i error cp2k.out.err || true; } | wc -l)"
        if [ ${error_count} -ge "1" ]; then
            set +o pipefail
            backtrace_length="$(grep -A 100 Backtrace cp2k.out.err | grep -v Backtrace | wc -l)"
            set -o pipefail
            if [ "${backtrace_length}" -ge "1" ]; then
                echo -e "Error detected in the file cp2k.out.err"
                echo -e "Contents of the file cp2k.out.err:"
                cat cp2k.out.err | awk '{print "cp2k.out.err: " $0}'
                echo
                exit 1
            else
                break
            fi
        fi
    fi

    # Checking if CP2K has terminated (hopefully wihtout error after the previous error checks)
    if [ ! -e /proc/${pid_cp2k} ]; then
        echo " * CP2K seems to have terminated without errors."
        break
    fi

    # Sleeping shortly before next round
    sleep 1 || true             # true because the script might be terminated while sleeoping, which would result in an error
done