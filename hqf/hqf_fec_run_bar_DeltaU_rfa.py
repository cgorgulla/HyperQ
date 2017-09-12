#!/usr/bin/env python
import sys
from hyperq.bar import *
    

def help():
    print "\nUsage: hqf_fec_run_bar.py <file with Delta_1 U = U1_U2-U1_U1 values> <file with Delta_2 U = U2_U1-U2_U2 values> <delta_F_min> <delta_F_max> <outputFilename> <iteration_max> <temp> <absolute C-tolerance>\n"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    
    # Checking the number of arguments
    if  (len(sys.argv) != 9 ):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 8 parameters. Exiting..."
        help()
        exit(1)

    elif sys.argv[1] == "-h" and len(sys.argv) == 1:
        help()

    else:
        # Preparing the input data
        U1_U2_minus_U1_U1_filename = sys.argv[1]
        U1_U2_minus_U1_U1_values = np.loadtxt(U1_U2_minus_U1_U1_filename)
        U2_U1_minus_U2_U2_filename = sys.argv[2]
        U2_U1_minus_U2_U2_values = np.loadtxt(U2_U1_minus_U2_U2_filename)

        # Running BAR
        bar_object = BAR_DeltaU_rfa(U1_U2_minus_U1_U1_values, U2_U1_minus_U2_U2_values, sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8])
        bar_object.compute_bar()
        bar_object.write_results()
