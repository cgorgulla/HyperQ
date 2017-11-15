#!/usr/bin/env bash 

usage="Usage: hqh_sp_prepare_PLS.sh <protein_basename> <ligand_basename>

Should be run in the root folder."

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

    # Exiting
    exit 1
}
trap 'error_response_std $LINENO' ERR

# Bash options
set -o pipefail

# Verbosity
if [ "${HQ_VERBOSITY_RUNTIME}" = "debug" ]; then
    set -x
fi

# Checking the input parameters
if [ "${2}" == "-h" ]; then
    echo
    echo -e "$usage"
    echo
    echo
    exit 0
fi
if [ "$#" -ne "2" ]; then
    echo
    echo -e "Error in script $(basename ${BASH_SOURCE[0]})"
    echo "Reason: The wrong number of arguments was provided when calling the script."
    echo "Number of expected arguments: 2"
    echo "Number of provided arguments: ${#}"
    echo "Provided arguments: $@"
    echo
    echo -e "$usage"
    echo
    echo
    exit 1
fi

# Printing some information
echo
echo
line_to_print="   Preparing the entire system for ligand ${2} (hqh_sp_prepare_PLS.sh)   "
echo "$line_to_print"
line_to_print_charno=$(echo -n "$line_to_print" | wc -m)
printf '%0.s*' $(seq 1 $line_to_print_charno)
echo

# Variables
protein_basename=${1}
ligand_basename=${2}
dirname=$(dirname $0)
ligand_FFparameter_source="$(grep -m 1 "^ligand_FFparameter_source=" input-files/config.txt | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Copying files, creating folders
echo -e "\n * Copying files and folders"
if [ -d input-files/systems/${ligand_basename}/RLS ]; then
    rm -r input-files/systems/${ligand_basename}/RLS
fi
mkdir -p input-files/systems/${ligand_basename}/RLS
cd input-files/systems/${ligand_basename}/RLS
cp ../../../ligands/pdb/${ligand_basename}.pdb ./${ligand_basename}.pdb
cp ../../../receptor/${protein_basename}.pdb ./receptor_original.pdb

