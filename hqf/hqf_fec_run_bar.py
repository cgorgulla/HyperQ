#!/usr/bin/env python
import sys
from hyperq.bar import BAR
    

def help():
    print "Usage: hqf_fec_run_bar.py <file with U1_U2 values> <file with U2_U2 values> <file with U2_U1 values> <file with U1_U1 values> <file with C-values> <outputfile basename>\n"
    print "The first potential is always the evaluationg potential, the second one is the one from whic the coordinates have been sampled.\n\n"
    
# Checking if this file is run as the main program
if __name__ == '__main__':
    
    # Checking the number of arguments
    if  (len(sys.argv) != 7) and (len(sys.argv) != 6): 
        print "Wrong number of arguments. Exiting.\n"
        help()
    elif sys.argv[1] == "-h" and len(sys.argv) == 1:
        help()
    else:
        try:
            bar = BAR(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
        except TypeError as err:
            sys.stderr.write('\n' + err.message + '\n\n')
            exit(10)
        bar.compute_bar()
        bar.write_delta_F_values()
        bar.write_results()
        bar.plot("save")