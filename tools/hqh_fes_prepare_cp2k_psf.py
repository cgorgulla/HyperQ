#!/usr/bin/env python
import sys

def main(psfFilenameIn, psfFilenameOut):
    
    with open(psfFilenameOut, "w") as pdbFileOut:
        with open(psfFilenameIn, "r") as pdbFileIn:
            currentSection = "not atoms"
            for line in pdbFileIn:
                lineSplit = line.split()
                # Modifying the first line
                if line[0:3] == "PSF":
                    line = "PSF"

                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not atoms"
                elif len(lineSplit) > 1:
                    if "!NATOM" in lineSplit[1]:
                        currentSection = "atoms"
                    elif currentSection == "atoms" and ("END" in line or "!" in line):
                        currentSection = "not atoms"
                    elif currentSection == "atoms" and len(lineSplit) == 9 and lineSplit[0].isdigit():
                        line = '   {:>7} {:>3} {:>9} {:>8} {:>8} {:>8} {:>13} {:>8} {:>5}\n'.format(*lineSplit)

                pdbFileOut.write(line)


def help():
    print "\nUsage: hqh_fes_prepare_cp2k_psf_dummy.py <psf filename in> <psf filename out>\n\n"


# Checking if this file is run as the main program
if __name__ == '__main__':

    # Checking the number of arguments
    if (len(sys.argv) != 3):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 2 parameters. Exiting..."
        help()
        exit(1)

    else:
        main(*sys.argv[1:])