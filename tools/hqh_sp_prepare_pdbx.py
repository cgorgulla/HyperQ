#!/usr/bin/env python
import sys

def update_status(unconstrained_ids_filename, quantum_ids_filename, pdb_filename):
    
    qatoms = []
    uatoms = []
    # Reading the atom ids of the quantum atoms
    with open(quantum_ids_filename, 'r') as quantum_ids_file:
        for line in quantum_ids_file:
          for number in line.split():
            qatoms.append(int(number))
    
    # Reading the atom ids of the constraint atoms
    with open(unconstrained_ids_filename, 'r') as unconstrained_ids_file:
        for line in unconstrained_ids_file:
          for number in line.split():
            uatoms.append(int(number))
    with open(pdb_filename, 'r') as pdb_file:
        with open(pdb_filename + "x", 'w', 0) as pdbx_file:
            for line in pdb_file:
                if "ATOM" in line or "HETATM" in line:     
                    atom_id = int(line[6:11].strip())
                    line = line.rstrip("\n").ljust(82)
                    if atom_id in qatoms:
                        line = list(line)
                        line[80] = "Q"
                    else:
                        line = list(line)
                        line[80] = "M"
                                            
                    if atom_id in uatoms:
                        line = list(line)
                        line[81] = "U"
                    else:
                        line = list(line)
                        line[81] = "C"
                    pdbx_file.write("".join(line))
                    pdbx_file.write("\n")
                else:
                    pdbx_file.write(line)
		    
def help():
    print "\nUsage: hqh_sp_prepare_pdbx.py <unconstrained_ids_filename> <quantum_ids_filenames> <input pdbfile>\n\n"
    
# Checking if this file is run as the main program 
if __name__ == '__main__':
    
    # Checking the number of arguments 
    if (len(sys.argv) != 4):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 3 input arguments. Exiting..."
        help()
        exit(1)

    else:
        update_status(sys.argv[1], sys.argv[2], sys.argv[3])