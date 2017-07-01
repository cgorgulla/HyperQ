#!/usr/bin/env python
import sys
from hyperq.molecular_systems import *




# Checking if this file is run as the main program
def help():
    print "Usage: hqh_gen_prepare_cp2k_qmmmm.py <system_basename>"
    print "Indices in the cp2k input file start at 1 (index by atom order <- atom order)."
    print "For each system the pdbx/psf files are required."
    print "The output files are input files for CP2K."


# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 2):
        print "Wrong number of arguments. Exiting.\n"
        help()
    else:
        # Variables
        dummyAtomIndeces = []
        system_basename = sys.argv[1]
        system = MolecularSystem2(system_basename)
        system.prepare_cp2k_qmmm()