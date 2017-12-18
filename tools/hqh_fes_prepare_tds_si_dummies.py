#!/usr/bin/env python
from __future__ import print_function
from hyperq.cp2k_dummies import *
import textwrap


class Atom:

    def __init__(self, atomIndex):

        self.atomIndex = atomIndex
        self.parentAtomIndex = None
        self.children = set()
        self.globalDistance = None
        self.totalDistance = None


def run_cp2k_dummies(systemBasename, psfFilename, prmFilename, tdwCountAllStages, hydrogenSingleStep, separateNeighbors, considerBranches, direction):

    # Variables
    dummyAtomIndicesAll = []
    tdwCountAllStages = int(tdwCountAllStages)
    tdsCountAllStages = tdwCountAllStages + 1
    #Todo: Rename all variables which contain the word dummy/dummies but are dummyAtomIndices accordingly to avoid confusion with the Atom objects

    # Reading in the dummy atom indices
    with open(systemBasename + ".dummy.indices", "r") as systemDummyAtomIndicesFile:
        for line in systemDummyAtomIndicesFile:
            dummyAtomIndicesAll += map(int,line.split())

    # Checking if there are dummy atoms at all
    if len(dummyAtomIndicesAll) == 0:

        print("There are no dummy atoms for this molecular system. Proceeding...\n")

        # Printing information on the distances and also writing them to a file
        open(systemBasename + ".dummy.distances", 'a').close()

        # Creating empty dummy atom files
        for tdsIndex in range(1, tdsCountAllStages+1):
            print("Writing the indices file for the TDS with index " + str(tdsIndex))
            # Determining the index of the output ID
            if direction == "increasing":
                tdsOutputIndex = tdsIndex
            elif direction == "decreasing":
                tdsOutputIndex = tdsCountAllStages + 1 - tdsIndex
            else:
                errorMessage = "Error: The input argument <tds index output order> has an unsupported value."
                raise ValueError(errorMessage)
            open(systemBasename + ".tds-" + str(tdsOutputIndex) + ".dummy.indices", 'a').close()
        exit(0)

    # Creating the molecular system
    system = MolecularSystem(systemBasename, psfFilename, dummyAtomIndicesAll)

    # Checking if there are hydrogen atoms at all
    if len(system.dummyAtoms.indicesNonH) <= 1 and hydrogenSingleStep.lower() == "true":        # also one hydrogen would not make sense to unify with itself, it seems in this case more advantageous to treat it the same way as the other atoms since this might reduce the global distance

        # Printing some information
        print("Info: At most one hydrogen dummy atom found for this molecular system. Setting the hydrogenSingleStep parameter to 'false' (overriding the specified value of 'true')")

        # If there are no hydrogens, the hydrogenSingleStep setting will be overwritten and set to false
        hydrogenSingleStep = "false"

    # Checking if there are sufficient TDWs
    if tdwCountAllStages == 1 and (separateNeighbors.lower() == "true" or hydrogenSingleStep.lower() == "true" ):

        # Printing some information
        print("Info: Only one TDW specified. Setting the separateNeighbors and hydrogenSingleStep parameters to 'false' (overriding the specified values)")

        # If there are no hydrogens, the hydrogenSingleStep setting will be overwritten and set to false
        hydrogenSingleStep = "false"
        separateNeighbors = "false"

    # Setting the stage1 variables (stage 1: include the TDS where the dummies are by distance. Stage 2 (optional, active if hydrogenSingleStep=true): all hydrogen atoms in an additional step)
    if hydrogenSingleStep.lower() == "false":
        tdsCountStage1 = tdsCountAllStages
    else:
        tdsCountStage1 = tdsCountAllStages - 1
    if hydrogenSingleStep.lower() == "false":
        tdwCountStage1 = tdwCountAllStages
    else:
        tdwCountStage1 = tdwCountAllStages - 1

    # Computing the global distances of the dummy atoms
    system.dummyAtoms.compute_dummy_atom_distances()

    # Computing the vdw radii
    maxVdwRadiusByGlobalDistance = {globalDistance:0 for globalDistance in system.dummyAtoms.distances}
    FFSystem = ForceField(prmFilename)
    for globalDistance in system.dummyAtoms.distances:
        indices = system.dummyAtoms.distanceToAtomIndices[globalDistance]
        vdwRadii = []
        for atomIndex in indices:
            vdwRadii.append(abs(float(FFSystem.LJParas.rminHalf[system.atomIndexToType[atomIndex]])))
        maxVdwRadiusByGlobalDistance[globalDistance] = max(vdwRadii)
    # # Sorting the maxVdwRadiiByDistanceSorted by their values, ascending
    # distanceSortedByVdWRadii = []
    # for key, value in sorted(maxVdwRadiiByDistance.iteritems(), key=lambda (k,v): (v,k)):
    #     print([key,value])
    #     distanceSortedByVdWRadii.append(key)


    # Computing the maximum global distance
    if hydrogenSingleStep.lower() == "false":
        maxGlobalDistanceStage1 = max(system.dummyAtoms.distances)
    elif hydrogenSingleStep.lower() == "true":
        maxGlobalDistanceStage1 = max(system.dummyAtoms.distancesNonH) # May or may not be smaller than with hydrogens, but we have now a separate final hydrogen step in any case
    else:
        errorMessage = "Error: The input argument <hydrogenSingleStep> has an unsupported value."
        raise ValueError(errorMessage)


    ## Computing the dummy atom clusters and their sizes
    # Variables
    dummyAtomsByGlobalDistance = {}
    atomClustersByGlobalDistance = {globalDistance:[] for globalDistance in range(1, maxGlobalDistanceStage1+1)}
    # Filling the dummyAtomsByGlobalDistance dictionary
    for globalDistance in range(1, maxGlobalDistanceStage1+1):
        if hydrogenSingleStep.lower() == "false":
            dummyAtomsByGlobalDistance[globalDistance] = system.dummyAtoms.distanceToAtomIndices[globalDistance]
        elif hydrogenSingleStep.lower() == "true":
            dummyAtomsByGlobalDistance[globalDistance] = system.dummyAtoms.distanceToAtomIndicesNonH[globalDistance]
        else:
            # Printing error message and raising an error
            errorMessage = "Error: The input argument <hydrogenSingleStep> has an unsupported value."
            raise ValueError(errorMessage)

    # Checking if the separate neighbor mode is activated
    if separateNeighbors.lower() == "true":

        # Loop for each distance
        print("maxGlobalDistanceStage1: " + str(maxGlobalDistanceStage1) )
        for globalDistance in range(1, maxGlobalDistanceStage1+1):

            # Variables
            clusterCount = 0
            atomsAdded = set()

            # Loop for each atom to add it to a cluster if needed
            print("dummyAtomsByGlobalDistance: " + str(dummyAtomsByGlobalDistance))
            for atomIndex in dummyAtomsByGlobalDistance[globalDistance]:
                print("atomIndex: " + str(atomIndex))

                # Variables
                newCluster = True

                # Loop for each cluster to check if the atom is already in a cluster
                for clusterIndex in range(0, len(atomClustersByGlobalDistance[globalDistance])):

                    # Checking if the atom is already in the cluster
                    print("atomClustersByGlobalDistance[globalDistance][clusterIndex]: " + str(atomClustersByGlobalDistance[globalDistance][clusterIndex]))
                    if atomIndex in atomClustersByGlobalDistance[globalDistance][clusterIndex]:

                        # Printing some information
                        print("Atom already in existing cluster...")

                        # Setting the skipAtom flag
                        newCluster = False

                        # Adding all angled atoms to the cluster, whether the cluster is new not, but excluding atoms which were already added to make the clusters disjoint (Alternative: allow for overlapping clusters and unite them afterwards)
                        if hydrogenSingleStep.lower() == "false":
                            atomsToAdd = (system.dummyAtoms.angledAtoms[atomIndex] & dummyAtomsByGlobalDistance[globalDistance])-atomsAdded
                        else:
                            atomsToAdd = (system.dummyAtoms.angledAtoms[atomIndex] & dummyAtomsByGlobalDistance[globalDistance] & set(system.dummyAtoms.indicesNonH))-atomsAdded
                        atomClustersByGlobalDistance[globalDistance][clusterIndex].update(atomsToAdd)
                        atomsAdded.update(atomsToAdd)

                # Checking if a new cluster should be created
                if newCluster == True:

                    # Printing some information
                    print("Atom not found in existing cluster. Creating new cluster...")

                    # Creating a new cluster
                    atomClustersByGlobalDistance[globalDistance].append(set())
                    clusterCount += 1
                    atomClustersByGlobalDistance[globalDistance][clusterCount-1].add(atomIndex)

                    # Adding all angled atoms to the cluster, whether the cluster is new not
                    if hydrogenSingleStep.lower() == "false":
                        atomClustersByGlobalDistance[globalDistance][clusterCount-1].update(system.dummyAtoms.angledAtoms[atomIndex] & dummyAtomsByGlobalDistance[globalDistance])
                    else:
                        atomClustersByGlobalDistance[globalDistance][clusterCount-1].update(system.dummyAtoms.angledAtoms[atomIndex] & dummyAtomsByGlobalDistance[globalDistance] & set(system.dummyAtoms.indicesNonH))

                # Unifying the non-disjoint clusters


    # Checking if the separate neighbor mode is deactivated
    elif separateNeighbors.lower() == "false":

        # Loop for each distance
        for globalDistance in range(1, maxGlobalDistanceStage1+1):

            ## In this case there is only one cluster per global distance, containing all the dummy atoms of that distance
            #atomClustersByGlobalDistance[globalDistance].append(set(dummyAtomsByGlobalDistance[globalDistance]))
            # Loop for each atom of the current global distance
            clusterCount = 0
            for atomIndex in dummyAtomsByGlobalDistance[globalDistance]:

                # Creating a new cluster for each atom
                atomClustersByGlobalDistance[globalDistance].append(set())
                clusterCount += 1
                atomClustersByGlobalDistance[globalDistance][clusterCount-1].add(atomIndex)
    else:

        # Printing error message and raising an error
        errorMessage = "Error: The input argument <separateNeighbors> has an unsupported value."
        raise ValueError(errorMessage)

    # Computing the maximum cluster size for each global distance
    maxClusterSizeByGlobalDistance = {}
    for globalDistance in range(1, maxGlobalDistanceStage1+1):

        # Computing the maximum cluster size
        maxClusterSizeByGlobalDistance[globalDistance] = max([len(cluster) for cluster in atomClustersByGlobalDistance[globalDistance]])

    # Creating linear lists of the atom clusters for stage 1
    atomSetsTotalLinearStage1 = []          # total = global + expanded local steps
    dummyAtoms = {dummyAtomIndex:Atom(dummyAtomIndex) for dummyAtomIndex in dummyAtomIndicesAll}
    totalDistanceToDummyAtomIndices = {}
    dummyAtomIndexToTotalDistance = {}
    if separateNeighbors.lower() == "true" and considerBranches.lower() == "true":

        # Adding a pseudo root dummy atom
        dummyAtoms[0] = Atom(0) # Root atom (parent) for the dummy atoms of global distance 1
        dummyAtoms[0].globalDistance = 0
        dummyAtoms[0].totalDistance = 0

        # Recursive function to determine the atom tree
        def findChildren(currentAtom):

            # Finding the children
            if currentAtom.atomIndex == 0:
                childrenAtomIndices = dummyAtomsByGlobalDistance[1]
            else:
                if currentAtom.globalDistance < maxGlobalDistanceStage1:
                    childrenAtomIndices = dummyAtomsByGlobalDistance[currentAtom.globalDistance+1] & system.bondedAtoms[currentAtom.atomIndex]
                else:
                    childrenAtomIndices = set()

            # Loop for each children
            nextChildTotalDistanceDifference = 1
            for childrenAtomIndex in childrenAtomIndices:

                # Checking if the child has a parent
                if dummyAtoms[childrenAtomIndex].parentAtomIndex == None:

                    # The current atom will adopt this child
                    dummyAtoms[childrenAtomIndex].parentAtomIndex = currentAtom.atomIndex

                    # Checking if the current atom is the root dummy atom
                    if currentAtom.atomIndex == 0:

                        # Resetting the nextChildTotalDistanceDifference
                        nextChildTotalDistanceDifference = 1

                        # Checking to how many other children which were already treated the current atom is angled in order to determine the total distance (useful if multiple dummies are connected to the same non-dummy (root) atom)
                        for dummyAtomIndexToCheck in dummyAtomsByGlobalDistance[1]:
                            # Checking if the atom to be checked was already initialized
                            if dummyAtoms[dummyAtomIndexToCheck].totalDistance != None:
                                if dummyAtomIndexToCheck in system.dummyAtoms.angledAtoms[childrenAtomIndex]:
                                    nextChildTotalDistanceDifference += 1

                        childrenTotalDistance = nextChildTotalDistanceDifference

                    else:
                        childrenTotalDistance = currentAtom.totalDistance + nextChildTotalDistanceDifference
                        nextChildTotalDistanceDifference += 1

                    # Setting properties
                    dummyAtoms[childrenAtomIndex].totalDistance = childrenTotalDistance
                    dummyAtoms[childrenAtomIndex].globalDistance = system.dummyAtoms.atomIndexToDistance[childrenAtomIndex]

                    # Updating variables
                    dummyAtomIndexToTotalDistance[childrenAtomIndex] = dummyAtoms[childrenAtomIndex].totalDistance

                    # Letting the child find its own children
                    findChildren(dummyAtoms[childrenAtomIndex])

        # Determining the atom tree
        findChildren(dummyAtoms[0])

        # Computing the maximum total distance
        maxTotalDistanceStage1 = max([dummyAtoms[dummyAtomIndex].totalDistance for dummyAtomIndex in dummyAtoms])

        # Creating the atomSetsTotalLinearStage1 variable
        for totalDistance in range(1, maxTotalDistanceStage1 +1):

            # Finding out which dummy atoms have the same totalDistance
            localDummyAtoms = set()
            for dummyAtomIndex in dummyAtoms:
                if dummyAtoms[dummyAtomIndex].totalDistance == totalDistance:
                    localDummyAtoms.add(dummyAtomIndex)

            # Updating variables
            atomSetsTotalLinearStage1.append(localDummyAtoms)

    else:

        # Creating the atomSetsTotalLinearStage1 variable
        totalDistance = 0
        for globalDistance in range(1, maxGlobalDistanceStage1+1):
            print("Global distance: " + str(globalDistance))
            for localDistance in range(1, maxClusterSizeByGlobalDistance[globalDistance]+1):
                totalDistance += 1
                print("Local distance: " + str(localDistance))
                localDummyAtoms = set()
                for cluster in atomClustersByGlobalDistance[globalDistance]:
                    cluster = list(cluster)
                    print("Cluster atoms: ", cluster)
                    if len(cluster) >= localDistance:
                        localDummyAtoms.add(cluster[localDistance-1])  # Add, not update, because we add a single atom
                atomSetsTotalLinearStage1.append(localDummyAtoms)
                for atomIndex in localDummyAtoms:
                    dummyAtomIndexToTotalDistance[atomIndex] = totalDistance
                    dummyAtoms[atomIndex].totalDistance = totalDistance
                    dummyAtoms[atomIndex].globalDistance = globalDistance

        # Computing the total length (= global length expanded by the local clusters)
        maxTotalDistanceStage1 = len(atomSetsTotalLinearStage1)


    if hydrogenSingleStep.lower() == "false":
        maxTotalDistanceAllStages = maxTotalDistanceStage1
    else:
        maxTotalDistanceAllStages = maxTotalDistanceStage1 + 1


    # Computing the distance stepsizes for stage 1 (stage 1: added by distance. Stage 2 (optional): additional hydrogen atoms)
    dummyDistanceStepsizeBasic = maxTotalDistanceStage1 // tdwCountStage1
    dummyDistanceStepsizeRemainder = maxTotalDistanceStage1 % tdwCountStage1
    dummyDistanceStepsizes = {}             # Keys are the TDW indices
    for stepIndex in range(1, tdwCountStage1+1):
        if dummyDistanceStepsizeRemainder == 0:
            dummyDistanceStepsizes[stepIndex] = dummyDistanceStepsizeBasic
        else:
            dummyDistanceStepsizes[stepIndex] = dummyDistanceStepsizeBasic+1
            dummyDistanceStepsizeRemainder -= 1


    # Computing the minimum dummy atom total distances for each TDS of stage1 (the number of dummy layers to include)
    tdsMinTotalDistancesStage1 = {}                                             # Keys are the TDS indices. Each TDS has a range of allowed dummy atom distances, this variable specifies the minimum distance (where distance is the minimum path distance, thus it is a 'minimum' minimum distance)
    tdsMinTotalDistancesStage1[1] = 1                                           # The Minimum distance for the first TDS is always 1 (no dummies). Setting it here before the loop because it is needed for the second TDS
    for tdsIndex in range(2, tdsCountStage1+1):                                 # We index the TDS starting at 1, but TDS 1 always has distance 1 (all dummies included). This index might not be the index used by HyperQ (e.g. if electrostatics gives rise to additional TDSs)
        tdsMinTotalDistancesStage1[tdsIndex] = tdsMinTotalDistancesStage1[tdsIndex-1] + dummyDistanceStepsizes[tdsIndex-1] # The dummyDistanceStepsizes are indexed by TDW index, thus are lower by 1


    # If hydrogenSingleStep = true it will be determined which TDS is the one with only hydrogen dummy atoms left
    tdwIndexStage2 = None
    tdsCountStage1Adjusted = tdsCountStage1
    tdwCountStage1Adjusted = tdwCountStage1
    if hydrogenSingleStep.lower() == "true":

        # Determining the TDW in which only the hydrogen are transformed (stage 2). It can only be an earlier TDW than the last one if dummyDistanceStepsizes = 0 for some TDW
        tdwIndexStage2 = tdwCountAllStages
        for tdwIndex in range(1, tdwCountStage1+1):
            if dummyDistanceStepsizes[tdwIndex] == 0:
                tdwIndexStage2 = tdwIndex # TDS 1 - TDW 1 - TDS 2 - ...
                tdsCountStage1Adjusted = tdwIndexStage2
                tdwCountStage1Adjusted = tdwIndexStage2-1
                break


    # Generating the dummy atom sets for each TDS of stage 1
    tdsDummyAtomIndices = {tdsIndex:set() for tdsIndex in range(1, tdsCountAllStages+1)}
    tdwDummyAtomsToRemove = {tdsIndex:set() for tdsIndex in range(1, tdsCountAllStages+1)}
    for tdsIndex in range(1, tdsCountStage1Adjusted+1):
        # Getting the minimum dummy atom distance of the TDS
        minTotalDistance = tdsMinTotalDistancesStage1[tdsIndex]
        for totalDistance in range(minTotalDistance, maxTotalDistanceStage1+1):
            tdsDummyAtomIndices[tdsIndex].update(atomSetsTotalLinearStage1[totalDistance-1])

        # Adding the hydrogen dummies if hydrogenSingleStep=true
        if hydrogenSingleStep.lower() == "true":
            tdsDummyAtomIndices[tdsIndex].update(system.dummyAtoms.indicesH)

        # Updating the tdwDummyAtomsToRemove (not used by the main code, only for the human readable information output)
        if tdsIndex >= 2:
            minTotalDistanceLastTds = tdsMinTotalDistancesStage1[tdsIndex-1]
            for totalDistance in range(minTotalDistanceLastTds, minTotalDistance):
                tdwDummyAtomsToRemove[tdsIndex-1].update(atomSetsTotalLinearStage1[totalDistance-1])


    # If hydrogenSingleStep = true we need to manually add the last hydrogen step
    if hydrogenSingleStep.lower() == "true":

        # Updating the tdwDummyAtomsToRemove
        tdwDummyAtomsToRemove[tdwIndexStage2].update(system.dummyAtoms.indicesH)

        # Adding all dummy atoms including hydrogens to the last TDS
        #tdsDummyAtomIndices[tdsIndexStage2] = set() # Nothing to do, the last TDS has no dummies



    # Writing the dummy atom sets for each TDS to files
    for tdsIndex in range(1, tdsCountAllStages+1):

        # Printing some information
        print("Writing the indices file for the TDS with index " + str(tdsIndex) + "\n")

        # Determining the index of the output ID
        if direction == "increasing":
            tdsOutputIndex = tdsIndex
        elif direction == "decreasing":
            tdsOutputIndex = tdsCountAllStages + 1 - tdsIndex
        else:
            errorMessage = "Error: The input argument <tds index output order> has an unsupported value."
            raise ValueError(errorMessage)

        with open(systemBasename + ".tds-" + str(tdsOutputIndex) + ".dummy.indices", "w") as tdsDummyFile:
            for index in tdsDummyAtomIndices[tdsIndex]:
                tdsDummyFile.write(str(index) + " ")


    # Printing information about the distances and corresponding dummy atoms and writing them to a file
    with open(systemBasename + ".tdcycle.si.info.dummies", "w") as dummyDistanceFile:

        # General information (including all hydrogens)
        lineToPrint = "\n\n\n{:^120}\n".format("General information on the dummy atoms and the insertion mode")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Single step for hydrogens: " + str(hydrogenSingleStep) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Separation of neighbors: " + str(separateNeighbors) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Consideration of branches: " + str(considerBranches) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "TDW count w.r.t. all stages: " + str(tdwCountAllStages) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "TDS count w.r.t. all stages: " + str(tdsCountAllStages) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "TDW count w.r.t. stage 1: " + str(tdwCountStage1Adjusted) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "TDS count w.r.t. stage 1: " + str(tdsCountStage1Adjusted) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Maximum global depth: " + str(maxGlobalDistanceStage1) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Dummy atom count: " + str(len(system.dummyAtoms.indices)) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Non-hydrogen dummy atom count: " + str(len(system.dummyAtoms.indicesNonH)) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Hydrogen dummy atom count: " + str(len(system.dummyAtoms.indicesH)) + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Dummy atom indices: " + textwrap.fill(", ".join([str(index) for index in system.dummyAtoms.indices]), width=80, subsequent_indent="                    ") + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Non-hydrogen dummy atom indices: " + textwrap.fill(", ".join([str(index) for index in system.dummyAtoms.indicesNonH]), width=80, subsequent_indent="                    ") + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "Hydrogen dummy atom indices: " + textwrap.fill(", ".join([str(index) for index in system.dummyAtoms.indicesH]), width=80, subsequent_indent="                    ") + "\n"
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        dummyDistanceFile.write("\n\n")
        print("\n\n")

        # Overview of dummies by global distance within all stages (including hydrogen dummy atoms)
        lineToPrint = "\n{:^120}\n".format("Overview of dummies by global distance within all stages (including hydrogen dummy atoms)")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^20s} {:^20s} {}\n".format("Global Distance", "Maximum VdW Radius", "Dummy Atom Indices")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        for globalDistance in range(1, max(system.dummyAtoms.distances)+1):
            indices = system.dummyAtoms.distanceToAtomIndices[globalDistance]
            lineToPrint = "{:^20s} {:^20s} {}\n".format(str(globalDistance), str(maxVdwRadiusByGlobalDistance[globalDistance]), " " + ", ".join([str(index) for index in indices]))
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
        dummyDistanceFile.write("\n\n")
        print("\n\n")

        # Overview of dummies by global distance within stage 1 (possibly without hydrogen atoms)
        lineToPrint = "\n{:^120}\n".format("Overview of the global distances within stage 1")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^20s} {:^25} {:^20s} {:^25s} {}\n".format("Global Distance", "Maximum VdW Radius", "Number of Clusters", "Maximum Cluster Size", "Dummy Atom Indices")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        for globalDistance in range(1, maxGlobalDistanceStage1+1):
            indices = dummyAtomsByGlobalDistance[globalDistance]
            lineToPrint = "{:^20s} {:^25s} {:^20s} {:^25} {}\n".format(str(globalDistance), str(maxVdwRadiusByGlobalDistance[globalDistance]), str(len(atomClustersByGlobalDistance[globalDistance])), str(maxClusterSizeByGlobalDistance[globalDistance]), " " + ", ".join([str(index) for index in indices]))
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
        dummyDistanceFile.write("\n\n")
        print("\n\n")

        # Overview of dummies by total distance within stage 1 (possibly without hydrogens)
        lineToPrint = "\n{:^120}\n".format("Overview of dummies by total distance within stage 1")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^20s} {}\n".format("Total Distance", "Dummy Atom Indices")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        for totalDistance in range(1, maxTotalDistanceStage1+1):
            indices = atomSetsTotalLinearStage1[totalDistance-1]
            lineToPrint = "{:^20s} {}\n".format(str(totalDistance), " " + ", ".join([str(index) for index in indices]))
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
        dummyDistanceFile.write("\n\n")
        print("\n\n")

        # Overview of the TDS within all stages
        lineToPrint = "\n{:^120}\n".format("Overview of the TDSs within all stages")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^20s} {}\n".format("TDS", "Dummy Atom Indices")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        for tdsIndex in range(1, tdsCountAllStages+1):
            indices = tdsDummyAtomIndices[tdsIndex]
            lineToPrint = "{:^20s} {}\n".format(str(tdsIndex), " " + ", ".join([str(index) for index in indices]))
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
        dummyDistanceFile.write("\n\n")
        print("\n\n")

        # Overview of the TDWs within all stages
        lineToPrint = "\n{:^120}\n".format("Overview of the TDWs within all stages")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^20s} {:^30s} {}\n".format("TDW", "Step Size (total distance)", "Transformed Atoms")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        for tdwIndex in range(1, tdwCountAllStages+1):
            indices = tdwDummyAtomsToRemove[tdwIndex]
            if hydrogenSingleStep.lower() == "true" and tdwIndex >= tdwIndexStage2:  # TDS1 - TDW1 - TDS2 - TDW2 ...
                lineToPrint = "{:^20s} {:^30s} {}\n".format(str(tdwIndex), "N/A (stage 2)", " " + ", ".join([str(index) for index in indices]))
            else:
                lineToPrint = "{:^20s} {:^30s} {}\n".format(str(tdwIndex), str(dummyDistanceStepsizes[tdwIndex]), " " + ", ".join([str(index) for index in indices]))
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
        dummyDistanceFile.write("\n\n")
        print("\n\n")

        # Info about stage 2 if present
        if hydrogenSingleStep.lower() == "true":
            # Global information (including all hydrogens)
            lineToPrint = "\n{:^120}\n".format("Overview about stage 2 which is present for this system")
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
            lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
            lineToPrint = "(First) TDW of stage 2: " + str(tdwIndexStage2) + "\n"
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
            lineToPrint = "Hydrogen dummy atom indices: " + ", ".join([str(index) for index in system.dummyAtoms.indicesH])
            print(lineToPrint, end="")
            dummyDistanceFile.write(lineToPrint)
            dummyDistanceFile.write("\n\n")
            print("\n\n")

        # Infos about the dummy atoms
        lineToPrint = "\n{:^120}\n".format("Information about the dummy atoms")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^120}\n\n".format("********************************************************************************************************************************************")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        lineToPrint = "{:^10s} {:^10s} {:^20s} {:^20s} {:^15s} {:^15s} {:^15s} {:^15s}\n".format("Dummy ID", "Stage", "Global Distance", "Total Distance", "Parent ID", "Atom name", "Atom type", "VdW Radius")
        print(lineToPrint, end="")
        dummyDistanceFile.write(lineToPrint)
        for totalDistance in range(1, maxTotalDistanceStage1 + 1):
            for dummyAtomIndex in atomSetsTotalLinearStage1[totalDistance-1]:
                lineToPrint = "{:^10s} {:^10s} {:^20s} {:^20s} {:^15s} {:^15s} {:^15s} {:^15s}\n".format(str(dummyAtomIndex), "1", str(system.dummyAtoms.atomIndexToDistance[dummyAtomIndex]), str(dummyAtoms[dummyAtomIndex].totalDistance), str(dummyAtoms[dummyAtomIndex].parentAtomIndex), system.atomIndexToName[dummyAtomIndex], system.atomIndexToType[dummyAtomIndex], str(abs(float(FFSystem.LJParas.rminHalf[system.atomIndexToType[dummyAtomIndex]]))))
                print(lineToPrint, end="")
                dummyDistanceFile.write(lineToPrint)
        if hydrogenSingleStep.lower() == "true":
            for dummyAtomIndex in system.dummyAtoms.indicesH:
                lineToPrint = "{:^10s} {:^10s} {:^20s} {:^20s} {:^15s} {:^15s} {:^15s} {:^15s}\n".format(str(dummyAtomIndex), "2", str(system.dummyAtoms.atomIndexToDistance[dummyAtomIndex]), str(dummyAtoms[dummyAtomIndex].totalDistance), str(dummyAtoms[dummyAtomIndex].parentAtomIndex), system.atomIndexToName[dummyAtomIndex], system.atomIndexToType[dummyAtomIndex], str(abs(float(FFSystem.LJParas.rminHalf[system.atomIndexToType[dummyAtomIndex]]))))
                print(lineToPrint, end="")
                dummyDistanceFile.write(lineToPrint)

        dummyDistanceFile.write("\n\n")
        print("\n\n")


        # Finalizing the output
        dummyDistanceFile.write("\n")
        print("\n")



