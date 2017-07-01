#!/usr/bin/env python
from hyperq.cp2k_dummies import *

def run_cp2k_dummies(system1_basename, system2_basename):

    dummyAtomIndeces1 = []
    dummyAtomIndeces2 = []
    
    with open(system1_basename + ".dummy.indices", "r") as system1DummyAtomIndecesFile:
        for line in system1DummyAtomIndecesFile:
            dummyAtomIndeces1 += map(int,line.split())
    
    with open(system2_basename + ".dummy.indices", "r") as system2DummyAtomIndecesFile:
        for line in system2DummyAtomIndecesFile:
            dummyAtomIndeces2 += map(int,line.split())

    system1 = molecularSystem(system1_basename, dummyAtomIndeces1)
    system2 = molecularSystem(system2_basename, dummyAtomIndeces2)
    FFSystem1 = ForceField(system1_basename)
    FFSystem2 = ForceField(system2_basename)
    prepare_cp2k_FF(system1, FFSystem1)
    prepare_cp2k_FF(system2, FFSystem2)
    
def help():
    print "Usage: hqh_fes_prepare_cp2k_dummies.py <system1_basename> <system2_basename>"
    print "Indices used internally are the ones of the psf files. -> atom order"
    print "For each system pdb/psf/prm/.dummy.indices files are required."
    print "The output files are required input files for CP2K."

# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 3):
        help()
    else:
        run_cp2k_dummies(sys.argv[1], sys.argv[2])