#!/usr/bin/env python
import sys
import math

class DummyAtoms:
    
    def __init__(self, indices, molecularSystem):

        # Variables
        self.dummyCount = len(indices)
        self.indices = indices          # A list
        self.indicesH = []
        self.indicesNonH = []
        self.molecularSystem = molecularSystem
        
        # Bonds 
        self.dummyAtomIndexToBondedAtoms = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        self.allBondedAtoms = set()
        self.allBondedAtomsWithoutDummies = set()
        self.bonds = {index: [] for index in self.indices}
        for bond in molecularSystem.bonds:
            for dummyAtomIndex in self.indices:
                if dummyAtomIndex in bond:
                    self.bonds[dummyAtomIndex].append(bond)
                    for atomIndex in bond:
                        if atomIndex != dummyAtomIndex:
                            self.dummyAtomIndexToBondedAtoms[dummyAtomIndex].add(int(atomIndex))
                        self.allBondedAtoms.add(int(atomIndex))
        self.allBondedAtomsWithoutDummies = self.allBondedAtoms - set(self.indices)

        # Angles
        self.angledAtoms = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        self.angles = {index: [] for index in self.indices}
        for angle in molecularSystem.angles:
            for dummyAtomIndex in self.indices:
                if dummyAtomIndex in angle:
                    self.angles[dummyAtomIndex].append(angle)
                    for atomIndex in angle:
                        #if atomIndex != dummyAtomIndex:
                        self.angledAtoms[dummyAtomIndex].add(atomIndex)

        # Dihedrals
        self.dihedraledAtoms = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        self.dihedrals = {index: [] for index in self.indices}
        for dihedral in molecularSystem.dihedrals:
            for dummyAtomIndex in self.indices:
                if dummyAtomIndex in dihedral:
                    self.dihedrals[dummyAtomIndex].append(dihedral)
                    for atomIndex in dihedral:
                        if atomIndex != dummyAtomIndex:
                            self.dihedraledAtoms[dummyAtomIndex].add(atomIndex)

        # Improper
        self.improperedAtoms = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        self.impropers = {index: [] for index in self.indices}
        for improper in molecularSystem.impropers:
            for dummyAtomIndex in self.indices:
                if dummyAtomIndex in improper:
                    self.impropers[dummyAtomIndex].append(improper)
                    for atomIndex in improper:
                        if atomIndex != dummyAtomIndex:
                            self.improperedAtoms[dummyAtomIndex].add(atomIndex)

        # Nonangled Atom Indices
        self.nonangledAtomIndices = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        for dummyAtomIndex in self.indices:
            dummyAtomSegment = self.molecularSystem.atomIndexToSegment[dummyAtomIndex]
            self.nonangledAtomIndices[dummyAtomIndex] = molecularSystem.segmentToIndices[dummyAtomSegment] - self.angledAtoms[dummyAtomIndex]
        
        # Nonangled Atoms Names
        self.nonangledAtomNames = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        for dummyAtomIndex in self.indices:
            for atomIndex in self.nonangledAtomIndices[dummyAtomIndex]:
                self.nonangledAtomNames[dummyAtomIndex].add(molecularSystem.atomIndexToName[atomIndex])

        # Hydrogen and non-hydrogen dummies
        for dummyAtomIndex in self.indices:
            if molecularSystem.atomIndexToName[dummyAtomIndex][0] == "H" and isfloat(molecularSystem.atomIndexToName[dummyAtomIndex][1]):
                self.indicesH.append(dummyAtomIndex)
            else:
                self.indicesNonH.append(dummyAtomIndex)

        # Dummy atom distances
        self.atomIndexToDistance = None
        self.distances = None
        self.distancesNonH = None
        self.distanceToAtomIndices = None
        self.distanceToAtomIndicesNonH = None


    def compute_dummy_atom_distances(self):

        # Preparing the atom index to distance conversion
        self.atomIndexToDistance = {}

        # All dummy atoms
        # Loop for each dummy atom
        for dummyAtomIndex in self.indices:
            self.atomIndexToDistance[dummyAtomIndex] = self.compute_dummy_atom_distance(dummyAtomIndex)
        # Preparing the set of all distances
        self.distances = set(self.atomIndexToDistance.values())
        # Preparing the distance to index dictionary for all dummies
        self.distanceToAtomIndices = {distance: set() for distance in self.distances}
        for dummyAtomIndex in self.indices:
            self.distanceToAtomIndices[self.atomIndexToDistance[dummyAtomIndex]].add(dummyAtomIndex)

        # Only non-hydrogen dummy atoms
        # Preparing the set of all distances
        self.distancesNonH = set(self.atomIndexToDistance[dummyAtomIndex] for dummyAtomIndex in self.indicesNonH)

        # Preparing the distance to index dictionary for the non-hydrogen atoms only
        self.distanceToAtomIndicesNonH = {distance: set() for distance in self.distancesNonH}
        for dummyAtomIndex in self.indicesNonH:
            self.distanceToAtomIndicesNonH[self.atomIndexToDistance[dummyAtomIndex]].add(dummyAtomIndex)


    def compute_dummy_atom_distance(self, dummyAtomIndex):

        # Variables
        dummyAtomDistances = []

        # Nested functions
        print "\n\nComputing the distance for dummy atom (root) with index " + str(dummyAtomIndex)
        print "********************************************************************"

        # Defining the recursive function which checks the bonded neighboring atoms
        def find_distances(atomIndex, distance, atomIndicesToIgnore):

            # Checking if there is a neighbor which is not a dummy
            print "\nTesting the bonded neighbors of dummy atom: " + str(atomIndex)
            print " * Current distance from the root dummy atom is: " + str(distance)
            print " * Atoms already visited during the path search: " + ", ".join([str(item) for item in atomIndicesToIgnore])
            for bondedAtomIndex in self.dummyAtomIndexToBondedAtoms[atomIndex] - atomIndicesToIgnore:
                print " * Testing bonded atom: " + str(bondedAtomIndex)
                if bondedAtomIndex not in self.indices:
                    print "   * The tested bonded atom is not a dummy atom. Saving the current distance in the list of found path distances."
                    dummyAtomDistances.append(distance)
                else:
                    print "   * The tested bonded atom is a dummy atom. Testing this bonded atom for its own neighbors"
                    atomIndicesToIgnoreNew = atomIndicesToIgnore.copy()
                    atomIndicesToIgnoreNew.add(atomIndex)
                    find_distances(bondedAtomIndex, distance + 1, atomIndicesToIgnoreNew)

        # Computing the shortest distance to the non-dummy atoms
        find_distances(dummyAtomIndex, 1, set())

        # Returning the shortest dummy atom distance
        return min(dummyAtomDistances)

    # Function for writing the bonded atoms of the dummies
    def writeBondedAtoms(self, outputFilename):

        # Writing the bonded atom indices to a file
        with open(outputFilename, "w") as outputFile:
            for atomIndex in self.allBondedAtoms:
                outputFile.write(str(atomIndex) + " ")


