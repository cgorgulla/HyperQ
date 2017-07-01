#!/usr/bin/env python
import sys
from hyperq.molecular_systems import *
def help():
    print "Usage: hqh_fes_prepare_human_mapping.py <system1 pdb filename> <system2 pdb filename> <mcs mapping filename>"
    print
    print "Prepares a human-readable (hr) mappinig file."
    print "Index of the atoms in the mcs-mapping-file starts at 1 (based on the ligand only files)"
    print "The atom indicess which are mapped are the ones of the entire system (the indices in the pdb files)."
    print "Therefore the pdb files of the individual systems should have continuous indices starting at 1."
    print "Can contain the following molecules:"
    print "Chain P - at first (e.g. protein)"
    print "Chain L - at second (e.g. ligand)"
    print "Other chains - at the end (e.g. solvent)"
    print "The chain identifyers must be present in the PDB files. Each chain is optional."
    print "E.g. P+L+S/W is possible, or L+S, or L only (not tested yet)."
    print "The output file contains the mixed forces sections for CP2K."

# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 4):
        help()
    else:
        system1 = SingleSystem(sys.argv[1], sys.argv[3], 1)
        system2 = SingleSystem(sys.argv[2], sys.argv[3], 2)
        jointSystem = JointSystem(system1, system2, sys.argv[3])
        jointSystem.writeHRMappingFile()