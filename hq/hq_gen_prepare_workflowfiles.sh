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
    echo "Working directory: $PWD"
    echo "Exiting..."
    echo
    echo

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail
shopt -s nullglob

# Checking if there is a general config file
verbosity_suffix=""
if [ -f input-files/config/general.txt ]; then

    # Getting the verbosity setting
    HQ_VERBOSITY_NONRUNTIME="$( grep -m 1 "^verbosity_nonruntime=" input-files/config/general.txt &>/dev/null | tr -d '[:space:]' | awk -F '[=#]' '{print $2}')"

    # Setting the verbosity
    if [ "${HQ_VERBOSITY_NONRUNTIME}" == "debug" ]; then
        set -x
        verbosity_suffix="v"
    fi
fi

# Checking if the variable HQ_HOME is set
if [[ -z "${HQ_HOME}" ]]; then
    echo -e "\n * Error: The environment variable HQ_HOME is not set. Exiting...\n\n"
    exit 1
fi

# Checking if we are in the root folder
if [ ! -d input-files ]; then

    # Since the input-folder might not exist yet, we inform the user that this has to be the root folder and give him a chance to abort
    echo -e "\n"
    read -p "This script has to be run in the root folder of the workflow. Press Enter to continue... "

fi
# Asking if everything should be prepared/cleaned up
echo
while true; do
    echo
    read -p "Should everything be prepared/cleaned up? " answer_cleanup_all
    echo
    case ${answer_cleanup_all} in
        [Yy]* ) answer_cleanup_all=true; break;;
        [Nn]* ) answer_cleanup_all=false; break;;
        * ) echo -e "Unsupported answer. Possible answers are 'yes' or 'no'";;
    esac
done

# Asking the user if the input-folder should be prepared
if [ ${answer_cleanup_all} == "false" ]; then
    while true; do
        echo
        read -p "Should the input-files folder be prepared? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi

# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Asking if the input-files folder should be removed if existent
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the input-files folder be removed if existent? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Removing the input-files folder if existent"

        # Removing the old files and folders
        rm -r input-files &> /dev/null || true
    fi

    # Preparing the input-files directory if not yet there
    mkdir -p input-files

    ### Config files ###
    # Asking if the config-files should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            read -p "Should the input-files/config folder be prepared (replacing existing files)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the input-files/config folder"

        # Copying the files. rsync source dest: If source is a folder with a backslash at the end, it will copy its contents only, the directory itself. If there is no backslash it will copy the root folder as well. cp -r always copies the root folder...
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/input-files/config input-files/
    fi

    ### Special atom files ###
    # Asking if the special-atoms files should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            read -p "Should the input-files/special-atoms folder be prepared (replacing existing files)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the input-files/special-atoms folder"

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/input-files/special-atoms input-files/
    fi

    ### CP2K input-files folder ###
    # Asking if the CP2K folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the input-files/cp2k folder be prepared (replacing existing files & folders)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the input-files/cp2k folder"

        # Removing the old files and folders
        rm -r input-files/cp2k &> /dev/null || true

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/input-files/cp2k input-files
    fi

    ### i-PI input-files folder ###
    # Asking if the i-PI folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the input-files/ipi folder be prepared (replacing existing files & folders)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the input-files/ipi folder"

        # Removing the old files and folders
        rm -r input-files/ipi &> /dev/null || true

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/input-files/ipi input-files
    fi

    ### i-QI input-files folder ###
    # Asking if the i-QI folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the input-files/iqi folder be prepared (replacing existing files & folders)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the input-files/iqi folder"

        # Removing the old files and folders
        rm -r input-files/iqi &> /dev/null || true

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/input-files/iqi input-files
    fi

    # Copying the system-related input files from another folder
    while true; do
        echo
        read -p "Should system-related input files (ligands, receptor, systems, mappings, special-atoms) be copied from another folder (replacing existing files)? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [[ "${answer}" = "true" ]] ; then

        # Loop for getting the user input
        while true; do

            # Printing some information
            echo
            read -e -p " Please specify the relative path of the input-file folder which contains the files to be copied (autocompletion available): " source_inputfiles_folder
            echo

            # Checking if the path exists
            echo -n " * Checking if the specified folder exists... "
            if [ -d ${source_inputfiles_folder} ]; then
                echo "OK"
                break;
            else
                echo "failed"
            fi
        done

        # Printing some information
        echo -e " * Copying the files..."

        # Copying the files
        if [ -d ${source_inputfiles_folder}/ligands ]; then
            rsync -a${verbosity_suffix} --exclude=".*" ${source_inputfiles_folder}/ligands input-files
        else
            echo " * Info: The folder ${source_inputfiles_folder}/ligands does not exist, skipping..."
        fi
        if [ -d ${source_inputfiles_folder}/receptor ]; then
            rsync -a${verbosity_suffix} --exclude=".*" ${source_inputfiles_folder}/receptor input-files
        else
            echo " * Info: The folder ${source_inputfiles_folder}/receptor does not exist, skipping..."
        fi
        if [ -d ${source_inputfiles_folder}/systems ]; then
            rsync -a${verbosity_suffix} --exclude=".*" ${source_inputfiles_folder}/systems input-files
        else
            echo " * Info: The folder ${source_inputfiles_folder}/systems does not exist, skipping..."
        fi
        if [ -d ${source_inputfiles_folder}/mappings ]; then
            rsync -a${verbosity_suffix} --exclude=".*" ${source_inputfiles_folder}/mappings input-files
        else
            echo " * Info: The folder ${source_inputfiles_folder}/mappings does not exist, skipping..."
        fi
        if [ -d ${source_inputfiles_folder}/special-atoms ]; then
            rsync -a${verbosity_suffix} --exclude=".*" ${source_inputfiles_folder}/special-atoms input-files
        else
            echo " * Info: The folder ${source_inputfiles_folder}/special-atoms does not exist, skipping..."
        fi
        echo
    fi

    # Copying the hyperq config files from another folder
    while true; do
        echo
        read -p "Should the hyperq config files be copied from another folder (replacing existing files)? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [[ "${answer}" = "true" ]] ; then

        # Loop for getting the user input
        while true; do

            # Printing some information
            echo
            read -e -p " Please specify the relative path of the folder which contains config-folder to be copied (autocompletion available): " source_inputfiles_folder
            echo

            # Checking if the path exists
            echo -n " * Checking if the specified folder exists... "
            if [ -d ${source_inputfiles_folder} ]; then
                echo "OK"
                break;
            else
                echo "failed"
            fi
        done

        # Printing some information
        echo -e " * Copying the input files of the specified folder..."

        # Copying the files
        if [ -d ${source_inputfiles_folder}/input-files/config ]; then
            rsync -a${verbosity_suffix} --exclude=".*" ${source_inputfiles_folder}/input-files/config input-files/
        else
            echo " * Info: The folder ${source_inputfiles_folder}/input-files/config does not exist, skipping..."
        fi
        echo
    fi
