#!/usr/bin/env python
import sys
from hyperq.bar import *
    

def help():
    print "Usage: hqf_fec_run_bar.py <file with Delta_1 U = U1_U2-U1_U1 values> <file with Delta_2 U = U2_U1-U2_U2 values> <delta_F_min> <delta_F_max> <outputFilename> <iteration_max> <temp> <absolute C-tolerance>\n"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    
    # Checking the number of arguments
    if  (len(sys.argv) != 9 ):
        print "Wrong number of arguments. Exiting.\n"
        help()
    elif sys.argv[1] == "-h" and len(sys.argv) == 1:
        help()
    else:
        #try:
        bar_object = BAR_DeltaU_rfa(*sys.argv[1:])
        bar_object.compute_bar()
        bar_object.write_results()
        #except TypeError as err:
        #    sys.stderr.write('\n' + err.message + '\n\n')
        #    exit(10)