#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_qatom_files.sh <system basename>"

# Standard error response 
error_response_std() {
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Exiting."
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Verbosity
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Checking the input parameters
if [ "${1}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "1" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments were provided when calling the script."
    echo "Number of expected arguments: 1"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Variables
system_basename=${1}

# Preparing the qatom indices
# Checking if number of indices > 0
if [ -z "$(cat ${system_basename}.all.qatoms.indices.0 | tr -d "[:space:]" )" ]; then
    echo -e " * Info: No QM atoms (qatoms) in system ${system_basename}." 
    touch ${system_basename}.all.qatoms.indices
    touch ${system_basename}.solvent.qatoms.indices
    touch ${system_basename}.nonsolvent.qatoms.indices    
    touch ${system_basename}.all.qcatoms.indices
    touch ${system_basename}.all.qatoms.elements
else
    # qatoms
    cat ${system_basename}.all.qatoms.indices.0 | tr " " "\n" | awk '{print ($1 + 1)}' | tr "\n" " " > ${system_basename}.all.qatoms.indices
    # for each component: nonsolvent, solvent
    for component in all nonsolvent solvent; do
        cat ${system_basename}.${component}.qatoms.indices+elements.0 | sed "s/} {/\n/g" | tr -d "}{" | awk '{print $1, ($2 + 1)}' > ${system_basename}.${component}.qatoms.indices+elements.columns
        cat ${system_basename}.${component}.qatoms.indices+elements.columns | awk '{print $1}' | tr 'g' " "  |  sort | uniq > ${system_basename}.${component}.qatoms.elements
        for elem in $(cat ${system_basename}.${component}.qatoms.elements); do 
            cat /dev/null >| ${system_basename}.${component}.qatoms.elements.${elem}.indices
        done
        for elem in $(cat ${system_basename}.${component}.qatoms.elements); do
            grep "$elem " ${system_basename}.${component}.qatoms.indices+elements.columns | awk '{printf "%s ", $2}' >> ${system_basename}.${component}.qatoms.elements.${elem}.indices
        done
    done
    
    # qcatoms
    cat ${system_basename}.all.qcatoms.indices.0 | tr " " "\n" | awk '{print ($1 + 1)}' | tr "\n" " " > ${system_basename}.all.qcatoms.indices
fi
