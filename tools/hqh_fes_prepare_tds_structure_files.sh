#!/usr/bin/env bash

# Usage information
usage="Usage: hqh_fes_prepare_tds_structure_files.sh

Has to be run in the subsystem folder of the MSP."

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
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Variables
subsystem="$(pwd | awk -F '/' '{print $(NF)}')"
msp_name="$(pwd | awk -F '/' '{print $(NF-1)}')"
runtype="$(pwd | awk -F '/' '{print $(NF-2)}')"
sim_type="$(grep -m 1 "^${runtype}_type_${subsystem}=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_type="$(grep -m 1 "^tdcycle_type=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_activate="$(grep -m 1 "^tdcycle_si_activate=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_hydrogen_single_step="$(grep -m 1 "^tdcycle_si_hydrogen_single_step=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_separate_neighbors="$(grep -m 1 "^tdcycle_si_separate_neighbors=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdcycle_si_consider_branches="$(grep -m 1 "^tdcycle_si_consider_branches=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
nbeads="$(grep -m 1 "^nbeads=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tdw_count="$(grep -m 1 "^tdw_count=" ../../../input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tds_count="$((tdw_count + 1))"


# Creating the dummy atom indices files
if [ "${tdcycle_si_activate^^}" == "TRUE" ]; then
    hqh_fes_prepare_tds_si_dummies.py system1 system1.cp2k.psf system1.prm ${tdw_count} ${tdcycle_si_hydrogen_single_step} ${tdcycle_si_separate_neighbors} ${tdcycle_si_consider_branches} decreasing
    hqh_fes_prepare_tds_si_dummies.py system2 system2.cp2k.psf system2.prm ${tdw_count} ${tdcycle_si_hydrogen_single_step} ${tdcycle_si_separate_neighbors} ${tdcycle_si_consider_branches} increasing
fi

# Preparing the files and folders
for tds_index in $(seq 1 ${tds_count}); do

    # Checking the td cycle type
    if [ "${tdcycle_type}" == "hq" ]; then

        # Checking if nbeads and tdw_count are compatible
        echo -e -n " * Checking if the variables <nbeads> and <tdw_count> are compatible..."
        trap '' ERR
        mod="$(expr ${nbeads} % ${tdw_count})"
        trap 'error_response_std $LINENO' ERR
        if [ "${mod}" != "0" ]; then

            # Printing some information
            echo " * Error: The variables <nbeads> and <tdw_count> are not compatible. <nbeads> has to be divisible by <tdw_count>. Exiting..."

            # Exiting
            exit 1
        fi
        echo " OK"

        # Variables
        bead_step_size=$(expr ${nbeads} / ${tdw_count})
        bead_count1="$(( nbeads - (tds_index-1)*bead_step_size))"
        bead_count2="$(( (tds_index-1)*bead_step_size))"
        subconfiguration="k_${bead_count1}_${bead_count2}"
        tds_folder=tds.${subconfiguration}

    elif [ "${tdcycle_type}" == "lambda" ]; then

        # Variables
        lambda_stepsize=$(echo "print(1/${tdw_count})" | python3)
        lambda_current=$(echo "$((tds_index-1))/${tdw_count}" | bc -l | xargs /usr/bin/printf "%.*f\n" 3 )
        subconfiguration=lambda_${lambda_current}
        tds_folder="tds.${subconfiguration}"
    fi

    # Creating the folders
    mkdir -p ${tds_folder}/general
    cd ${tds_folder}/general/

    # Copying the basic files of the two systems of the MSP
    for system_ID in 1 2; do
        cp ../../system${system_ID}.pdb ./
        cp ../../system${system_ID}.prm ./
        cp ../../system${system_ID}.dummy.psf ./
    done

    # Checking if serial insertion is activated
    if [ "${tdcycle_si_activate^^}" == "TRUE" ]; then

        # Moving the dummy atom indices file
        mv ../../system1.tds-${tds_index}.dummy.indices system1.dummy.indices
        mv ../../system2.tds-${tds_index}.dummy.indices system2.dummy.indices

        # Preparing the psf files for the real system
        hqh_fes_psf_transform_into_dummies.py ../../system1.cp2k.psf system1.dummy.indices system1.cp2k.psf
        hqh_fes_psf_transform_into_dummies.py ../../system2.cp2k.psf system2.dummy.indices system2.cp2k.psf

        # Adjusting the prm files for the real system
        hqh_fes_prm_transform_into_dummies.py system1 system1.cp2k.psf system1.dummy.indices system1.prm
        hqh_fes_prm_transform_into_dummies.py system2 system2.cp2k.psf system2.dummy.indices system2.prm

        # Preparing the CP2K dummy atom files for the dummy system
        hqh_fes_prepare_cp2k_dummies.py system1 ../../system1.cp2k.psf ../../system1.prm system1.dummy.indices
        hqh_fes_prepare_cp2k_dummies.py system2 ../../system2.cp2k.psf ../../system2.prm system2.dummy.indices
    else

        # Copying the basic files of the two systems of the MSP
        for system_ID in 1 2; do
            cp ../../system${system_ID}.dummy.indices ./
            cp ../../system${system_ID}.dummy.psf ./
            cp ../../system${system_ID}.cp2k.psf ./
            cp ../../cp2k.in.bonds.system${system_ID} ./
            cp ../../cp2k.in.angles.system${system_ID} ./
            cp ../../cp2k.in.dihedrals.system${system_ID} ./
            cp ../../cp2k.in.impropers.system${system_ID} ./
            cp ../../cp2k.in.lj.system${system_ID} ./
        done
    fi

    # Changing to the original directory
    cd ../../
done
