#!/usr/bin/env bash 

# Usage information
usage="Usage: hqf_sp_prepare_all.sh <subsystems> [lomap]

The format is read from the file general hyperq config file.

<subsystems> can be L, LS, RLS. Multiple subsystems can be specified by colons without whitespaces (e.g. L:LS:RLS)

The lomap flag can be specified if the atom mappings for the thermodynamic cycles should be computed (with LOMAP). This requires a terminal connected to an X-server due to Lomap."

# Checking the input paras
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [[ "$#" -ne "1" && "$#" -ne "2" ]]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 1-2"
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

# Config file setup
if [[ -z "${HQ_CONFIGFILE_GENERAL}" ]]; then

    # Printing some information
    echo -e "\n * Info: The variable HQ_CONFIGFILE_GENERAL was unset. Setting it to input-files/config/general.txt\n"

    # Setting and exporting the variable
    HQ_CONFIGFILE_GENERAL=input-files/config/general.txt
    export HQ_CONFIGFILE_GENERAL
fi

# Verbosity
HQ_VERBOSITY_RUNTIME="$(grep -m 1 "^verbosity_runtime=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export HQ_VERBOSITY_RUNTIME
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Printing some information
echo
echo
echo "************************************************************"
echo "   Preparing all input structures  (hqf_sp_prepare_all.sh)   "
echo "************************************************************"

