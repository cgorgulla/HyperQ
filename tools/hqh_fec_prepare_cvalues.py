#!/usr/bin/env python
import sys
import numpy as np

def partition(x_min, x_max, n):
    
    grid = np.linspace(x_min, x_max, n+1)
    
    for elem in grid:
        print "%f" % elem
    


def help():
    print "\nUsage: hqh_fec_prepare_cvalues.py <lower_bound> <upper_bound> <number_of_intervals>\n\n"
    
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 4):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 3 parameters. Exiting..."
        help()
        exit(1)

    else:
        partition(float(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3]))