fi

# Asking the user if the batchsystem-folder should be prepared
if [ ${answer_cleanup_all} == "false" ]; then

    echo
    while true; do
        echo
        read -p "Should the batchsystem folder be prepared? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi

# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Preparing the batchsystem directory if not yet there
    mkdir -p batchsystem

    ### Tasks folder ###
    # Asking if the tasks folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the batchsystem/task-lists folder be prepared (replacing existing files & folders)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/task-lists folder"

        # Removing the old files and folders
        rm -r batchsystem/task-lists &> /dev/null || true

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/batchsystem/task-lists batchsystem/
    fi

    ### Template files folder ###
    # Asking if the templates folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the batchsystem/templates folder be prepared (replacing existing files & folders)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/templates folder"

        # Removing the old files and folders
        rm -r batchsystem/templates &> /dev/null || true

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/batchsystem/templates batchsystem/
    fi

    ### bin folder ###
    # Asking if the bin folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the batchsystem/bin folder be prepared (replacing existing files & folders)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/bin folder"

        # Removing the old files and folders
        rm -r batchsystem/bin &> /dev/null || true

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/batchsystem/bin batchsystem/
    fi

    ### Control folder ###
    # Asking if the control folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the batchsystem/control folder be prepared (replacing existing files & folders)? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Preparing the batchsystem/control folder"

        # Removing the old files and folders
        rm -r batchsystem/control &> /dev/null || true

        # Copying the files
        rsync -a${verbosity_suffix} --exclude=".*" ${HQ_HOME}/workflow-files/batchsystem/control batchsystem/
    fi

    ### Jobfiles folder ###
    # Asking if the control folder should be prepared
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the batchsystem/job-files folder be deleted if it exists? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Deleting the batchsystem/job-files folder if it exists"

        # Removing the old files and folders
        rm -r batchsystem/job-files &> /dev/null || true
    fi

    ### Output-files folder ###
    # Asking if the output-files folder should be removed
    if [ ${answer_cleanup_all} == "false" ]; then
        while true; do
            echo
            read -p "Should the batchsystem/output-files folder be removed if it exists? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Removing the batchsystem/output-files folder if it exists"

        # Removing the old files and folders
        rm -r batchsystem/output-files &> /dev/null || true
    fi
fi

# Asking if the log-files folder should be removed
if [ ${answer_cleanup_all} == "false" ]; then
    while true; do
        echo
        read -p "Should the log-files folder be removed if existent? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi
# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Printing some information
    echo -e " * Removing the log-files folder if existent"

    # Removing the old files and folders
    rm -r log-files &> /dev/null || true
fi

# Asking if the runtime folder should be removed
if [ ${answer_cleanup_all} == "false" ]; then
    while true; do
        echo
        read -p "Should the runtime folder be removed if existent? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi
# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Printing some information
    echo -e " * Removing the runtime folder if existent"

    # Removing the old files and folders
    rm -r runtime &> /dev/null || true
fi