class MolecularSystem:
    
    def __init__(self, systemName, psfFilename, dummyAtomIndices):

        self.systemName = systemName
        self.atomIndices = set()
        self.atomIndexToName = {}
        self.atomIndexToType = {}
        self.bonds = []
        self.angles = []
        self.dihedrals = []
        self.impropers = []
        self.atomNames = set()
        self.atomNameToType = {}
        self.segments = set()
        self.atomIndexToSegment = {}
        
        # All atom indices, names, types, segment
        with open(psfFilename, "r") as psf_file:
            currentSection = "not atoms"
            for line in psf_file:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not atoms"
                elif len(lineSplit) > 1:
                    if "!NATOM" in lineSplit[1]:
                        currentSection = "atoms"
                    elif currentSection == "atoms" and ("END" in line or "!" in line):
                        currentSection = "not atoms"
                    elif currentSection == "atoms":
                        self.atomIndices.add(int(lineSplit[0]))
                        self.atomIndexToName[int(lineSplit[0])] = lineSplit[4]
                        self.atomIndexToType[int(lineSplit[0])] = lineSplit[5]
                        self.segments.add(lineSplit[1])
                        self.atomIndexToSegment[int(lineSplit[0])] = lineSplit[1]
        
        # Atom names to types dictionary
        for atomIndex in self.atomIndices:
            atomName = self.atomIndexToName[atomIndex]
            atomType = self.atomIndexToType[atomIndex]
            self.atomNames.add(atomName)
            self.atomNameToType[atomName] = atomType
        
        # All bonds
        with open(psfFilename, "r") as psf_file:
            currentSection = "not bonds"
            for line in psf_file:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not bonds"
                elif len(lineSplit) > 1:
                    if "!NBOND" in lineSplit[1]:
                        currentSection = "bonds"
                    elif currentSection == "bonds" and ("END" in line or "!" in line):
                        currentSection = "not bonds"
                    elif currentSection == "bonds":
                        if all(isfloat(item) for item in lineSplit):
                            for bond in zip(*[iter(lineSplit)] * 2):
                                self.bonds.append(map(int,bond))

        # All angles
        with open(psfFilename, "r") as psf_file:
            currentSection = "not angles"
            for line in psf_file:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not angles"
                elif len(lineSplit) > 1:
                    if "!NTHETA" in lineSplit[1]:
                        currentSection = "angles"
                    elif currentSection == "angles" and ("END" in line or "!" in line):
                        currentSection = "not angles"
                    elif currentSection == "angles":
                        if all(isfloat(item) for item in lineSplit):
                            for angle in zip(*[iter(lineSplit)] * 3):
                                self.angles.append(map(int,angle))

        # All dihedrals
        with open(psfFilename, "r") as psf_file:
            currentSection = "not dihedrals"
            for line in psf_file:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not dihedrals"
                elif len(lineSplit) > 1:
                    if "!NPHI" in lineSplit[1]:
                        currentSection = "dihedrals"
                    elif currentSection == "dihedrals" and ("END" in line or "!" in line):
                        currentSection = "not dihedrals"
                    elif currentSection == "dihedrals":
                        if all(isfloat(item) for item in lineSplit):
                            for dihedral in zip(*[iter(lineSplit)] * 4):
                                self.dihedrals.append(map(int,dihedral))

        # All impropers
        with open(psfFilename, "r") as psf_file:
            currentSection = "not impropers"
            for line in psf_file:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) <= 1:
                    currentSection = "not impropers"
                elif len(lineSplit) > 1:
                    if "!NIMPHI" in lineSplit[1]:
                        currentSection = "impropers"
                    elif currentSection == "impropers" and ("END" in line or "!" in line):
                        currentSection = "not impropers"
                    elif currentSection == "impropers":
                        if all(isfloat(item) for item in lineSplit):
                            for improper in zip(*[iter(lineSplit)] * 4):
                                self.impropers.append(map(int,improper))

        # Segment atom indices
        self.segmentToIndices = {segment: set() for segment in self.segments}
        for atomIndex in self.atomIndices:
            atomSegment = self.atomIndexToSegment[atomIndex]
            self.segmentToIndices[atomSegment].add(atomIndex)

        # Dummy atoms
        self.dummyAtoms = DummyAtoms(dummyAtomIndices, self)


        # Bonds
        self.bondedAtoms = {atomIndex: set() for atomIndex in self.atomIndices}
        for atomIndex in self.atomIndices:
            for bond in self.bonds:
                if atomIndex in bond:
                    for atomIndexBond in bond:
                        if atomIndexBond != atomIndex:
                            self.bondedAtoms[atomIndex].add(int(atomIndexBond))


