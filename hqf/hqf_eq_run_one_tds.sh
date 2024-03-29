#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_eq_run_one_tds.sh

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
    echo "Reason: The wrong number of arguments was provided when calling the script."
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
    echo "The error occurred in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "The error occurred on line $1" 1>&2
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE_BS}/error.pipeline
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
    if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then

        echo -e "\n * Information about all jobs of the user: \n"
        ps -fu $USER

        echo -e "\n * The following jobs processes will be terminated: \n"
        echo
        pgrep ${pids[*]} | xargs ps -o pid,pgid,ppid,command
        echo
        pgrep ${pids[*]} | xargs pwdx
        echo
        pgrep -P ${pids[*]} | xargs ps -o pid,pgid,ppid,command
        echo
        pgrep -P ${pids[*]} | xargs pwdx
        echo
        pgrep -P $$ | xargs ps -o pid,pgid,ppid,command
        echo
        pgrep -P $$ | xargs pwdx
        echo
    fi

    # Running the termination in an own process group to prevent it from preliminary termination. Since it will run in the background it will not cause any delays
    setsid nohup bash -c "

        # Trapping signals
        trap '' SIGINT SIGQUIT SIGTERM SIGHUP ERR

        # Terminating the main processes
        kill ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 5 || true
        kill -9 ${pids[*]} 1>/dev/null 2>&1 || true

        # Terminating the child processes of the main processes
        pkill -P ${pids[*]} 1>/dev/null 2>&1 || true
        sleep 1 || true
        pkill -9 -P ${pids[*]} 1>/dev/null 2>&1 || true

        # Terminating everything else which is still running and which was started by this script, which will include the current exit-code
        pkill -P $$ || true
        sleep 1
        pkill -9 -P $$ || true
    " &> /dev/null || true
}
trap "cleanup_exit" EXIT

# Bash options
set -o pipefail

# Config file setup
if [[ -z "${HQ_CONFIGFILE_MSP}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_MSP was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_MSP=input-files/config/general.txt
    export HQ_CONFIGFILE_MSP
fi

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ../../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
tds_folder="$(pwd | awk -F '/' '{print $(NF)}')"
subsystem="$(pwd | awk -F '/' '{print $(NF-1)}')"
msp_name="$(pwd | awk -F '/' '{print     $(NF-2)}')"
eq_programs=$(grep -m 1 "^eq_programs_${subsystem}=" ../../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')
eq_timeout=$(grep -m 1 "^eq_timeout_${subsystem}=" ../../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')
eq_continue=$(grep -m 1 "^eq_continue=" ../../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')
sim_counter=0

# Checking if this equilibration has already been completed and should be skipped
if [[ ${eq_continue^^} == "TRUE" && -f  ../system.${tds_folder//tds.}.eq.pdb ]]; then

    # Printing some information
    echo -e " * This equilibration has already been completed. Skipping... (continuation mode)\n"

    # Exiting
    exit 0
fi

# Running the equilibration
# CP2K
if [[ "${eq_programs}" == "cp2k" ]] ;then

    # Changing into the simulation folder
    cd cp2k

    # Cleaning the folder
    if [ ${eq_continue^^} == "FALSE" ]; then
        rm cp2k.out* > /dev/null 2>&1 || true
    elif [ -f cp2k.out.err ]; then
        # Renaming previous error files
        mv cp2k.out.err cp2k.out.err.old."$(date --rfc-3339=seconds | tr -s ' ' '_')"
    fi

    # Variables
    ncpus_cp2k_eq="$(grep -m 1 "^ncpus_cp2k_eq_${subsystem}=" ../../../../../${HQ_CONFIGFILE_MSP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    cp2k_command="$(grep -m 1 "^cp2k_command=" ../../../../../${HQ_CONFIGFILE_MSP} | awk -F '[=#]' '{print $2}')"
    export OMP_NUM_THREADS=${ncpus_cp2k_eq}

    # Checking the input file
    ${cp2k_command} -e cp2k.in.main 1> cp2k.out.config 2> cp2k.out.err

    # Starting CP2K
    ${cp2k_command} -i cp2k.in.main -o cp2k.out.general > cp2k.out.screen 2>cp2k.out.err &
    pid_cp2k=$!

    # Updating variables
    pids[sim_counter]=$pid_cp2k
    sim_counter=$((sim_counter+1))
    
    # Changing back to the original folder
    cd ..
fi

# Checking if the simulation is
sleep 5
while true; do

    # Printing some information
    if [ "${HQ_VERBOSITY_RUNTIME}" == "debug" ]; then
        echo " * Checking if the simulation running in folder ${PWD} has completed or should be terminated."
    fi

    # Checking if the workflow is run by the BS module
    if [ -n "${HQ_BS_JOBNAME}" ]; then

        # Determining the control file responsible for us
        cd ../../../../
        controlfile="$(hqh_bs_controlfile_determine.sh ${HQ_BS_JTL} ${HQ_BS_JID})"

        # Getting the relevant value
        terminate_job="$(hqh_gen_inputfile_getvalue.sh ${controlfile} terminate_job true)"
        cd -

        # Checking the value
        if [ "${terminate_job^^}" == "TRUE" ]; then

            # Printing some information
            echo " * According to the controlfile ${controlfile} the current batchsystem job should be terminated immediately. Stopping this simulation and exiting..."

            # Exiting
            exit 0
        fi
    fi

    # Checking for errors
    if [[ -s cp2k/cp2k.out.err ]] ; then
        if [ -f cp2k/cp2k.out.trajectory.pdb ]; then

            # Checking the number of frames. During MD simulations CP2K stores the initial conformation, thus Step 0 is always present, therefore we require at least two frames
            frame_count=$(grep -c Step cp2k/cp2k.out.trajectory.pdb)
            if [ "${frame_count}" -ge "2" ]; then
                echo " * Warning: CP2K seems to have completed with errors, but has produced the desired trajectories file which contains ${frame_count} coordinate frames. Continuing..."
                break
            else
                echo " * Error: CP2K seems to have completed with errors, and the trajectory output file seems not to contain any coordinate frames. Exiting..."
                exit 1
            fi
        else
            echo " * Error: CP2K seems to have completed with errors, and has not produced any trajectory output file. Exiting..."
            exit 1
        fi
    fi

    # Checking if CP2K has terminated (hopefully without error after the previous error checks)
    if [ ! -e /proc/${pid_cp2k} ]; then
        echo " * CP2K seems to have terminated without errors."
        break
    fi

    # Checking the condition of the output major log file of CP2k
    if [ -f cp2k/cp2k.out.general ]; then

        # Variables
        time_diff=$(($(date +%s) - $(date +%s -r cp2k/cp2k.out.general)))

        # Checking the time difference with upper bound because very few times it seems that something goes wrong and the time_diff is extremely large
        if [[ "${time_diff}" -ge "${eq_timeout}" ]] && [ "${time_diff}" -le "$((${eq_timeout} + 30))" ]; then

            # Printing message
            echo " * CP2K seems to have completed the equilibration."
            break
        elif [[ "${time_diff}" -ge "$((eq_timeout+30))" ]]; then

            # If the time diff is larger, then the workflow will most likely have been suspended and has now been resumed
            touch cp2k/cp2k.out.general
        fi
    fi

    # Sleeping shortly before next round
    sleep 10 || true             # true because the script might be terminated while sleeping, which would result in an error

done

# Printing script completion information
echo -e "\n * The equilibration run of the current TDS (${tds_folder}) of MSP (${msp_name}) has been completed.\n\n"
