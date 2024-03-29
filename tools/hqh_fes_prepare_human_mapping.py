#!/usr/bin/env python
import sys
from hyperq.molecular_systems import *
def help():
    print "\nUsage: hqh_fes_prepare_human_mapping.py <system1 pdb filename> <system2 pdb filename> <mcs mapping filename> <output filename>"
    print
    print "Prepares a human-readable (hr) mapping file."
    print "Index of the atoms in the mcs-mapping-file starts at 1 (based on the ligand only files)"
    print "The atom indices which are mapped are the ones of the entire system (the indices in the pdb files)."
    print "Therefore the pdb files of the individual systems should have continuous indices starting at 1."
    print "Can contain the following chains/molecules in the given order:"
    print "Chain R (receptor)"
    print "Chain L (ligand)"
    print "Other chains - at the end (e.g. solvent)"
    print "The chain identifiers must be present in the PDB files. Each chain is optional."
    print "E.g. R+L+S/W is possible, or L+S, or L only (not tested yet)."
    print "The output file contains the mixed forces sections for CP2K.\n\n"

# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 5):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 4 input arguments. Exiting..."
        help()
        exit(1)

    else:
        system1 = SingleSystem(sys.argv[1], sys.argv[3], 1, createDummyIndexFiles=False)
        system2 = SingleSystem(sys.argv[2], sys.argv[3], 2, createDummyIndexFiles=False)
        jointSystem = JointSystem(system1, system2, sys.argv[3])
        jointSystem.writeHRMappingFile(sys.argv[4])