#!/usr/bin/env python
import sys
from hyperq.bar import BAR
    

def help():
    print "Usage: hqf_fec_run_bar.py <file with U1_U1 values> <file with U1_U2 values> <file with U2_U1 values> <file with U2_U2 values> <Delta F_min> <Delta F max> <output filename> <absolute temperature> <C absolute tolerance>\n"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    
    # Checking the number of arguments
    if  (len(sys.argv) != 10):
        print "Wrong number of arguments. Exiting.\n"
        help()
    elif sys.argv[1] == "-h" and len(sys.argv) == 1:
        help()
    else:
        bar = BAR(*sys.argv[1:])
        bar.compute_bar()
        bar.write_delta_F_values()
        bar.write_results()
        bar.plot("save")
        #try:
        #except TypeError as err:
        #    sys.stderr.write('\n' + err.message + '\n\n')
        #    exit(10)