#!/usr/bin/env python
import sys

def main(psfFilenameIn, dummyAtomIndices, electrostaticsScalingFactor, transformAtomNames, psfFilenameOut):

    # Curating the input arguments
    if dummyAtomIndices != "all" and dummyAtomIndices != "ligand" :
        dummyAtomIndices = map(int,dummyAtomIndices.split())
    electrostaticsScalingFactor = float(electrostaticsScalingFactor)

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
                        if (type(dummyAtomIndices) is list and atomID in dummyAtomIndices) or (type(dummyAtomIndices) is str and (dummyAtomIndices == "all" or (dummyAtomIndices == "ligand" and lineSplit[1] == "LIG"))):

                            # Scaling the charge
                            lineSplit[6] = '{:8.6f}'.format(float(lineSplit[6])*electrostaticsScalingFactor)        # If the number is longer it will be used as such. Minus signs as well. The format number of digits is a minimum number for padding them if needed, or truncating decimal digits as far as I understand

                            # Setting the atom type dummy
                            if transformAtomNames.lower() == "true":
                                lineSplit[5] = "DUM"

                        # Reassembling the entire line
                        line = '   {:>7} {:>3} {:>9} {:>8} {:>8} {:>8} {:>13} {:>8} {:>5}\n'.format(*lineSplit)         # This will align all the input arguments from the left, padding them if needed with spaces. also the charge (lineSplit[6]) will be handled as desired since it was already transformed into a string.

                # Writing the line to the output file
                psfFileOut.write(line)

def help():
    print "\nUsage: hqh_fes_psf_transform_into_dummies.py <psf input file> <dummy atom indices> <electrostatics scaling factor> <transform atom names> <psf output file>"
    print ""
    print "The indices in the <dummy atom indices file> are interpreted as the atom IDs in the specified psf input file."
    print "The dummy atom indices argument can be:"
    print "     *) a list of integers separated by whitespaces"
    print "     *) 'ligand': All ligand atoms will be transformed"
    print "     *) 'all': All atoms will be transformed (ligand, receptor and solvent)"
    print "The input psf file can be in any format (vmd or psf)."
    print "The <electrostatics scaling factor> has to be a floating point number."
    print "<transform atom types> can be either set to 'false' or 'true'. If true, the atom types will be set to 'DUM'"
    print "The output psf file is in cp2k format"
    print ""
    print ""


# Checking if this file is run as the main program
if __name__ == '__main__':

    # Checking the number of arguments
    if (len(sys.argv) != 6):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 5 input arguments. Exiting..."
        help()
        exit(1)

    else:
        main(*sys.argv[1:])