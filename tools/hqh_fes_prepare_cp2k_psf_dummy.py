#!/usr/bin/env python
import sys

def main(psfFilenameIn, psfFilenameOut):
    
    with open(psfFilenameOut, "w") as pdbFileOut:
        with open(psfFilenameIn, "r") as pdbFileIn:
            section = "not atoms"
            for line in pdbFileIn:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not atoms"
                elif len(lineSplit) > 1:
                    if "!NATOM" in lineSplit[1]:
                        currentSection = "atoms"
                    elif currentSection == "atoms" and ("END" in line or "!" in line):
                        currentSection = "not atoms"
                    elif currentSection == "atoms" and line[8:9] == " " and line[12:13] == " " and line[9:12].isupper():
                        line = list(line)
                        # Setting the charge to zero
                        line[35:44] = " 0.000000"
                        # Setting the atom type to atom name
                        if len(lineSplit[4]) <= 4: 
                            line[29:34] = line[24:29]
                        else:
                            print "Error: The atom type (field 5) of the following line contains more than four characters, which is the maximum possible."
                            print line
                            print "Exiting."
                            exit(1)
                        line = ''.join(line)
                pdbFileOut.write(line)


def help():
    print "Usage: hqh_fes_prepare_cp2k_psf_dummy.py <psf filename in> <psf filename out>"
    

# Checking if this file is run as the main program 
if __name__ == '__main__':

    # Checking the number of arguments 
    if (len(sys.argv) != 3):
        help()
    else:
        main(*sys.argv[1:])