# Preparing the ligand
if [ "${ligand_FFparameter_source}" == "MATCH" ]; then

    # Assigning uniqe atom names
    echo -e "\n *** Assigning unique atom names (uniqe_atom_names_pdb.py) ***"
    hqh_sp_prepare_unique_atom_names_pdb.py ${ligand_basename}.pdb ${ligand_basename}_unique.pdb Q

    # Atom typing with MATCH - and unique atom names (required also by us regarding cp2k and dummy atoms)
    echo -e "\n * Atom typing with MATCH\n"
    #MATCH.pl -ExitifNotInitiated 0 -ExitifNotTyped 0 -ExitifNotCharged 0 ${ligand_basename}_unique.pdb
    obabel -ipdb ${ligand_basename}_unique.pdb -osdf -O ${ligand_basename}_unique.sdf #because of the bond orders (which can be caused by missing hydrogens, but not only) sdf does work for that, but obabel doesn't create the alias atom names in the sdf file (https://sourceforge.net/p/rdkit/mailman/message/35360754/)
    trap '' ERR

    timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${ligand_basename}_unique_match.pdb ${ligand_basename}_unique.sdf
    exit_code=${?}
    if [ "${exit_code}" == "124" ]; then
        echo " * MATCH seems to take too long. Aborting and trying again with the option UsingRefiningIncrements turned off"
        timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${ligand_basename}_unique_match.pdb -UsingRefiningIncrements 0 ${ligand_basename}_unique.sdf;
        if [ "${exit_code}" == "124" ]; then
            echo " * MATCH still seems to take too long. Aborting and trying again with the option SubstituteIncrements turned off"
            timeout 1m MATCH.pl -forcefield top_all36_cgenff_new -ExitifNotInitiated 0 -CreatePdb ${ligand_basename}_unique_match.pdb -SubstituteIncrements 0 ${ligand_basename}_unique.sdf;
            if [ "${exit_code}" == "124" ]; then
                echo " * MATCH still seems to take too long. Giving up... "
            else
                echo -e "\n Failed to type atoms, skipping this ligand..."
                exit 0
            fi
        fi
    elif [ "${exit_code}" -ne "0" ]; then
        echo -e "\n Failed to type atoms (exit code was $exit_code, skipping this ligand..."
        exit 0
    fi
    trap 'error_response_std $LINENO' ERR

    #sed -i "s/RESI  LIG1/RESI  LIG /" ${ligand_basename}_unique.rtf # Required only if using mol2 ligand file for MATCH
    sed -i "s/RESI  UNK/RESI  LIG/" ${ligand_basename}_unique.rtf # Required only if using sdf ligand file for MATCH because it cannot store residue names
    mv top_${ligand_basename}_unique.rtf protein_ligand.rtf

    #sed -i "s/HE/He/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/LI/Li/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/BE/Be/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/NE/Ne/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/NA/Na/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/MG/Mg/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AL/Al/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SI/Si/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CL/Cl/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AR/Ar/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CA/Ca/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SC/Sc/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TI/Ti/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CR/Cr/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/MN/Mn/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/FE/Fe/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CO/Co/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/NI/Ni/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CU/Cu/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/ZN/Zn/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/GA/Ga/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/GE/Ge/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AS/As/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SE/Se/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/BR/Br/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/KR/Kr/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RB/Rb/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SR/Sr/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/ZR/Zr/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/NB/Nb/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/MO/Md/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TC/Tc/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RU/Ru/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RH/Rh/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PD/Pd/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AG/Ag/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CD/Cd/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/IN/In/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SN/Sn/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SB/Sb/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TE/Te/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/XE/Xe/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CS/Cs/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/BA/Ba/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/LA/La/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CE/Ce/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PR/Pr/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/ND/Nd/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PM/Pm/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SM/Sm/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/EU/Eu/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/GD/Gd/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TB/Tb/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/DY/Dy/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/HO/Ho/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/ER/Er/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TM/Tm/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/YB/Yb/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/LU/Lu/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/HF/Hf/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TA/Ta/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RE/Re/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/OS/Os/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/IR/Ir/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PT/Pt/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AU/Au/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/HG/Hg/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TL/Tl/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PB/Pb/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/BI/Bi/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PO/Po/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AT/At/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RN/Rn/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/FR/Fr/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RA/Ra/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AC/Ac/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/TH/Th/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PA/Pa/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/NP/Np/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/PU/Pu/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/AM/Am/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CM/Cm/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/BK/Bk/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CF/Cf/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/ES/Es/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/FM/Fm/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/MD/Md/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/NO/No/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/LR/Lr/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RF/Rf/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/DB/Db/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/SG/Sg/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/BH/Bh/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/HS/Hs/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/MT/Mt/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/DS/Ds/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/RG/Rg/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/CN/Cn/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/UU/Uu/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/UUT/Uut/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/FL/Fl/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/UUP/Uuü/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/LV/Lv/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/UUS/Uus/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise
    #sed -i "s/UUO/Uuo/g" ${ligand_basename}_unique.rtf protein_ligand.rtf # ipi complains otherwise

    # mv ${ligand_basename}_unique.pdb ${ligand_basename}_unique_typed.pdb # only needed when not using MATCH's pdb file
    cc_match_pp_pdb.sh ${ligand_basename}_unique.pdb ${ligand_basename}_unique_match.pdb ${ligand_basename}_unique_typed.pdb


    # Patching the prm file of MATCH
    # MATCH does not add the END statement which is needed by CP2K (in particular when joining multiple parameter files)
    echo "END" >> ${ligand_basename}_unique.prm

    # Renaming the output files
    mv ${ligand_basename}_unique.prm ${ligand_basename}_unique_typed.prm
    mv ${ligand_basename}_unique.rtf ${ligand_basename}_unique_typed.rtf
elif [ "${ligand_FFparameter_source}" == "folder" ]; then
    cp ${ligand_basename}.pdb ${ligand_basename}_unique_typed.pdb
    cp ../../../ligands/FF/${ligand_basename}.rtf ${ligand_basename}_unique_typed.rtf
    cp ../../../ligands/FF/${ligand_basename}.prm ${ligand_basename}_unique_typed.prm
fi

echo

# Creating the joint parameter file for protein+ligand
script_dir=$(dirname $0)
cp ${script_dir}/../common/charmm36/par_all36_prot_solvent.prm system_complete.prm
cat ${script_dir}/../common/charmm36/par_all36_cgenff.prm >> system_complete.prm
# We need to remove these three atoms because they would require charmms lipid/carb/cgenff prm file to be loaded at first,
# and the cgenff caused an error with NAMD, it was not happy
# The END/return needs to be correct for cp2k
sed -i "/return/d" ./system_complete.prm
sed -i "/^SOD    OCL/d" ./system_complete.prm
sed -i "/^SOD    OC2D2/d" ./system_complete.prm
sed -i "/^SOD    OG2D2/d" ./system_complete.prm
cat ${ligand_basename}_unique_typed.prm >> system_complete.prm

# Some parameter files seem to contain the section keyword IMPROPERS instead of IMPROPER, but CP2K only understands the latter)
sed -i "s/^IMPROPERS/IMPROPER/g" system_complete.prm
# Removing any return statements (from Charmm stream files)
sed -i "/return/d" system_complete.prm

# Waterbox generation
echo -e "\n *** Preparing the joint protein-ligand-solvent system (hqh_sp_prepare_waterbox_PLS.sh) ***"
hqh_sp_prepare_waterbox_PLS.sh receptor_original ${ligand_basename}_unique_typed system

cd ../../..
