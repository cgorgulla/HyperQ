#!/usr/bin/env python
import sys
import math

class dummyAtoms:
    
    def __init__(self, indices, molecularSystem):
        
        self.dummyCount = len(indices)
        self.indices = indices
        self.molecularSystem = molecularSystem
        
        # Bonds 
        self.bondedAtoms = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        self.bonds = {index: [] for index in self.indices}
        for bond in molecularSystem.bonds:
            for dummyAtomIndex in self.indices:
                if dummyAtomIndex in bond:
                    self.bonds[dummyAtomIndex].append(bond)
                    for atomIndex in bond:
                        if atomIndex != dummyAtomIndex:
                            self.bondedAtoms[dummyAtomIndex].add(int(atomIndex))

        # Angles
        self.angledAtoms = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        self.angles = {index: [] for index in self.indices}
        for angle in molecularSystem.angles:
            for dummyAtomIndex in self.indices:
                if dummyAtomIndex in angle:
                    self.angles[dummyAtomIndex].append(angle)
                    for atomIndex in angle:
                        if atomIndex != dummyAtomIndex:
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
                            
        # self.nonangledAtomIndeces
        self.nonangledAtomIndeces = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        for dummyAtomIndex in self.indices:
            self.angledAtoms[dummyAtomIndex].add(dummyAtomIndex)
            self.nonangledAtomIndeces[dummyAtomIndex] = molecularSystem.atomIndeces - self.angledAtoms[dummyAtomIndex]
        
        # self.nonangledNames
        self.nonangledAtomNames = {dummyAtomIndex: set() for dummyAtomIndex in self.indices}
        for dummyAtomIndex in self.indices:
            for atomIndex in self.nonangledAtomIndeces[dummyAtomIndex]:
                self.nonangledAtomNames[dummyAtomIndex].add(molecularSystem.atomIndexToName[atomIndex])
        

class molecularSystem:
    
    def __init__(self, systemName, dummyAtomIndeces):

        self.systemName = systemName
        self.atomIndeces = set()
        self.atomIndexToName = {}
        self.atomIndexToType = {}
        self.bonds = []
        self.angles = []
        self.dihedrals = []
        self.atomNames = set()
        self.atomNameToType = {}
        
        # All atom indices, names, types
        with open(systemName + ".vmd.psf", "r") as psf_file:
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
                        self.atomIndeces.add(int(lineSplit[0]))
                        self.atomIndexToName[int(lineSplit[0])] = lineSplit[4]
                        self.atomIndexToType[int(lineSplit[0])] = lineSplit[5]
        
        # Atom names to types dictionary
        for atomIndex in self.atomIndeces:
            atomName = self.atomIndexToName[atomIndex]
            atomType = self.atomIndexToType[atomIndex]
            self.atomNames.add(atomName)
            self.atomNameToType[atomName] = atomType
        
        # All bonds
        with open(systemName + ".vmd.psf", "r") as psf_file:
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
        with open(systemName + ".vmd.psf", "r") as psf_file:
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
        with open(systemName + ".vmd.psf", "r") as psf_file:
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
        # Dummy atoms
        self.dummyAtoms = dummyAtoms(dummyAtomIndeces, self)

class ForceField:
    
    def __init__(self, systemName):

        self.LJParas = FF_LJ_paras(systemName)
        self.bondParas = FF_bond_paras(systemName)
        self.angleParas= FF_angle_paras(systemName)
        self.dihedralParas= FF_dihedral_paras(systemName)
        
        
        
class FF_LJ_paras:
    
    def __init__(self, systemName):
        self.systemName = systemName
        
        # LJ paras
        self.epsilon = dict()
        self.rmin_half = dict()
        self.sigma = dict.fromkeys(self.rmin_half.keys())
        
        currentSection = "not nonbonded"
        with open(systemName + ".prm") as systemPrmFile:

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
                            self.rmin_half[lineSplit[0]] = float(lineSplit[2])
                            self.sigma[lineSplit[0]] = (2.**(-1./6.))*float(lineSplit[3])
        
# Bonds
class FF_bond_paras:

    def __init__(self, systemName):
        self.systemName = systemName

        # Bond paras
        self.Kb = dict()
        self.b0 = dict()

        currentSection = "not bonded"
        with open(systemName + ".prm") as systemPrmFile:

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
                    self.Kb[tuple(sorted((lineSplit[0], lineSplit[1])))] = float(lineSplit[2])
                    self.b0[tuple(sorted((lineSplit[0], lineSplit[1])))] = float(lineSplit[3])

# Angles
class FF_angle_paras:
    def __init__(self, systemName):
        self.systemName = systemName

        # Angle paras
        self.Ktheta = dict()
        self.Theta0 = dict()

        currentSection = "not angle"
        with open(systemName + ".prm") as systemPrmFile:

            # Reading in the paras into a dictionary
            for line in systemPrmFile:
                lineSplit = line.split()

                # Checking the current section
                if len(lineSplit) == 1 and all(char.isupper() for char in lineSplit[0]):
                    if lineSplit[0] == "ANGLES":
                        currentSection = "angles"
                    else:
                        currentSection = "not angles"
                if currentSection == "angles" and len(lineSplit) >= 5 and lineSplit[0][
                    0] != "!" and all(isfloat(item) for item in lineSplit[3:5]):
                    self.Ktheta[tuple(sorted((lineSplit[0], lineSplit[1], lineSplit[2])))] = float(
                        lineSplit[3])
                    self.Theta0[tuple(sorted((lineSplit[0], lineSplit[1], lineSplit[2])))] = float(
                        lineSplit[4])
                    
                    