# Asking the user if the opt-folder should be prepared
if [ ${answer_cleanup_all} == "false" ]; then

    echo
    while true; do
        echo
        read -p "Should the optimization folder be prepared? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi

# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Asking if the opt folder should be removed
    if [[ ${answer_cleanup_all} == "false" ]]; then
        while true; do
            echo
            read -p "Should the opt folder be removed if existent? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Removing the opt folder if existent"

        # Removing the old files and folders
        rm -r opt &> /dev/null || true
    fi

    # Copying the optimization files
    while true; do
        echo
        read -p "Should the relevant optimization output files be copied from another run? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [[ "${answer}" = "true" ]] ; then

        # Loop for getting the user input
        while true; do

            # Printing some information
            echo
            read -e -p " Please specify the relative path of the root folder of the run which contains the files to be copied (autocompletion available): " source_inputfiles_folder
            echo

            # Checking if the path exists
            echo -n " * Checking if the specified folder exists... "
            if [ -d ${source_inputfiles_folder} ]; then
                echo "OK"
                break;
            else
                echo "failed"
            fi
        done

        # Printing some information
        echo -e " * Copying the optimization output files of the specified run..."

        # Copying the files
        for msp_folder in ${source_inputfiles_folder}/opt/*; do
            msp=$(basename ${msp_folder})
            for subsystem_folder in ${msp_folder}/*; do
                subsystem=$(basename ${subsystem_folder});
                mkdir -p opt/${msp}/${subsystem}/
                rsync -a${verbosity_suffix} ${subsystem_folder}/*opt.pdb opt/${msp}/${subsystem}/
            done
        done
        echo
    fi
fi


# Asking the user if the eq-folder should be prepared
if [ ${answer_cleanup_all} == "false" ]; then

    echo
    while true; do
        echo
        read -p "Should the equilibration folder be prepared? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi

# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Asking if the eq folder should be removed
    if [[ ${answer_cleanup_all} == "false" ]]; then
        while true; do
            echo
            read -p "Should the eq folder be removed if existent? " answer
            echo
            case ${answer} in
                [Yy]* ) answer=true; break;;
                [Nn]* ) answer=false; break;;
                * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
            esac
        done
    fi
    # Checking the answer
    if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

        # Printing some information
        echo -e " * Removing the eq folder if existent"

        # Removing the old files and folders
        rm -r eq &> /dev/null || true
    fi

    # Copying the equilibration files
    while true; do
        echo
        read -p "Should the relevant equilibration output files be copied from another run? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
    # Checking the answer
    if [[ "${answer}" = "true" ]] ; then

        # Loop for getting the user input
        while true; do

            # Printing some information
            echo
            read -e -p " Please specify the relative path of the root folder run which contains the files to be copied (autocompletion available): " source_inputfiles_folder
            echo

            # Checking if the path exists
            echo -n " * Checking if the specified folder exists... "
            if [ -d ${source_inputfiles_folder} ]; then
                echo "OK"
                break;
            else
                echo "failed"
            fi
        done

        # Printing some information
        echo -e " * Copying the equilibration output files of the specified run..."

        # Copying the files
        for msp_folder in ${source_inputfiles_folder}/eq/*; do
            msp=$(basename ${msp_folder})
            for subsystem_folder in ${msp_folder}/*; do
                subsystem=$(basename ${subsystem_folder});
                mkdir -p eq/${msp}/${subsystem}/
                rsync -a${verbosity_suffix} ${subsystem_folder}/*eq.pdb eq/${msp}/${subsystem}/
            done
        done
        echo
    fi
fi

# Asking if the md folder should be removed
if [ ${answer_cleanup_all} == "false" ]; then
    while true; do
        echo
        read -p "Should the md folder be removed if existent? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi
# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Printing some information
    echo -e " * Removing the md folder if existent"

    # Removing the old files and folders
    rm -r md &> /dev/null || true
fi

# Asking if the ce folder should be removed
if [ ${answer_cleanup_all} == "false" ]; then
    while true; do
        echo
        read -p "Should the ce folder be removed if existent? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi
# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Printing some information
    echo -e " * Removing the ce folder if existent"

    # Removing the old files and folders
    rm -r ce &> /dev/null || true
fi

# Asking if the fec folder should be removed
if [ ${answer_cleanup_all} == "false" ]; then
    while true; do
        echo
        read -p "Should the fec folder be removed if existent? " answer
        echo
        case ${answer} in
            [Yy]* ) answer=true; break;;
            [Nn]* ) answer=false; break;;
            * ) echo -e "\nUnsupported answer. Possible answers are 'yes' or 'no'";;
        esac
    done
fi
# Checking the answer
if [[ "${answer}" = "true" ]] || [[ "${answer_cleanup_all}" == "true" ]]; then

    # Printing some information
    echo -e " * Removing the fec folder if existent"

    # Removing the old files and folders
    rm -r fec &> /dev/null || true
fi

# Displaying some information
echo -e "\n\n * The preparation of the files and folders has been completed\n\n"
