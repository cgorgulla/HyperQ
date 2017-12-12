#!/usr/bin/env python
import sys
from hyperq.molecular_systems import *




# Checking if this file is run as the main program
def help():
    print "\nUsage: hqh_gen_prepare_cp2k_qmmm.py <system basename> <psf file> <parameter file> <pdbx file>\n"
    print "Indices in the cp2k input file start at 1 (index by atom order <- atom order)."
    print "For each system the pdbx/psf files are required."
    print "The output files are input files for CP2K.\n\n"


# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 5):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required is 4 input arguments. Exiting..."
        help()
        exit(1)

    else:
        # Variables
        systemBasename = sys.argv[1]
        psfFilename = sys.argv[2]
        parameterFilename = sys.argv[3]
        pdbxFilename = sys.argv[4]
        system = MolecularSystemQMMM(systemBasename, psfFilename, pdbxFilename)
        system.prepare_cp2k_qmmm(parameterFilename)