#!/usr/bin/env python
import sys
from hyperq.molecular_systems import *                        

def help():
    print "\nUsage: hqh_fes_prepare_jointsystem.py <system1 pdb filename> <system2 pdb filename> <mcs mapping filename>"
    print 
    print "Index of the atoms in the (input) mcs-mapping-file starts at 1 (based on the ligand only files)"
    print "The atom indices which are mapped are the ones of the entire system."
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
    if (len(sys.argv) != 4):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 3 input arguments. Exiting..."
        help()
        exit(1)

    else:
        system1 = SingleSystem(sys.argv[1], sys.argv[3], 1)
        system2 = SingleSystem(sys.argv[2], sys.argv[3], 2)
        jointSystem = JointSystem(system1, system2, sys.argv[3])
        jointSystem.write_cp2k_mapping_files()
        jointSystem.writeSystemPDB()