class ForceField:
    
    def __init__(self, prmFilename):

        self.LJParas = FF_LJ_paras(prmFilename)
        self.bondParas = FF_bond_paras(prmFilename)
        self.angleParas= FF_angle_paras(prmFilename)
        self.dihedralParas= FF_dihedral_paras(prmFilename)
        self.improperParas= FF_improper_paras(prmFilename)

        
# Bonds
class FF_bond_paras:

    def __init__(self, prmFilename):

        # Bond paras
        self.Kb = dict()
        self.b0 = dict()

        currentSection = "not bonded"
        with open(prmFilename, "r") as systemPrmFile:

            # Reading in the LJ paras into a dictionary
            for line in systemPrmFile:
                lineSplit = line.split()

                # Checking the current section
                if len(lineSplit) == 1 and all(char.isupper() for char in lineSplit[0]):
                    if lineSplit[0] == "BONDS":
                        currentSection = "bonds"
                    else:
                        currentSection = "not bonds"

                if currentSection == "bonds" and len(lineSplit) >= 4 and lineSplit[0][0] != "!" and all(isfloat(item) for item in lineSplit[2:4]):

                    # Making the atom order unique to facilitate the later parameter retrieval
                    bondAtoms = [lineSplit[0], lineSplit[1]]
                    bondAtoms = sorted([bondAtoms, list(reversed(bondAtoms))])[0]

                    # Storing the parameter values
                    self.Kb[tuple(bondAtoms)] = float(lineSplit[2])
                    self.b0[tuple(bondAtoms)] = float(lineSplit[3])


