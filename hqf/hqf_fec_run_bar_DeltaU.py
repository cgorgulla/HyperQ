#!/usr/bin/env python
import sys
from hyperq.bar import *
    

def help():
    print "Usage: hqf_fec_run_bar.py <file with Delta_1 U = U1_U2-U1_U1 values> <file with Delta_2 U = U2_U1-U2_U2 values> <Delta F_min> <Delta F max> <output filename> <absolute temperature> <C absolute tolerance>\n"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    
    # Checking the number of arguments
    if  (len(sys.argv) != 8 ):
        print "Wrong number of arguments. Exiting.\n"
        help()
    elif sys.argv[1] == "-h" and len(sys.argv) == 1:
        help()
    else:

        # Preparing the input data
        U1_U2_minus_U1_U1_filename = sys.argv[1]
        U1_U2_minus_U1_U1_values = np.loadtxt(U1_U2_minus_U1_U1_filename)
        U2_U1_minus_U2_U2_filename = sys.argv[2]
        U2_U1_minus_U2_U2_values = np.loadtxt(U2_U1_minus_U2_U2_filename)

        # Running BAR
        bar_object = BAR_DeltaU(U1_U2_minus_U1_U1_values, U2_U1_minus_U2_U2_values, sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
        bar_object.compute_bar()
        bar_object.write_results()
        bar_object.plot("save")
