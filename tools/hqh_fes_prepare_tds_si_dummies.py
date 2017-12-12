#!/usr/bin/env python
from hyperq.cp2k_dummies import *

def run_cp2k_dummies(systemBasename, psfFilename, prmFilename, tdwCount, order):

    # Variables
    dummyAtomIndicesAll = []
    tdwCount = int(tdwCount)
    tdsCount = tdwCount + 1

    # Reading in the dummy atom indices
    with open(systemBasename + ".dummy.indices", "r") as systemDummyAtomIndicesFile:
        for line in systemDummyAtomIndicesFile:
            dummyAtomIndicesAll += map(int,line.split())

    # Creating the molecular system
    system = MolecularSystem(systemBasename, psfFilename, dummyAtomIndicesAll)

    # Computing the dummy atom distances
    system.dummyAtoms.compute_dummy_atom_distances()
    # Printing information on the distances and also writing them to a file
    print "\nOverview of dummies by distance"
    with open(systemBasename + ".dummies.distances.overview", "w") as dummyDistanceFile:
        for distance in range(1, max(system.dummyAtoms.distances)+1):
            indices = system.dummyAtoms.distanceToAtomIndices[distance]
            lineToPrint = " * Dummies with distance " + str(distance) + ": " + ", ".join([str(index) for index in indices])
            print lineToPrint
            dummyDistanceFile.write(lineToPrint+"\n")

    # # Computing the vdw radii
    # maxVdwRadiiByDistance = {distance:0 for distance in system.dummyAtoms.distances}
    # FFSystem = ForceField(prmFilename)
    # for distance in system.dummyAtoms.distances:
    #     indices = system.dummyAtoms.distanceToAtomIndices[distance]
    #     vdwRadii = []
    #     for atomIndex in indices:
    #         vdwRadii.append(FFSystem.LJParas.rminHalf(system.atomIndexToType(atomIndex)))
    #     maxVdwRadiiByDistance[distance] = max(vdwRadii)
    # # Sorting the maxVdwRadiiByDistanceSorted by their values, ascending
    # distanceSortedByVdWRadii = []
    # for key, value in sorted(maxVdwRadiiByDistance.iteritems(), key=lambda (k,v): (v,k)):
    #     print([key,value])
    #     distanceSortedByVdWRadii.append(key)

    # Computing the step width
    maximumDistance =  max(system.dummyAtoms.distances)
    dummyDistanceStepsizeBasic = maximumDistance // tdwCount
    dummyDistanceStepsizeRemainder = maximumDistance % tdwCount
    dummyDistanceStepsizes = {}             # Keys are the TDW indices
    for tdw_index in range(1, tdwCount+1):
        if dummyDistanceStepsizeRemainder == 0:
            dummyDistanceStepsizes[tdw_index] = dummyDistanceStepsizeBasic
        else:
            dummyDistanceStepsizes[tdw_index] = dummyDistanceStepsizeBasic+1
            dummyDistanceStepsizeRemainder -= 1


    # Computing the minimum dummy atom distances for each TDS (the number of dummy layers to include)
    minimumDistances = {}                  # Keys are the TDS indices. Each TDS has a range of allowed dummy atom distances, this variable specifies the minimum distance (where distance is the minimum path distance, thus it is a 'minimum' minimum distance)
    minimumDistances[1] = 1                # Needed (the first TDS) for the second TDS
    for tdsIndex in range(2, tdsCount+1):  # We index the TDS starting at 1, but TDS 1 always has distance 1 (all dummies included)
        minimumDistances[tdsIndex] = minimumDistances[tdsIndex-1] + dummyDistanceStepsizes[tdsIndex-1] # The dummyDistanceStepsizes are indexed by TDW index, thus are lower by 1
    print ""

    # Generating the dummy atom sets for each TDS and writing them to files
    dummyAtomIndicesTDS = {tdsIndex:set() for tdsIndex in range(1, tdsCount+1)}
    for tdsIndex in range(1, tdsCount+1):
        print "Writing the indices file for the TDS with index " + str(tdsIndex)

        # Determining the index of the output ID
        if order == "increasing":
            tdsOutputIndex = tdsIndex
        elif order == "decreasing":
            tdsOutputIndex = tdsCount + 1 - tdsIndex
        else:
            errorMessage = "Error: The input argument <tds index output order> does have an unsupported value."
            raise ValueError(errorMessage)

        # Getting the minimum dummy atom distance of the TDS
        minimumDistance = minimumDistances[tdsIndex]
        for distance in range(minimumDistance, maximumDistance+1):
            dummyAtomIndicesTDS[tdsIndex].update(system.dummyAtoms.distanceToAtomIndices[distance])
        with open(systemBasename + ".tds-" + str(tdsOutputIndex) + ".dummy.indices", "w") as tdsDummyFile:
            for index in dummyAtomIndicesTDS[tdsIndex]:
                tdsDummyFile.write(str(index) + " ")

    print ""

def help():
    print "\nUsage: hqh_fes_prepare_tds_si_dummies.py <systemBasename> <psf file> <prm file> <tdwCount> <tds index output order>\n"
    print "Prepares the dummy atom indices for the serial insertion thermodynamic cycles."
    print "Indices used internally are the ones of the psf files. -> atom order"
    print "The dummy atom indices are interpreted as the atom IDs used in the psf file."
    print "The psf file can be in any format."
    print "<tds index output order>: Possible values: increasing"
    print "                 * increasing: The core/non-dummy region of the molecule will increase (the dummies will decrease)."
    print "                 * decreasing: The core/non-dummy region of the molecule will decrease (the dummies will increase).\n\n"

# Checking if this file is run as the main program
if __name__ == '__main__':

    # Checking the number of arguments
    if (len(sys.argv) != 6):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 5 input arguments. Exiting..."
        help()
        exit(1)

    else:
        run_cp2k_dummies(*sys.argv[1:])