# Angles
class FF_angle_paras:
    def __init__(self, prmFilename):

        # Angle paras
        self.Ktheta = dict()
        self.Theta0 = dict()
        self.Kub = dict()
        self.S0 = dict()

        currentSection = "not angle"
        with open(prmFilename, "r") as systemPrmFile:

            # Reading in the paras into a dictionary
            for line in systemPrmFile:
                lineSplit = line.split()

                # Checking the current section
                if len(lineSplit) == 1 and all(char.isupper() for char in lineSplit[0]):
                    if lineSplit[0] == "ANGLES":
                        currentSection = "angles"
                    else:
                        currentSection = "not angles"
                if currentSection == "angles" and len(lineSplit) >= 7 and lineSplit[0][0] != "!" and all(isfloat(item) for item in lineSplit[3:7]):

                    # Making the atom order unique to facilitate the later parameter retrieval
                    angleAtoms = [lineSplit[0], lineSplit[1], lineSplit[2]]
                    angleAtoms = sorted([angleAtoms, list(reversed(angleAtoms))])[0]

                    # Storing the parameter values
                    self.Ktheta[tuple(angleAtoms)] = float(lineSplit[3])
                    self.Theta0[tuple(angleAtoms)] = float(lineSplit[4])
                    self.Kub[tuple(angleAtoms)] = float(lineSplit[5])
                    self.S0[tuple(angleAtoms)] = float(lineSplit[6])

                elif currentSection == "angles" and len(lineSplit) >= 5 and lineSplit[0][0] != "!" and all(isfloat(item) for item in lineSplit[3:5]):

                    # Making the atom order unique to facilitate the later parameter retrieval
                    angleAtoms = [lineSplit[0], lineSplit[1], lineSplit[2]]
                    angleAtoms = sorted([angleAtoms, list(reversed(angleAtoms))])[0]

                    # Storing the parameter values
                    self.Ktheta[tuple(angleAtoms)] = float(lineSplit[3])
                    self.Theta0[tuple(angleAtoms)] = float(lineSplit[4])
                    self.Kub[tuple(angleAtoms)] = 0
                    self.S0[tuple(angleAtoms)] = 2