# Dihedrals
class FF_dihedral_paras:
    def __init__(self, systemName):
        self.systemName = systemName
        
        # Dihedral paras
        self.Kchi = dict()
        self.n = dict()
        self.delta = dict()

        currentSection = "not dihedral"
        with open(systemName + ".prm") as systemPrmFile:

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
                    self.Kchi[tuple(sorted((lineSplit[0], lineSplit[1], lineSplit[2], lineSplit[3])))] = float(lineSplit[4])
                    self.n[tuple(sorted((lineSplit[0], lineSplit[1], lineSplit[2], lineSplit[3])))] = float(lineSplit[5])
                    self.delta[tuple(sorted((lineSplit[0], lineSplit[1], lineSplit[2],  lineSplit[3])))] = float(lineSplit[6])
                    

def prepare_cp2k_FF(molecularSystem, FFParas):

#    # Preparing LJ input file for CP2K
#    with open("cp2k.in.LJ." + molecularSystem.systemName, "w") as cp2k_LJ_file:
#        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
#            for atomName in molecularSystem.dummyAtoms.nonangledAtomNames[dummyAtomIndex]:
#                epsilon = math.sqrt(FFParas.LJParas.epsilon[molecularSystem.atomIndexToType[dummyAtomIndex]] * FFParas.LJParas.epsilon[molecularSystem.atomNameToType[atomName]])
#                sigma = FFParas.LJParas.sigma[molecularSystem.atomIndexToType[dummyAtomIndex]]+FFParas.LJParas.sigma[molecularSystem.atomNameToType[atomName]]
#                cp2k_LJ_file.write("""&LENNARD-JONES\n  ATOMS %s %s\n  EPSILON [kcalmol] %f\n  SIGMA %f\n  RCUT %f\n&END LENNARD-JONES\n"""
#                                  % (molecularSystem.atomIndexToName[dummyAtomIndex], atomName, epsilon, sigma, sigma))
                
    # Preparing bonds input for CP2K
    with open("cp2k.in.bonds." + molecularSystem.systemName, "w") as cp2kBondsFile:
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for bond in molecularSystem.dummyAtoms.bonds[dummyAtomIndex]:
                atomName1 = molecularSystem.atomIndexToName[bond[0]]
                atomName2 = molecularSystem.atomIndexToName[bond[1]]
                atomType1 = molecularSystem.atomNameToType[atomName1]
                atomType2 = molecularSystem.atomNameToType[atomName2]
                Kb = FFParas.bondParas.Kb[tuple(sorted((atomType1, atomType2)))]
                b0 = FFParas.bondParas.b0[tuple(sorted((atomType1, atomType2)))]
                cp2kBondsFile.write("&BOND\n  ATOMS %s %s\n  K [angstrom^-2kcalmol] %f\n  R0 [angstrom] %f\n&END BOND\n" % (atomName1, atomName2, Kb, b0))
            
    # Preparing angles input file for CP2K
    with open("cp2k.in.angles." + molecularSystem.systemName, "w") as cp2kAnglesFile:
        for dummyAtomIndex in molecularSystem.dummyAtoms.indices:
            for angle in molecularSystem.dummyAtoms.angles[dummyAtomIndex]:
                atomName1 = molecularSystem.atomIndexToName[angle[0]]
                atomName2 = molecularSystem.atomIndexToName[angle[1]]
                atomName3 = molecularSystem.atomIndexToName[angle[2]]
                atomType1 = molecularSystem.atomNameToType[atomName1]
                atomType2 = molecularSystem.atomNameToType[atomName2]
                atomType3 = molecularSystem.atomNameToType[atomName3]
                Ktheta = FFParas.angleParas.Ktheta[tuple(sorted((atomType1, atomType2, atomType3)))]
                Theta0 = FFParas.angleParas.Theta0[tuple(sorted((atomType1, atomType2, atomType3)))]
                cp2kAnglesFile.write("&BEND\n  ATOMS %s %s %s\n  K [rad^-2kcalmol] %f\n  THETA0 [deg] %f\n&END BEND\n" % (atomName1, atomName2, atomName3, Ktheta, Theta0))

    # Preparing dihedrals input file for CP2K
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
                Kchi = FFParas.dihedralParas.Kchi[tuple(sorted((atomType1, atomType2, atomType3, atomType4)))]
                n = FFParas.dihedralParas.n[tuple(sorted((atomType1, atomType2, atomType3, atomType4)))]
                delta = FFParas.dihedralParas.delta[tuple(sorted((atomType1, atomType2, atomType3, atomType4)))]
                cp2kDihedralFile.write(
                    "&TORSION\n  ATOMS %s %s %s %s\n  K [kcalmol] %f\n  M %d\n  PHI0 [deg] %f\n&END TORSION\n" % (
                        atomName1, atomName2, atomName3, atomName4, Kchi, n, delta))

def isfloat(value):
    try:
        float(value)
        return True
    except ValueError:
        return False