def help():
    print("\nUsage: hqh_fes_prepare_tds_si_dummies.py <systemBasename> <psf file> <prm file> <tdw_count> <hydrogen single step> <separate neighbors> <consider branches> <tds index output direction>\n")
    print("Prepares the dummy atom indices for the serial insertion thermodynamic cycles.")
    print("Indices used internally are the ones of the psf files. -> atom order")
    print("The dummy atom indices are interpreted as the atom IDs used in the psf file.")
    print("The psf file can be in any format.")
    print("<hydrogen single step>: Possible values: False, True")
    print("<separate neighbors>: Possible values: False, True")
    print("<consider branches>: Possible values: False, True. Only relevant if <separate neighbors>=True")
    print("<tdw_count> refers only to the TDWs which should be considered by the serial insertion mechanism.")
    print("<tds index output direction>: Possible values: increasing")
    print("                 * increasing: The core/non-dummy region of the molecule will increase (the dummies will decrease).")
    print("                 * decreasing: The core/non-dummy region of the molecule will decrease (the dummies will increase).\n\n")


# Checking if this file is run as the main program
if __name__ == '__main__':

    # Checking the number of arguments
    if (len(sys.argv) != 9):
        print("Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv))
        print("Required are 8 input arguments. Exiting...")
        help()
        exit(1)

    else:
        run_cp2k_dummies(*sys.argv[1:])