#!/usr/bin/env python
from hyperq.cp2k_dummies import *

def run_cp2k_dummies(systemBasename, psfFilename, dummyAtomIndicesFilename, prmOutputFile):

    dummyAtomIndices = []
    
    with open(dummyAtomIndicesFilename, "r") as systemDummyAtomIndicesFile:
        for line in systemDummyAtomIndicesFile:
            dummyAtomIndices += map(int,line.split())

    system = MolecularSystem(systemBasename, psfFilename, dummyAtomIndices)
    append_dummies_to_prmfile(system, prmOutputFile)


def help():
    print "\nUsage: hqh_fes_prm_transform_into_dummies.py <system_basename> <psf file> <dummy atom indices file> <prm file> \n"
    print "The dummy atom indices are interpreted as the atom IDs used in the psf file."
    print "The psf file can be in any format."
    print "The parameter file will be appended with the parameters for the dummy atoms specified in the dummy atom indices file.\n\n"

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
