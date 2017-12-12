#!/usr/bin/env python
import sys
from hyperq.fep import FEP
    

def help():
    print "\nUsage: hqf_fec_run_fep.py <file with U1_U1 values> <file with U1_U2 values> <absolute temperature>\n"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    
    # Checking the number of arguments
    if  (len(sys.argv) != 4):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 3 input arguments. Exiting..."
        help()
        exit(1)

    elif sys.argv[1] == "-h" and len(sys.argv) == 1:
        help()
    else:
        try:
            fep = FEP(sys.argv[1], sys.argv[2], sys.argv[3])
            fep_value=fep.compute_fep()
            print(str(fep_value) + " kcal/mol")
        except TypeError as err:
            sys.stderr.write('\n' + err.message + '\n\n')
            exit(10)