# Dihedrals
class FF_dihedral_paras:
    def __init__(self, prmFilename):
        
        # Dihedral paras
        self.Kchi = dict()
        self.n = dict()
        self.delta = dict()

        currentSection = "not dihedral"
        with open(prmFilename, "r") as systemPrmFile:

            # Reading in the paras into a dictionary
            for line in systemPrmFile:
                lineSplit = line.split()

                # Checking the current section
                if len(lineSplit) == 1 and all(char.isupper() for char in lineSplit[0]):
                    if lineSplit[0] == "DIHEDRALS":
                        currentSection = "dihedrals"
                    else:
                        currentSection = "not dihedrals"
                if currentSection == "dihedrals" and len(lineSplit) >= 7 and lineSplit[0][0] != "!" and all(isfloat(item) for item in lineSplit[4:7]):

                    # Making the order unique to facilitate the later parameter retrieval
                    dihedralAtoms = [lineSplit[0], lineSplit[1], lineSplit[2], lineSplit[3]]
                    dihedralAtoms = sorted([dihedralAtoms, list(reversed(dihedralAtoms))])[0]

                    # Storing the parameter values
                    self.Kchi[tuple(dihedralAtoms)] = float(lineSplit[4])
                    self.n[tuple(dihedralAtoms)] = float(lineSplit[5])
                    self.delta[tuple(dihedralAtoms)] = float(lineSplit[6])

# Impropers
class FF_improper_paras:
    def __init__(self, prmFilename):

        # Impropers paras
        self.Kpsi = dict()          # Called so in the Charmm para files. CP2K calls this K
        self.delta = dict()

        currentSection = "not improper"
        with open(prmFilename, "r") as systemPrmFile:

            # Reading in the paras into a dictionary
            for line in systemPrmFile:
                lineSplit = line.split()

                # Checking the current section
                if len(lineSplit) == 1 and all(char.isupper() for char in lineSplit[0]):
                    if lineSplit[0] == "IMPROPER":
                        currentSection = "impropers"
                    else:
                        currentSection = "not impropers"
                if currentSection == "impropers" and len(lineSplit) >= 7 and lineSplit[0][0] != "!" and all(isfloat(item) for item in lineSplit[4:7]):

                    # Making the order unique to facilitate the later parameter retrieval. The central improper atom in Charmm topology files is the first one, the other three determine the plane
                    improperAtoms = [lineSplit[0], lineSplit[1], lineSplit[2], lineSplit[3]]
                    improperAtoms = [improperAtoms[0]] + sorted([improperAtoms[1:4], list(reversed(improperAtoms[1:4]))])[0]

                    # Storing the parameter values
                    self.Kpsi[tuple(improperAtoms)] = float(lineSplit[4])
                    self.delta[tuple(improperAtoms)] = float(lineSplit[6])


        
class FF_LJ_paras:
    
    def __init__(self, prmFilename):
        
        # LJ paras
        self.epsilon = dict()
        self.rminHalf = dict()
        self.sigma = dict.fromkeys(self.rminHalf.keys())
        
        currentSection = "not nonbonded"
        with open(prmFilename, "r") as systemPrmFile:

            # Reading in the LJ paras into a dictionary
            for line in systemPrmFile:
                lineSplit = line.split()
                
                # Checking the current section
                if len(lineSplit) >= 1:
                    if lineSplit[0] == "NONBONDED":
                        currentSection = "nonbonded"
                    elif lineSplit[0] == "END":
                        currentSection = "not nonbonded"
                    elif currentSection == "nonbonded":
                        if "END" in line or "HBOND" in line:
                            currentSection = "not nonbonded"
                        elif len(lineSplit) >= 4 and lineSplit[0][0] != "!" and lineSplit[0] != "cutnb" and all(isfloat(item) for item in lineSplit[1:4]):
                            if lineSplit[2][0] == "-":
                                self.epsilon[lineSplit[0]] = -float(lineSplit[2])
                            else:
                                self.epsilon[lineSplit[0]] = float(lineSplit[2])
                            self.rminHalf[lineSplit[0]] = float(lineSplit[2])
                            self.sigma[lineSplit[0]] = (2.**(-1./6.))*float(lineSplit[3])
                            
                            
