#!/usr/bin/env python
import sys

def main(psfFilenameIn, dummyAtomIndiciesFile, psfFilenameOut):

    # Variables
    dummyAtomIndices = []

    # Reading in the dummy atom indices
    with open(dummyAtomIndiciesFile, "r") as systemDummyAtomIndicesFile:
        for line in systemDummyAtomIndicesFile:
            dummyAtomIndices += map(int,line.split())

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

                        # Checking if the current atom is a dummy atom
                        atomID = int(lineSplit[0])
                        if atomID in dummyAtomIndices:

                            # Setting the charge to zero
                            lineSplit[6] = "0.000000"

                            # Setting the atom type dummy
                            lineSplit[5] = "DUM"

                        # Reassembling the entire line
                        line = '   {:>7} {:>3} {:>9} {:>8} {:>8} {:>8} {:>13} {:>8} {:>5}\n'.format(*lineSplit)

                # Writing the line to the output file
                psfFileOut.write(line)

def help():
    print "\nUsage: hqh_fes_psf_transform_into_dummies.py <psf input file> <dummy atom indices file> <psf output file>"
    print ""
    print "The indices in the <dummy atom indices file> are interpreted as the atom IDs in the specified psf input file."
    print "The dummy atom indices file should contain indices in a single line separated by whitespaces."
    print "The input psf file can be in any format (vmd or psf)."
    print "The output psf file is in cp2k format"
    print ""
    print ""


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