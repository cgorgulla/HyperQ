#!/usr/bin/env python
from hyperq.cp2k_dummies import *

def run_cp2k_dummies(systemBasename, psfFilename, prmFilename, dummyAtomIndicesFilename):

    dummyAtomIndices = []
    
    with open(dummyAtomIndicesFilename, "r") as systemDummyAtomIndicesFile:
        for line in systemDummyAtomIndicesFile:
            dummyAtomIndices += map(int,line.split())

    system = MolecularSystem(systemBasename, psfFilename, dummyAtomIndices)
    FFSystem = ForceField(prmFilename)
    prepare_cp2k_FF(system, FFSystem)


def help():
    print "\nUsage: hqh_fes_prepare_cp2k_dummies.py <system basename> <psf file> <prm file> <dummy atom indices file>\n"
    print "The dummy atom indices are interpreted as the atom IDs used in the psf file."
    print "The psf file can be in any format.\n\n"

# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 5):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 4 input arguments. Exiting..."
        help()
        exit(1)

    else:
        run_cp2k_dummies(*sys.argv[1:])