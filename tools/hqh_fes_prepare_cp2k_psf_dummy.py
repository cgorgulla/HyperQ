#!/usr/bin/env python
import sys

def main(psfFilenameIn, psfFilenameOut):

    with open(psfFilenameOut, "w") as psfFileOut:
        with open(psfFilenameIn, "r") as psfFileIn:
            currentSection = "not atoms"
            for line in psfFileIn:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not atoms"
                elif len(lineSplit) > 1:
                    if "!NATOM" in lineSplit[1]:
                        currentSection = "atoms"
                    elif currentSection == "atoms" and ("END" in line or "!" in line):
                        currentSection = "not atoms"
                    elif currentSection == "atoms" and len(lineSplit) == 9 and lineSplit[0].isdigit():
                        # Setting the charge to zero
                        lineSplit[6] = "0.000000"

                        # Setting the atom type to the atom name
                        if len(lineSplit[4]) <= 4: 
                            lineSplit[5] = lineSplit[4]
                        else:
                            print "Error: The atom name (field 5) of the following line of the psf file contains more than four characters, which is the maximum supported."
                            print "    " + line
                            print "Exiting."
                            exit(1)
                        line = '   {:>7} {:>3} {:>9} {:>8} {:>8} {:>8} {:>13} {:>8} {:>5}\n'.format(*lineSplit)

                # Writing the line to the output file
                psfFileOut.write(line)

def help():
    print "\nUsage: hqh_fes_prepare_cp2k_psf_dummy.py <psf filename in> <psf filename out>\n\n"


# Checking if this file is run as the main program
if __name__ == '__main__':

    # Checking the number of arguments
    if (len(sys.argv) != 3):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 2 input arguments. Exiting..."
        help()
        exit(1)

    else:
        main(*sys.argv[1:])