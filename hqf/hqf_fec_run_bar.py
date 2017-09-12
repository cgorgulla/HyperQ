#!/usr/bin/env python
import sys
from hyperq.bar import *
import numpy as np
    

def help():
    print "\nUsage: hqf_fec_run_bar.py <file with U1_U1 values> <file with U1_U2 values> <file with U2_U1 values> <file with U2_U2 values> <Delta F_min> <Delta F max> <output filename> <absolute temperature> <C absolute tolerance>\n"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    
    # Checking the number of arguments
    if  (len(sys.argv) != 10):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 9 parameters. Exiting..."
        help()
        exit(1)

    elif sys.argv[1] == "-h" and len(sys.argv) == 1:
        help()

    else:

        # Preparing the input data
        U1_U1_filename = sys.argv[1]
        U1_U1_values = np.loadtxt(U1_U1_filename)
        U1_U2_filename = sys.argv[2]
        U1_U2_values = np.loadtxt(U1_U2_filename)
        U2_U1_filename = sys.argv[3]
        U2_U1_values = np.loadtxt(U2_U1_filename)
        U2_U2_filename = sys.argv[4]
        U2_U2_values = np.loadtxt(U2_U2_filename)

        if len(U1_U1_values) == len(U1_U2_values):
            U1_U2_minus_U1_U1_values = U1_U2_values - U1_U1_values
        else:
            errorMessage = "Error: The files " + U1_U1_filename + " and " + U1_U2_filename + " contain an unequal number of values."
            raise TypeError(errorMessage)
        if len(U2_U1_values) == len(U2_U2_values):
            U2_U1_minus_U2_U2_values = U2_U1_values - U2_U2_values
        else:
            errorMessage = "Error: The files " + U2_U1_filename + " and " + U2_U2_filename + " contain an unequal number of values."
            raise TypeError(errorMessage)

        # Running BAR
        bar_object = BAR_DeltaU(U1_U2_minus_U1_U1_values, U2_U1_minus_U2_U2_values, sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9])
        bar_object.compute_bar()
        bar_object.write_results()
        bar_object.plot("save")