def prepare_cp2k_FF(molecularSystem, FFParas):

    # Preparing the bonds input for CP2K
    with open("cp2k.in.bonds." + molecularSystem.systemName, "w") as cp2kBondsFile:
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for bond in molecularSystem.dummyAtoms.bonds[dummyAtomIndex]:
                atomName1 = molecularSystem.atomIndexToName[bond[0]]
                atomName2 = molecularSystem.atomIndexToName[bond[1]]
                atomType1 = molecularSystem.atomNameToType[atomName1]
                atomType2 = molecularSystem.atomNameToType[atomName2]
                # Making the atom order unique to facilitate the parameter retrieval
                bondAtoms = [atomType1, atomType2]
                bondAtoms = sorted([bondAtoms, list(reversed(bondAtoms))])[0]
                Kb = FFParas.bondParas.Kb[tuple(bondAtoms)]
                b0 = FFParas.bondParas.b0[tuple(bondAtoms)]
                cp2kBondsFile.write("&BOND\n  ATOMS %s %s\n  K [kcalmol*angstrom^-2] %f\n  R0 [angstrom] %f\n&END BOND\n" % (atomName1, atomName2, Kb, b0))
            
    # Preparing the angles input file for CP2K
    with open("cp2k.in.angles." + molecularSystem.systemName, "w") as cp2kAnglesFile:
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for angle in molecularSystem.dummyAtoms.angles[dummyAtomIndex]:
                atomName1 = molecularSystem.atomIndexToName[angle[0]]
                atomName2 = molecularSystem.atomIndexToName[angle[1]]
                atomName3 = molecularSystem.atomIndexToName[angle[2]]
                atomType1 = molecularSystem.atomNameToType[atomName1]
                atomType2 = molecularSystem.atomNameToType[atomName2]
                atomType3 = molecularSystem.atomNameToType[atomName3]
                # Making the atom order unique to facilitate the parameter retrieval
                angleAtoms = [atomType1, atomType2, atomType3]
                angleAtoms = sorted([angleAtoms, list(reversed(angleAtoms))])[0]
                Ktheta = FFParas.angleParas.Ktheta[tuple(angleAtoms)]
                Theta0 = FFParas.angleParas.Theta0[tuple(angleAtoms)]
                Kub = FFParas.angleParas.Kub[tuple(angleAtoms)]
                S0 = FFParas.angleParas.S0[tuple(angleAtoms)]
                cp2kAnglesFile.write("&BEND\n  ATOMS %s %s %s\n  K [kcalmol*rad^-2] %f\n  THETA0 [deg] %f\n  &UB\n    KIND CHARMM\n    K [kcalmol*angstrom^-2] %f\n    R0 [angstrom] %f\n  &END UB\n&END BEND\n" % (atomName1, atomName2, atomName3, Ktheta, Theta0, Kub, S0))

    # Preparing the dihedrals input file for CP2K
    with open("cp2k.in.dihedrals." + molecularSystem.systemName, "w") as cp2kDihedralFile:
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for dihedral in molecularSystem.dummyAtoms.dihedrals[dummyAtomIndex]:
                atomName1 = molecularSystem.atomIndexToName[dihedral[0]]
                atomName2 = molecularSystem.atomIndexToName[dihedral[1]]
                atomName3 = molecularSystem.atomIndexToName[dihedral[2]]
                atomName4 = molecularSystem.atomIndexToName[dihedral[3]]
                atomType1 = molecularSystem.atomNameToType[atomName1]
                atomType2 = molecularSystem.atomNameToType[atomName2]
                atomType3 = molecularSystem.atomNameToType[atomName3]
                atomType4 = molecularSystem.atomNameToType[atomName4]
                # Making the atom order unique to facilitate the parameter retrieval
                dihedralAtoms = [atomType1, atomType2, atomType3, atomType4]
                dihedralAtoms = sorted([dihedralAtoms, list(reversed(dihedralAtoms))])[0]
                Kchi = FFParas.dihedralParas.Kchi[tuple(dihedralAtoms)]
                n = FFParas.dihedralParas.n[tuple(dihedralAtoms)]
                delta = FFParas.dihedralParas.delta[tuple(dihedralAtoms)]
                cp2kDihedralFile.write("&TORSION\n  ATOMS %s %s %s %s\n  K [kcalmol] %f\n  M %d\n  PHI0 [deg] %f\n&END TORSION\n" % (atomName1, atomName2, atomName3, atomName4, Kchi, n, delta))

    # Preparing the impropers input file for CP2K
    with open("cp2k.in.impropers." + molecularSystem.systemName, "w") as cp2kImproperFile:
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for improper in molecularSystem.dummyAtoms.impropers[dummyAtomIndex]:
                atomName1 = molecularSystem.atomIndexToName[improper[0]]
                atomName2 = molecularSystem.atomIndexToName[improper[1]]
                atomName3 = molecularSystem.atomIndexToName[improper[2]]
                atomName4 = molecularSystem.atomIndexToName[improper[3]]
                atomType1 = molecularSystem.atomNameToType[atomName1]
                atomType2 = molecularSystem.atomNameToType[atomName2]
                atomType3 = molecularSystem.atomNameToType[atomName3]
                atomType4 = molecularSystem.atomNameToType[atomName4]
                # Making the atom order unique to facilitate the parameter retrieval
                improperAtoms = [atomType1, atomType2, atomType3, atomType4]
                improperAtoms = [improperAtoms[0]] + sorted([improperAtoms[1:4], list(reversed(improperAtoms[1:4]))])[0]
                Kpsi = FFParas.improperParas.Kpsi[tuple(improperAtoms)]
                delta = FFParas.improperParas.delta[tuple(improperAtoms)]
                cp2kImproperFile.write("&IMPROPER\n  ATOMS %s %s %s %s\n  K [kcalmol*rad^-2] %f\n  PHI0 [deg] %f\n&END TORSION\n" % (atomName1, atomName2, atomName3, atomName4, Kpsi, delta))

    # Preparing LJ input file for CP2K
    with open("cp2k.in.lj." + molecularSystem.systemName, "w") as cp2k_LJ_file:
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for atomName in molecularSystem.dummyAtoms.nonangledAtomNames[dummyAtomIndex]:
                epsilon = math.sqrt(FFParas.LJParas.epsilon[molecularSystem.atomIndexToType[dummyAtomIndex]] * FFParas.LJParas.epsilon[molecularSystem.atomNameToType[atomName]])
                sigma = FFParas.LJParas.sigma[molecularSystem.atomIndexToType[dummyAtomIndex]]+FFParas.LJParas.sigma[molecularSystem.atomNameToType[atomName]]
                cp2k_LJ_file.write("&LENNARD-JONES\n  ATOMS %s %s\n  EPSILON [kcalmol] %f\n  SIGMA %f\n  RCUT %f\n&END LENNARD-JONES\n" % (molecularSystem.atomIndexToName[dummyAtomIndex], atomName, epsilon, sigma, sigma))


