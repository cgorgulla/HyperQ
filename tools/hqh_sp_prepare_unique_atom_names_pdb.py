#!/usr/bin/env python
import sys

def main(pdbFilenameIn, pdbFilenameOut, atomNameChar):
    
    elementTypes = set()
    
    with open(pdbFilenameIn, "r") as pdbFileIn:
        for line in pdbFileIn:
            if line[0:6].strip() in ["ATOM", "HETATM"]:
                element = line[76:78].strip()
                elementTypes.add(element)
    
    elementCount = {item:0 for item in elementTypes}
    
    with open(pdbFilenameOut, "w") as pdbFileOut:
        with open(pdbFilenameIn, "r") as pdbFileIn:
            for line in pdbFileIn:
                if line[0:6].strip() in ["ATOM", "HETATM"]:
                    element = line[76:78].strip()
                    elementCount[element] += 1
                    if len(element) == 1 and elementCount[element] >= 100:
                        print "Too many atoms of the type (" + element + ") in molecule. The maximum number of this type is 99."
                        exit()
                    elif len(element) == 2 and elementCount[element] >= 10:
                        print "Too many atoms of the type (" + element + ") in molecule. The maximum number is 9."
                        exit()
                    line = list(line)
                    line[12:16] = (element + str(elementCount[element]) + atomNameChar).ljust(4)
                    line = ''.join(line)
                    
                pdbFileOut.write(line)


def help():
    print "\nUsage: hqh_sp_prepare_unique_atom_names_pdb.py <pdb filename> <output filename> <atom name character>"
    print "The input file needs to have the element ID in columns 77-78 as defined in the official PDB format specifications."
    print "<atom name character>: Is a letter which is used in the atom names to make them unique."
    print "                       J and Q are quite unique in the context of the CGFF, but this does not seem to matter since atom names are different from atom types.\n\n"


# Checking if this file is run as the main program 
if __name__ == '__main__':
    # Checking the number of arguments 
    if (len(sys.argv) != 4):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 3 input arguments. Exiting..."
        help()
        exit(1)

    else:
        main(*sys.argv[1:])
