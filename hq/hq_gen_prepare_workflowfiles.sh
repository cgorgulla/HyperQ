#!/usr/bin/env bash

# Usage information
usage="Usage: hq_gen_prepare_workflowfiles.sh

Prepares the input-files and batchsystem folder from the provided default files.

Has to be run in the root folder."

# Checking the input parameters
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
    echo "Exiting..."
    echo
    echo

    # Changing to the root folder
    for i in {1..10}; do
        if [ -d input-files ]; then

            # Setting the error flag
            touch runtime/${HQ_STARTDATE}/error
            exit 1
        else
            cd ..
        fi
    done

    # Printing some information
    echo "Error: Cannot find the input-files directory..."
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Verbosity
verbosity_preparation="$(grep -m 1 "^verbosity_preparation=" input-files/config.txt | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')" &>/dev/null || true      # the config file might not exist yet since this script might just prepare it
if [ "${verbosity_preparation}" = "debug" ]; then
    set -x
fi

# Checking the folder
if [ ! -d input-files ]; then
    echo
    echo -e " * Error: This script has to be run in the root folder. Exiting..."
    echo
    echo

    false
fi

# Checking if the variable HQ_ROOT is set
if [[ -z "${HQ_HOME}" ]]; then
    echo -e "\n * Error: The environment variable HQ_ROOT is not set. Exiting...\n\n"
    exit 1
fi

# Asking the user if the input-folder should be prepared
echo
while true; do
    echo
    read -p "Should the input-files folder be prepared? " answer
    case ${answer} in
        [Yy]* ) answer=true; break;;
        [Nn]* ) answer=false; break;;
        * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
    esac
done

# Checking the answer
if [ "${answer}" = "true" ]; then

    # Printing some information
    echo -e "\n\n *** Preparing the input-files folder ***\n"

    ### Config files ###
    # Asking if the config-files should be prepared
    echo
    while true; do
        echo
        read -p "Should the config files of the input-files folder be prepared (replacing existing files)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the input-files/iqi folder"

        # Copying the files
        cp ${HQ_HOME}/workflow-files/input-files/config.* input-files/
    fi

    ### CP2K input-files folder ###
    # Asking if the CP2K folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the input-files/cp2k folder be prepared (replacing existing files & folders)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the input-files/cp2k folder"

        # Removing the old files and folders
        rm -r input-files/cp2k &> /dev/null || true

        # Copying the files
        cp -r ${HQ_HOME}/workflow-files/input-files/cp2k input-files/
    fi

    ### i-PI input-files folder ###
    # Asking if the i-PI folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the input-files/ipi folder be prepared (replacing existing files & folders)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the input-files/ipi folder"

        # Removing the old files and folders
        rm -r input-files/ipi &> /dev/null || true

        # Copying the files
        cp -r ${HQ_HOME}/workflow-files/input-files/ipi input-files/
    fi

    ### i-QI input-files folder ###
    # Asking if the i-QI folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the input-files/iqi folder be prepared (replacing existing files & folders)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the input-files/iqi folder"

        # Removing the old files and folders
        rm -r input-files/iqi &> /dev/null || true

        # Copying the files
        cp -r ${HQ_HOME}/workflow-files/input-files/iqi input-files/
    fi
fi


# Asking the user if the batchsystem-folder should be prepared
echo
while true; do
    echo
    read -p "Should the batchsystem folder be prepared?" answer
    case ${answer} in
        [Yy]* ) answer=true; break;;
        [Nn]* ) answer=false; break;;
        * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
    esac
done

# Checking the answer
if [ "${answer}" = "true" ]; then

    # Printing some information
    echo -e "\n\n *** Preparing the batchsystem folder ***\n"

    ### Tasks folder ###
    # Asking if the tasks folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the batchsystem/task-lists folder be prepared (replacing existing files & folders)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/tasks folder"

        # Removing the old files and folders
        rm -r batchsystem/task-lists &> /dev/null || true

        # Copying the files
        cp -r ${HQ_HOME}/workflow-files/batchsystem/task-lists batchsystem/
    fi

    ### Template files folder ###
    # Asking if the templates folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the batchsystem/templates folder be prepared (replacing existing files & folders)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/templates folder"

        # Removing the old files and folders
        rm -r batchsystem/templates &> /dev/null || true

        # Copying the files
        cp -r ${HQ_HOME}/workflow-files/batchsystem/templates batchsystem/
    fi

    ### bin folder ###
    # Asking if the bin folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the batchsystem/bin folder be prepared (replacing existing files & folders)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/bin folder"

        # Removing the old files and folders
        rm -r batchsystem/bin &> /dev/null || true

        # Copying the files
        cp -r ${HQ_HOME}/workflow-files/batchsystem/bin batchsystem/
    fi

    ### Control folder ###
    # Asking if the control folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the batchsystem/control folder be prepared (replacing existing files & folders)? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/control folder"

        # Removing the old files and folders
        rm -r batchsystem/control &> /dev/null || true

        # Copying the files
        cp -r ${HQ_HOME}/workflow-files/batchsystem/control batchsystem/
    fi


    ### Jobfiles folder ###
    # Asking if the control folder should be prepared
    echo
    while true; do
        echo
        read -p "Should the batchsystem/job-files folder be deleted if it exists? " answer
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [ "${answer}" = "true" ]; then

        # Printing some information
        echo -e " * Deleting the batchsystem/job-files folder if it exists"

        # Removing the old files and folders
        rm -r batchsystem/job-files &> /dev/null || true
    fi

fi


# Displaying some information
echo -e "\n\n * The preparation of the files and folders has been completed\n\n"
