#!/usr/bin/env python
import sys

def update_status(unconstraint_ids_filename, quantum_ids_filename, pdb_filename):
    
    q_atoms = []
    u_atoms = []
    # Reading the atom ids of the quantum atoms
    with open(quantum_ids_filename, 'r') as quantum_ids_file:
        for line in quantum_ids_file:
          for number in line.split():
            q_atoms.append(int(number))
    
    # Reading the atom ids of the constraint atoms
    with open(unconstraint_ids_filename, 'r') as unconstraint_ids_file:
        for line in unconstraint_ids_file:
          for number in line.split():
            u_atoms.append(int(number))
    with open(pdb_filename, 'r') as pdb_file:
        with open(pdb_filename + "x", 'w', 0) as pdbx_file:
            for line in pdb_file:
                if "ATOM" in line or "HETATM" in line:     
                    atom_id = int(line[6:11].strip())
                    line = line.rstrip("\n").ljust(82)
                    if atom_id in q_atoms:
                        line = list(line)
                        line[80] = "Q"
                    else:
                        line = list(line)
                        line[80] = "M"
                                            
                    if atom_id in u_atoms:
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
    print "Usage: hqh_sp_prepare_pdbx <unconstraint_ids_filename> <qunatum_ids_filenamet> <input pdbfile>"
    
# Checking if this file is run as the main program 
if __name__ == '__main__':
    
    # Checking the number of arguments 
    if (len(sys.argv) != 4):
        help()
    else:
        update_status(sys.argv[1], sys.argv[2], sys.argv[3])