# Variables
input_file_format="$(grep -m 1 "^input_file_format=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
lomap_mol2_folder="$(grep -m 1 "^lomap_mol2_folder" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
subsystems=${1//:/ }

# Lomap flag
if [[ "$@" == *"lomap"* ]]; then
    lomap="true"
else
    lomap="false"
fi

# Converting the input files into the required formats
# Printing some information
echo
echo
echo "   Converting the input files into the required formats   "
echo "**********************************************************"

# Input format PDBQT
if [ "${input_file_format}" = "pdbqt" ]; then

    # Checking the presence of the input file fodler
    if [ ! -d input-files/ligands/pdbqt ]; then
        echo -e "\nError: The folder input-files/ligands/pdbqt does not exist. Exiting...\n"
        exit 1
    fi
    
    # Creating folders
    if [ -d input-files/ligands/pdb ]; then
        rm -r input-files/ligands/pdb
    fi
    if [ -d input-files/ligands/mol2-Li ]; then
        rm -r input-files/ligands/mol2-Li
    fi
    mkdir input-files/ligands/pdb
    mkdir input-files/ligands/mol2-Li

    # Preparing the raw ligands
    echo -e "\n * Preparing the ligands (pdbqt) with obabel"
    for file in $(ls -v input-files/ligands/pdbqt); do
        ligand_basename="${file/.*}"
        echo " * Converting the ligand $ligand_basename"
        obabel -l 1 -p 7.4 -ipdbqt input-files/ligands/pdbqt/${file} -opdb -O sp/ligands/pdb/${ligand_basename}.pdb
        obabel -l 1 -p 7.4 -ipdbqt input-files/ligands/pdbqt/${file} -omol2 -O sp/ligands/mol2-Li/${ligand_basename}.mol2
        sed -i "s/ H / Li/g" input-files/ligands/mol2-Li/${ligand_basename}.mol2
    done

# Input format SDF
elif [ "${input_file_format}" = "sdf" ]; then

    # Checking the presence of the input file fodler
    if [ ! -d input-files/ligands/sdf ]; then
        echo -e "\nError: The folder input-files/ligands/sdf does not exist. Exiting...\n"
        exit 1
    fi
    
    # Creating folders
    if [ -d input-files/ligands/pdb ]; then
        rm -r input-files/ligands/pdb
    fi
    if [ -d input-files/ligands/mol2-Li ]; then
        rm -r input-files/ligands/mol2-Li
    fi
    mkdir input-files/ligands/pdb
    mkdir input-files/ligands/mol2-Li

    # Preparing the raw ligands
    echo -e "\n * Preparing the ligands (sdf) with obabel"
    for file in $(ls -v input-files/ligands/sdf); do
        ligand_basename="${file/.*}"
        echo " * Converting the ligand $ligand_basename"
        obabel -l 1 -p 7.4 -isdf input-files/ligands/sdf/${file} -opdb -O input-files/ligands/pdb/${ligand_basename}.pdb
        obabel -l 1 -p 7.4 -isdf input-files/ligands/sdf/${file} -omol2 -O input-files/ligands/mol2-Li/${ligand_basename}.mol2
        sed -i "s/ H / Li/g" input-files/ligands/mol2-Li/${ligand_basename}.mol2
    done

# Input format MOL2 with hydrogens in 2D
elif [ "${input_file_format}" = "mol2_2d_h" ]; then

    # Checking the presence of the input file fodler
    if [ ! -d input-files/ligands/mol2 ]; then
        echo -e "\nError: The folder input-files/ligands/mol2 does not exist. Exiting...\n"
        exit 1
    fi

    # Creating folders
    if [ -d input-files/ligands/pdb ]; then
        rm -r input-files/ligands/pdb
    fi
    if [ -d input-files/ligands/mol2-Li ]; then
        rm -r input-files/ligands/mol2-Li
    fi
    mkdir input-files/ligands/pdb
    mkdir input-files/ligands/mol2-Li

    # Preparing the raw ligands
    echo -e "\n * Preparing the ligands (mol2_2d_h) with obabel"
    for file in $(ls -v input-files/ligands/mol2); do
        ligand_basename="${file/.*}"
        echo " * Converting the ligand $ligand_basename"
        obabel --gen3d -imol2 input-files/ligands/mol2/${file} -opdb -O input-files/ligands/pdb/${ligand_basename}.pdb
        obabel --gen3d -imol2 input-files/ligands/mol2/${file} -omol2 -O input-files/ligands/mol2-Li/${ligand_basename}.mol2
        sed -i "s/ H / Li/g" input-files/ligands/mol2-Li/${ligand_basename}.mol2
    done

# Input format PDB with hydrogens in 3D
elif [ "${input_file_format}" = "pdb_3d_h" ]; then
    
    # Checking the presence of the input file fodler
    if [ ! -d input-files/ligands/pdb ]; then
        echo -e "\nError: The folder input-files/ligands/pdb does not exist. Exiting...\n"
        exit 1
    fi

    # Creating folders
    if [ -d input-files/ligands/mol2-Li ]; then
        rm -r input-files/ligands/mol2-Li
    fi
    mkdir input-files/ligands/mol2-Li

    # Preparing the raw ligands
    echo -e "\n * Preparing the ligands (pdb_3d_h) with obabel"
    for file in $(ls -v input-files/ligands/pdb); do
        ligand_basename="${file/.*}"
        echo " * Converting the ligand $ligand_basename"
        obabel -ipdb input-files/ligands/pdb/${file} -omol2 -O input-files/ligands/mol2-Li/${ligand_basename}.mol2
        sed -i "s/ H / Li/g" input-files/ligands/mol2-Li/${ligand_basename}.mol2
    done

# Input format smi
elif [ "${input_file_format}" = "smi" ]; then
    
    # Checking the presence of the input file fodler
    if [ ! -d input-files/ligands/smi ]; then
        echo -e "\nError: The folder input-files/ligands/smi does not exist. Exiting...\n"
        exit 1
    fi

    # Creating folders for the mol2-Li format
    if [ -d input-files/ligands/mol2-Li ]; then
        rm -r input-files/ligands/mol2-Li
    fi
    mkdir input-files/ligands/mol2-Li
    # Creating folders for the pdb format    
    if [ -d input-files/ligands/pdb ]; then
        rm -r input-files/ligands/pdb
    fi
    mkdir input-files/ligands/pdb

    # Preparing the raw ligands
    echo -e "\n * Preparing the ligands (smi to pdb) with obabel"
    for file in $(ls -v input-files/ligands/smi); do
        ligand_basename="${file/.*}"
        echo " * Converting the ligand $ligand_basename"
        obabel --gen3d -p 7 -ismi input-files/ligands/smi/${file} -opdb -O input-files/ligands/pdb/${ligand_basename}.pdb
    done
    echo -e "\n * Preparing the ligands (pdb_3d_h to mol2_Li) with obabel"
    for file in $(ls -v input-files/ligands/pdb); do
        ligand_basename="${file/.*}"
        echo " * Converting the ligand $ligand_basename"
        obabel -ipdb input-files/ligands/pdb/${file} -omol2 -O input-files/ligands/mol2-Li/${ligand_basename}.mol2
        sed -i "s/ H / Li/g" input-files/ligands/mol2-Li/${ligand_basename}.mol2
    done
else
    echo -e "\nError the input file format for the ligands has an unsupported value. Exiting...\n"
    exit 1
fi

# Preparing the complete systems
for subsystem in ${subsystems}; do 
    if [[ "${subsystem}" == "L" ]]; then        
        for file in $(ls -v input-files/ligands/pdb); do
            echo $file
            ligand_basename="${file/.*}"
            echo $ligand_basename
            # Creating folders
            if [ -d input-files/systems/${ligand_basename}/${subsystem} ]; then
                rm -r input-files/systems/${ligand_basename}/${subsystem}
            fi
            mkdir -p input-files/systems/${ligand_basename}/${subsystem}

            # Preparing the system files
            hqh_sp_prepare_L.sh ${ligand_basename}
        done
    elif [[ "${subsystem}" == "LS" ]]; then
        for file in $(ls -v input-files/ligands/pdb); do
            ligand_basename="${file/.*}"
            # Creating folders
            if [ -d input-files/systems/${ligand_basename}/${subsystem} ]; then
                rm -r input-files/systems/${ligand_basename}/${subsystem}
            fi
            mkdir -p input-files/systems/${ligand_basename}/${subsystem}

            # Preparing the system files
            hqh_sp_prepare_LS.sh ${ligand_basename}
        done

    elif [[ "${subsystem}" == "RLS" ]]; then

        # Variables
        receptor_type="$(grep -m 1 "^receptor_type=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

        if [[ "${receptor_type}" == "H" ]]; then
            # Variables
            receptor_mode="$(grep -m 1 "^receptor_mode=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
            if [[ "${receptor_mode}" != "common" && "${receptor_mode}" != "individual" ]]; then
                echo -e " * Error: The variable receptor_mode has an unsupported value (${receptor_mode})."
                echo -e " *        Supported values are: common, individual"
                echo -e " *        Exiting..."
                exit 1
            fi

            # Preparing the receptor files
            if [[ ${receptor_mode} == "common" ]]; then
                receptor_basename="$(grep -m 1 "^receptor_basename=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
                cd input-files/receptor
                hqh_sp_prepare_H.sh ${receptor_basename}
                cd ../..
            elif [[ ${receptor_mode} == "individual" ]]; then
                for file in $(ls -v input-files/ligands/pdb); do
                    if [[ ! -f "input-files/receptor/${receptor_basename}.pdb" ]]; then
                        echo -e "\n * Error: The receptorfile ${receptor_basename} for ligand ${ligand_basename} could not be found. Exiting.\n\n"
                        exit 1
                    fi
                    ligand_basename="${file/.pdb}"
                    receptor_basename="${ligand_basename}"
                    cd input-files/receptor
                    hqh_sp_prepare_H.sh ${receptor_basename}
                    cd ../..
                done
            fi

            # Preparing the system files and folders
            for file in $(ls -v input-files/ligands/pdb); do

                # Variables
                ligand_basename="${file/.pdb}"
                if [[ ${receptor_mode} == "individual" ]]; then
                    receptor_basename="${ligand_basename}"
                fi

                # Creating folders
                if [ -d input-files/systems/${ligand_basename}/${subsystem} ]; then
                    rm -r input-files/systems/${ligand_basename}/${subsystem}
                fi
                mkdir -p input-files/systems/${ligand_basename}/${subsystem}

                # Preparing the system files
                hqh_sp_prepare_HLS.sh ${receptor_basename} ${ligand_basename}
            done

        elif [[ "${receptor_type}" == "P" ]]; then

            # Variables
            receptor_mode="$(grep -m 1 "^receptor_mode=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
            if [[ "${receptor_mode}" != "common" && "${receptor_mode}" != "individual" ]]; then
                echo -e " * Error: The variable receptor_mode has an unsupported value (${receptor_mode})."
                echo -e " *        Supported values are: common, individual"
                echo -e " *        Exiting..."
                exit 1
            fi

            for file in $(ls -v input-files/ligands/pdb); do
                ligand_basename="${file/.pdb}"
                if [[ ${receptor_mode} == "common" ]]; then
                    receptor_basename="$(grep -m 1 "^receptor_basename=" ${HQ_CONFIGFILE_GENERAL} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
                elif [[ ${receptor_mode} == "individual" ]]; then
                    receptor_basename="${ligand_basename}"
                fi
                if [[ ! -f "input-files/receptor/${receptor_basename}.pdb" ]]; then
                    echo -e "\n * Error: The receptorfile ${receptor_basename} for ligand ${ligand_basename} could not be found. Exiting.\n\n"
                    exit 1
                fi

                # Creating folders
                if [ -d input-files/systems/${ligand_basename}/${subsystem} ]; then
                    rm -r input-files/systems/${ligand_basename}/${subsystem}
                fi
                mkdir -p input-files/systems/${ligand_basename}/${subsystem}

                # Preparing the system files
                hqh_sp_prepare_PLS.sh ${receptor_basename} ${ligand_basename}
            done
        else
            echo -e " * Error: The receptor_type which was specified ($receptor_type) is not supported. Exiting..."
            exit 1
        fi

    else
        echo -e " * Error: The subsystem which was specified ($subsystem) is not supported. Exiting..."
        exit 1
    fi
done

# Filtering out the systems which were not successfully prepared
# Creating folders
echo -e "\n * Filtering out the systems which were not successfully prepared"
if [ -d input-files/ligands/${lomap_mol2_folder}.omit ]; then
    rm -r input-files/ligands/${lomap_mol2_folder}.omit
fi
if [ -d input-files/systems.omit/ ]; then
    rm -r input-files/systems.omit/
fi
mkdir input-files/ligands/${lomap_mol2_folder}.omit
mkdir input-files/systems.omit
for folder in $(ls -v input-files/systems/) ; do
    for subsystem in ${subsystems}; do 
        if [[ ! -f input-files/systems/${folder}/${subsystem}/system_complete.psf ]] && [[ -d input-files/systems/${folder}/${subsystem}/ ]]; then
            echo -e "\n * Removing ligand ${folder} due to failure in the preparation."
            mkdir -p input-files/systems.omit/${folder}
            mv input-files/systems/${folder}/${subsystem} input-files/systems.omit/${folder}
            mv input-files/ligands/mol2-Li/${folder}.mol2 input-files/ligands/${lomap_mol2_folder}.omit/
            break
        fi
    done
done

# Reducing the number of water molecules so that all systems have the same number
for subsystem in ${subsystems}; do
    hqh_sp_reduce_all_waters.sh ${subsystem}
done

# Preparing the remaining files for each system
for subsystem in ${subsystems}; do
    for ligand in $(find input-files/systems/ -type d -name ${subsystem} | awk -F '/' '{print $(NF-1)}'); do
        hqh_sp_prepare_system_2.sh ${ligand} ${subsystem}
    done
done

# Preparing the molecule pairings via MCS searches using Lomap
if [ "${lomap}" == "true" ]; then
    hqh_sp_prepare_td_pairings.sh
    awk '{print $3"_"$4}' input-files/mappings/td.pairings > input-files/mappings/msp.all
fi

echo -e " * The structures of all the molecules has been prepared\n\n"