def append_dummies_to_prmfile(molecularSystem, prmOutputFile):

    # Opening the parameter file
    with open(prmOutputFile, "a") as prmFile:
        prmFile.write("\n\n")
        prmFile.write("* Parameters for the dummy atoms\n")
        prmFile.write("* Generated by HyperQ\n")
        prmFile.write("*\n")
        prmFile.write("\n")

        # Atoms
        prmFile.write("ATOMS\n")
        prmFile.write("%-10s %10.0f %10s %10.0f ! dummy atom\n" % ("MASS", 893, "DUM", 0))
        prmFile.write("\n")

        # Bonds
        prmFile.write("BONDS\n")
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for bond in molecularSystem.dummyAtoms.bonds[dummyAtomIndex]:
                dummyBondIndex = bond.index(dummyAtomIndex)
                atomType1 = molecularSystem.atomIndexToType[bond[0]]
                atomType2 = molecularSystem.atomIndexToType[bond[1]]
                if dummyBondIndex == 0:
                    atomType1 = "DUM"
                elif dummyBondIndex == 1:
                    atomType2 = "DUM"
                prmFile.write("%-10s %-10s %10.4f %10.1f \n" % (atomType1, atomType2, 0, 10))
        prmFile.write("\n")

        # Angles
        prmFile.write("ANGLES\n")
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for angle in molecularSystem.dummyAtoms.angles[dummyAtomIndex]:
                dummyAngleIndex = angle.index(dummyAtomIndex)
                atomType1 = molecularSystem.atomIndexToType[angle[0]]
                atomType2 = molecularSystem.atomIndexToType[angle[1]]
                atomType3 = molecularSystem.atomIndexToType[angle[2]]
                if dummyAngleIndex == 0:
                    atomType1 = "DUM"
                elif dummyAngleIndex == 1:
                    atomType2 = "DUM"
                elif dummyAngleIndex == 2:
                    atomType3 = "DUM"
                prmFile.write("%-10s %-10s %-10s %10.4f %10f \n" % (atomType1, atomType2, atomType3, 0, 180))
        prmFile.write("\n")

        # Dihedrals
        prmFile.write("DIHEDRALS\n")
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for dihedral in molecularSystem.dummyAtoms.dihedrals[dummyAtomIndex]:
                dummyDihedralIndex = dihedral.index(dummyAtomIndex)
                atomType1 = molecularSystem.atomIndexToType[dihedral[0]]
                atomType2 = molecularSystem.atomIndexToType[dihedral[1]]
                atomType3 = molecularSystem.atomIndexToType[dihedral[2]]
                atomType4 = molecularSystem.atomIndexToType[dihedral[3]]
                if dummyDihedralIndex == 0:
                    atomType1 = "DUM"
                elif dummyDihedralIndex == 1:
                    atomType2 = "DUM"
                elif dummyDihedralIndex == 2:
                    atomType3 = "DUM"
                elif dummyDihedralIndex == 3:
                    atomType4 = "DUM"
                prmFile.write("%-10s %-10s %-10s %-10s %10.4f %1.0f %1.2f\n" % (atomType1, atomType2, atomType3, atomType4, 0, 1, 0))
        prmFile.write("\n")

        # Impropers
        prmFile.write("IMPROPER\n")
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for improper in molecularSystem.dummyAtoms.impropers[dummyAtomIndex]:
                dummyImproperIndex = improper.index(dummyAtomIndex)
                atomType1 = molecularSystem.atomIndexToType[improper[0]]
                atomType2 = molecularSystem.atomIndexToType[improper[1]]
                atomType3 = molecularSystem.atomIndexToType[improper[2]]
                atomType4 = molecularSystem.atomIndexToType[improper[3]]
                if dummyImproperIndex == 0:
                    atomType1 = "DUM"
                elif dummyImproperIndex == 1:
                    atomType2 = "DUM"
                elif dummyImproperIndex == 2:
                    atomType3 = "DUM"
                elif dummyImproperIndex == 3:
                    atomType4 = "DUM"
                prmFile.write("%-10s %-10s %-10s %-10s %10.4f %1.0f %1.2f\n" % (atomType1, atomType2, atomType3, atomType4, 0, 0, 0))
        prmFile.write("\n")

        # Atoms
        prmFile.write("NONBONDED nbxmod  5 atom cdiel shift vatom vdistance vswitch -\n")
        prmFile.write("cutnb 0.0 ctofnb 0.0 ctonnb 0.0 eps 1.0 e14fac 1.0 wmin 1.5\n")
        prmFile.write("%-10s %10s %12s %12s %12s %12s %12s\n" % ( "!atom", "ignored", "epsilon", "Rmin/2", "ignored", "eps,1-4", "Rmin/2,1-4"))
        prmFile.write("%-10s %10s %12s %12s\n" % ( "DUM", "0.0", "-0.0000", "0.0000"))
        prmFile.write("\n")

        # Closing the new section of the parameter file
        prmFile.write("END\n")

def isfloat(value):
    try:
        float(value)
        return True
    except ValueError:
        return False