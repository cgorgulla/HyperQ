#!/usr/bin/env python
from bidict import bidict
from hyperq.tools import *
import math
from cp2k_dummies import FF_LJ_paras
import itertools

class SingleSystem:
    
    def __init__(self, systemPDBfilename, mcsMappingFilename, systemID):
    
        # Fields
        self.atomCount = {"protein":0, "ligand":0, "solvent":0, "joint":0, "dummy":0, "total":0}
        self.indices= {"protein":set(), "ligand":set(), "solvent":set(), "joint":set(), "dummy":set()}
        self.PDBfilename = systemPDBfilename
        self.pdblines = {"ligand":{}}
        self.atomIndexToName = {}
        
        with open(systemPDBfilename, "r") as pdbFile:
            for line in pdbFile:
                lineSplit = line.split()
                if len(lineSplit) > 0 and lineSplit[0] == "ATOM":
                    chain = line[21:22]
                    if chain == "P":
                        self.atomCount["protein"] += 1
                        self.indices["protein"].add(int(lineSplit[1]))
                    elif chain == "L":
                        self.atomCount["ligand"] += 1
                        self.indices["ligand"].add(int(lineSplit[1]))
                        self.pdblines["ligand"][int(lineSplit[1])] = line
                    else:
                        self.atomCount["solvent"] += 1
                        self.indices["solvent"].add(int(lineSplit[1]))
                    
        self.atomCount["total"] = self.atomCount["protein"] + self.atomCount["ligand"] + self.atomCount["solvent"]
        
        # Joint atoms
        with open(mcsMappingFilename, "r") as mcsMappingFilename:
            for line in mcsMappingFilename:
                lineSplit = line.strip().split()
                if len(lineSplit) == 2 and all(char.isdigit() for char in lineSplit[0] + lineSplit[1]):
                    atomIndex = int(lineSplit[systemID - 1])  + self.atomCount["protein"]
                    self.indices["joint"].add(atomIndex)
                    self.atomCount["joint"] += 1
        
        # Dummy Atoms
        self.indices["dummy"] = self.indices["ligand"] - self.indices["joint"]
        self.atomCount["dummy"] = len(self.indices["dummy"])
        # Write out dummy indices (for cp2k_dummies.py)
        with open("system" + str(systemID) + ".dummy.indices", "w") as dummyFile:
            for atomIndex in self.indices["dummy"]: 
                dummyFile.write(str(atomIndex) + " ")

        # All atom indices, names, types
        with open(systemPDBfilename, "r") as pdbFile:
            currentSection = "not atoms"
            for line in pdbFile:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) > 1 and lineSplit[0] in ["ATOM", "HETATM"]:
                    self.atomIndexToName[int(line[6:11].strip())] = line[12:16]

# For
class MolecularSystem2:
    def __init__(self, systemName):

        self.systemName = systemName
        self.atomIndeces = set()
        self.atomIndexToName = {}
        self.atomIndexToPSFType = {} # But it will contain also as keys the atom indeces
        self.atomIndexToMQType = {}             # Q or M
        self.bonds = []
        self.atomNames = set()
        self.atomNameToType = {}

        # All atom indices, names, types
        with open(systemName + ".psf", "r") as psf_file:
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
                        self.atomIndexToPSFType[int(lineSplit[0])] = lineSplit[5]

        with open(systemName + ".pdbx", "r") as pdbx_file:
            index = 0
            for line in pdbx_file:
                lineSplit = line.split()
                # Checking the current section
                if len(lineSplit) >= 1 and lineSplit[0] in ["ATOM", "HETATM"]:
                    index += 1
                    atomType = line[80:81]
                    if atomType in ["Q", "M"]:
                        self.atomIndexToMQType[index] = atomType
                    else:
                        raise Exception("Wrong or missing element type in pdbx file. Exiting")

                        # All bonds
        with open(systemName + ".psf", "r") as psf_file:
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
                                self.bonds.append(map(int, bond))

        # Preparing the set of all psf atom types
        self.atomTypes = set(self.atomIndexToPSFType.values())


    def prepare_cp2k_qmmm(molecularSystem2, parameterFileBasename):

        # Preparing the link atom input file for CP2K
        with open("cp2k.in.qmmm.link." + molecularSystem2.systemName, "w") as cp2kLinkFile:
            for bond in molecularSystem2.bonds:
                if molecularSystem2.atomIndexToMQType[bond[0]] == "Q" and molecularSystem2.atomIndexToMQType[bond[1]] == "M":
                    atomIndexQM = bond[0]
                    atomIndexMM = bond[1]
                    cp2kLinkFile.write(
                        "&LINK\n  ALPHA 1.50\n  LINK_TYPE IMOMM\n  MM_INDEX %s\n  QM_INDEX %s\n&END LINK\n" % (
                        atomIndexMM, atomIndexQM))
                elif molecularSystem2.atomIndexToMQType[bond[0]] == "M" and molecularSystem2.atomIndexToMQType[bond[1]] == "Q":
                    atomIndexMM = bond[0]
                    atomIndexQM = bond[1]
                    cp2kLinkFile.write(
                        "&LINK\n  ALPHA 1.50\n  LINK_TYPE IMOMM\n  MM_INDEX %s\n  QM_INDEX %s\n&END LINK\n" % (
                        atomIndexMM, atomIndexQM))

        # Preparing LJ input for CP2K
        LJParameters = FF_LJ_paras(parameterFileBasename)
        # The file parameterFileBasename.prm needs to be present
        with open("cp2k.in.qmmm.lj." + molecularSystem2.systemName, "w") as cp2kLJFile:
            for atom_pair in itertools.combinations_with_replacement(molecularSystem2.atomTypes, 2):
                epsilon = math.sqrt(LJParameters.epsilon[atom_pair[0]] * LJParameters.epsilon[atom_pair[1]])
                sigma = ( LJParameters.sigma[atom_pair[0]] + LJParameters.sigma[atom_pair[1]] ) * 1
                cp2kLJFile.write("""&LENNARD-JONES\n  ATOMS %s %s\n  EPSILON [kcalmol] %f\n  SIGMA [angstrom] %f\n  RCUT [angstrom] %f\n&END LENNARD-JONES\n"""
                              % (atom_pair[0], atom_pair[1], epsilon, sigma, 12))


class JointSystem:
    
    def __init__(self, system1, system2, mcsMappingFilename):
        
        self.mappingJointSystemToSystem1 = bidict()
        self.mappingJointSystemToSystem2 = bidict()
        self.mappingMCSLigandSystem1To2 = bidict()
        self.system1 = system1
        self.system2 = system2
        self.mcsMappingFilename = mcsMappingFilename
        
        # Preparing the mapping between the MCS of the two single systems
        with open(mcsMappingFilename, "r") as mcsMappingFilename:
            for line in mcsMappingFilename:
                lineSplit = line.split()
                if len(lineSplit) == 2 and all(char.isdigit() for char in lineSplit[0] + lineSplit[1]):
                    self.mappingMCSLigandSystem1To2[int(lineSplit[0]) + system1.atomCount["protein"]] = int(lineSplit[1]) + system1.atomCount["protein"]
        
        # Mapping the atoms between the joint and the single systems
        # Joint system to system 1
        for index in self.system1.indices["protein"]:
            self.mappingJointSystemToSystem1[index] = index
        for index in self.system1.indices["ligand"]:
            self.mappingJointSystemToSystem1[index] = index
        for index in self.system1.indices["solvent"]:
            self.mappingJointSystemToSystem1[index + system2.atomCount["dummy"]] = index 
        # Joint system to system 2
        for index in system2.indices["protein"]:
            self.mappingJointSystemToSystem2[index] = index
        for index in self.mappingMCSLigandSystem1To2:
            self.mappingJointSystemToSystem2[index] = self.mappingMCSLigandSystem1To2[index]
        counter = 0
        for index in system2.indices["dummy"]:
            counter += 1
            self.mappingJointSystemToSystem2[self.system1.atomCount["protein"]+self.system1.atomCount["ligand"] - self.system1.atomCount["dummy"] + counter] = index 
        counter = 0
        for index in system2.indices["solvent"]:
            counter += 1
            self.mappingJointSystemToSystem2[self.system1.atomCount["protein"] + self.system1.atomCount["ligand"]+system2.atomCount["dummy"] + counter] = index


    def writeCP2Kfile(self):

        with open("cp2k.in.mapping", "w") as cp2kFile:

            # Beginning of the mapping section 
            cp2kFile.write("&MAPPING\n")

            # Beginng of the mixed force eval
            cp2kFile.write("  &FORCE_EVAL_MIXED\n")
            fragmentCounter = 1
            # Fragment for the protein
            if self.system1.atomCount["protein"] != 0:
                cp2kFile.write("    &FRAGMENT 1\n")
                cp2kFile.write("      1 " + str(self.system1.atomCount["protein"]) + "\n")
                cp2kFile.write("    &END FRAGMENT\n")
                fragmentCounter += 1
                # For each atom of the ligands (joint + dummies) a fragment
            if (self.system1.atomCount["ligand"] + self.system2.atomCount["dummy"]) != 0:
                for i in range(1, self.system1.atomCount["ligand"] + self.system2.atomCount["dummy"] + 1):
                    cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                    atomIndex = self.system1.atomCount["protein"] + i
                    cp2kFile.write("      " + str(atomIndex) + " " + str(atomIndex) + "\n")
                    cp2kFile.write("    &END FRAGMENT\n")
                    fragmentCounter += 1
            # Fragment for the solvent
            if self.system1.atomCount["solvent"] != 0:
                cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                atomIndex1 = str(
                    self.system1.atomCount["protein"] + self.system1.atomCount["ligand"] + self.system2.atomCount[
                        "dummy"] + 1)  # +1 because of starting index
                atomIndex2 = str(self.system1.atomCount["total"] + self.system2.atomCount["dummy"])
                cp2kFile.write("      " + atomIndex1 + " " + atomIndex2 + "\n")
                cp2kFile.write("    &END FRAGMENT\n")
                fragmentCounter += 1
            # End of this force eval
            cp2kFile.write("  &END FORCE_EVAL_MIXED\n")

            # First Force Eval (first system)
            cp2kFile.write("  &FORCE_EVAL 1\n")
            fragmentCounter = 1
            # Fragment for the protein
            if self.system1.atomCount["protein"] != 0:
                cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                cp2kFile.write("      1 " + str(self.system1.atomCount["protein"]) + "\n")
                cp2kFile.write("      MAP 1\n")
                cp2kFile.write("    &END FRAGMENT\n")
                fragmentCounter += 1
            # For each atom of the ligands a fragment
            if self.system1.atomCount["ligand"] != 0:
                for i in range(1, self.system1.atomCount["ligand"] + 1):
                    cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                    atomIndex = self.system1.atomCount["protein"] + i
                    cp2kFile.write("      " + str(atomIndex) + " " + str(atomIndex) + "\n")
                    cp2kFile.write("      MAP " + str(fragmentCounter) + "\n")
                    cp2kFile.write("    &END FRAGMENT\n")
                    fragmentCounter += 1
            # Fragment for the solvent
            if self.system1.atomCount["solvent"] != 0:
                cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                cp2kFile.write(
                    "      " + str(self.system1.atomCount["protein"] + self.system1.atomCount["ligand"] + 1) + " " + str(
                        self.system1.atomCount["total"]) + "\n")
                cp2kFile.write("      MAP " + str(fragmentCounter + self.system2.atomCount["dummy"]) + "\n")
                cp2kFile.write("    &END FRAGMENT\n")
                fragmentCounter += 1
            # End of this force eval
            cp2kFile.write("  &END FORCE_EVAL\n")

            # Second Force Eval (second system)
            cp2kFile.write("  &FORCE_EVAL 2\n")
            fragmentCounter = 1
            # Fragment for the protein
            if self.system2.atomCount["protein"] != 0:
                cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                cp2kFile.write("      1 " + str(self.system2.atomCount["protein"]) + "\n")
                cp2kFile.write("      MAP " + str(fragmentCounter) + "\n")
                cp2kFile.write("    &END FRAGMENT\n")
                fragmentCounter += 1
                # For each joint atom of the ligands a fragment
            if self.system2.atomCount["joint"] != 0:
                for atomIndex2 in sorted(self.system2.indices["joint"]):
                    cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                    atomIndex1 = self.mappingMCSLigandSystem1To2.inv[atomIndex2]
                    cp2kFile.write("      " + str(atomIndex2) + " " + str(atomIndex2) + "\n")
                    if self.system1.atomCount["protein"] != 0:
                        indexCorrection = 1  # if protein fragment is present we need to add 1 to the fragment id
                    else:
                        indexCorrection = 0  # otherweise not
                    cp2kFile.write(
                        "      MAP " + str(atomIndex1 - self.system1.atomCount["protein"] + indexCorrection) + "\n")
                    cp2kFile.write("    &END FRAGMENT\n")
                    fragmentCounter += 1
            # For each dummy atom of the ligands a fragment
            if self.system2.atomCount["dummy"] != 0:
                for atomIndex in sorted(self.system2.indices["dummy"]):
                    cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                    cp2kFile.write("      " + str(atomIndex) + " " + str(atomIndex) + "\n")
                    cp2kFile.write("      MAP " + str(fragmentCounter + self.system1.atomCount["dummy"]) + "\n")
                    cp2kFile.write("    &END FRAGMENT\n")
                    fragmentCounter += 1
            # Fragment for the solvent
            if self.system2.atomCount["solvent"] != 0:
                cp2kFile.write("    &FRAGMENT " + str(fragmentCounter) + "\n")
                cp2kFile.write(
                    "      " + str(self.system2.atomCount["protein"] + self.system2.atomCount["ligand"] + 1) + " " + str(
                        self.system2.atomCount["total"]) + "\n")
                cp2kFile.write("      MAP " + str(fragmentCounter + self.system1.atomCount["dummy"]) + "\n")
                #                cp2kFile.write("      MAP " + str(1 + system1.atomCount["ligand"] + system2.atomCount["dummy"] + 1) + "\n")
                cp2kFile.write("    &END FRAGMENT\n")
                fragmentCounter += 1
            # End of this force eval
            cp2kFile.write("  &END FORCE_EVAL\n")

            # End of this section
            cp2kFile.write("&END MAPPING\n")


    def writeSystemPDB(self):

        # k_0 state
        with open("system.a1c1.pdb", "w") as systemPDBfile:  # a for atom types, c for coordinates
            # Adding the protein and the first ligand of the first system
            with open(self.system1.PDBfilename, "r") as system1PDBfile:
                for line in system1PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] in ["ATOM", "HETATM"]:
                            if lineSplit[4] in ["P", "L"]:
                                if lineSplit[4] == "L":
                                    line = list(line)
                                    atomIndex = int(lineSplit[1])
                                    if atomIndex in self.system1.indices["joint"]:
                                        line[17:20] = "LC "
                                    else:
                                        line[17:20] = "L1 "
                                    line = "".join(line)
                                systemPDBfile.write(line)
                        if lineSplit[0] in ["CRYST1", "REMARK", "TITLE"]:
                            systemPDBfile.write(line)

            # Adding the dummies of the second system 
            with open(self.system2.PDBfilename, "r") as system2PDBfile:
                for line in system2PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            atomIndex = lineSplit[1]
                            if int(atomIndex) in self.system2.indices["dummy"]:
                                line = list(line)
                                line[17:20] = "L2 "
                                line = "".join(line)
                                systemPDBfile.write(line)

            # Adding the solvent of the first system 
            with open(self.system1.PDBfilename, "r") as system1PDBfile:
                for line in system1PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            if lineSplit[4] != "P" and lineSplit[4] != "L":
                                systemPDBfile.write(line)

        # k_1 state, coordinates from first ligand (MCS)
        with open("system.a2c1.pdb", "w") as systemPDBfile:
            # Adding the protein and the first ligand of the first system
            with open(self.system1.PDBfilename, "r") as system1PDBfile:
                for line in system1PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] in ["ATOM", "HETATM"]:
                            if lineSplit[4] in ["P", "L"]:
                                if lineSplit[4] == "L":
                                    line = list(line)
                                    atomIndex = int(lineSplit[1])
                                    if atomIndex in self.system1.indices["joint"]:
                                        # We change the line except for the coordinates
                                        #  line = self.system2.pdblines["ligand"][self.mappingMCSLigandSystem1To2[int(atomIndex)]] # to exchange also coordinates 
                                        line[0:30] = self.system2.pdblines["ligand"][
                                                         self.mappingMCSLigandSystem1To2[int(atomIndex)]][0:30]
                                        line[54:] = self.system2.pdblines["ligand"][
                                                        self.mappingMCSLigandSystem1To2[int(atomIndex)]][54:]
                                        line[17:20] = "LC "
                                    else:
                                        line[17:20] = "L1 "
                                    line = "".join(line)
                                systemPDBfile.write(line)
                        if lineSplit[0] in ["CRYST1", "REMARK", "TITLE"]:
                            systemPDBfile.write(line)

            # Adding the dummies of the second system 
            with open(self.system2.PDBfilename, "r") as system2PDBfile:
                for line in system2PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            atomIndex = lineSplit[1]
                            if int(atomIndex) in self.system2.indices["dummy"]:
                                line = list(line)
                                line[17:20] = "L2 "
                                line = "".join(line)
                                systemPDBfile.write(line)

            # Adding the solvent of the first system 
            with open(self.system1.PDBfilename, "r") as system1PDBfile:
                for line in system1PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            if lineSplit[4] != "P" and lineSplit[4] != "L":
                                systemPDBfile.write(line)

        # k_1 state, coordinates from second ligand (MCS)
        with open("system.a2c2.pdb", "w") as systemPDBfile:
            # Adding the protein and the first ligand of the first system
            with open(self.system1.PDBfilename, "r") as system1PDBfile:
                for line in system1PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] in ["ATOM", "HETATM"]:
                            if lineSplit[4] in ["P", "L"]:
                                if lineSplit[4] == "L":
                                    line = list(line)
                                    atomIndex = int(lineSplit[1])
                                    if atomIndex in self.system1.indices["joint"]:
                                        # We change the line except for the coordinates
                                        line = self.system2.pdblines["ligand"][self.mappingMCSLigandSystem1To2[
                                            int(atomIndex)]]  # to exchange also coordinates
                                        line = list(line)
                                        line[17:20] = "LC "
                                    else:
                                        line[17:20] = "L1 "
                                    line = "".join(line)
                                systemPDBfile.write(line)
                        if lineSplit[0] in ["CRYST1", "REMARK", "TITLE"]:
                            systemPDBfile.write(line)

            # Adding the dummies of the second system 
            with open(self.system2.PDBfilename, "r") as system2PDBfile:
                for line in system2PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            atomIndex = lineSplit[1]
                            if int(atomIndex) in self.system2.indices["dummy"]:
                                line = list(line)
                                line[17:20] = "L2 "
                                line = "".join(line)
                                systemPDBfile.write(line)

            # Adding the solvent of the first system 
            with open(self.system1.PDBfilename, "r") as system1PDBfile:
                for line in system1PDBfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            if lineSplit[4] != "P" and lineSplit[4] != "L":
                                systemPDBfile.write(line)


    def writeSystemPDBX(self):
        with open("system.a1c1.pdbx", "w") as systemPDBXfile:
            with open(self.system1.PDBfilename + "x", "r") as system1PDBXfile:
                for line in system1PDBXfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            if lineSplit[4] == "P" or lineSplit[4] == "L":
                                if lineSplit[4] == "L":
                                    line = list(line)
                                    atomIndex = int(lineSplit[1])
                                    if atomIndex in self.system1.indices["joint"]:
                                        line[17:20] = "LC "
                                    else:
                                        line[17:20] = "L1 "
                                    line = "".join(line)
                                systemPDBXfile.write(line)

            with open(self.system2.PDBfilename + "x", "r") as system2PDBXfile:
                for line in system2PDBXfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            atomIndex = lineSplit[1]
                            if int(atomIndex) in self.system2.indices["dummy"]:
                                line = list(line)
                                line[17:20] = "L2 "
                                line = "".join(line)
                                systemPDBXfile.write(line)

            # Adding the solvent of the first system 
            with open(self.system1.PDBfilename + "x", "r") as system1PDBXfile:
                for line in system1PDBXfile:
                    lineSplit = line.split()
                    if len(lineSplit) >= 1:
                        if lineSplit[0] == "ATOM":
                            if lineSplit[4] != "P" and lineSplit[4] != "L":
                                systemPDBXfile.write(line)


    def writeHRMappingFile(self):
        # hr = human readable
        with open(self.mcsMappingFilename + ".hr", "w") as mappingFile:
            # Writing the heading 
            mappingFile.write("Column 1: System 1 reduced indices\n")
            mappingFile.write("Column 2: System 1 total indices\n")
            mappingFile.write("Column 3: System 1 atom names\n")
            mappingFile.write("Column 4: System 2 reduced indices\n")
            mappingFile.write("Column 5: System 2 total indices\n")
            mappingFile.write("Column 6: System 2 atom names\n\n")
    
            # Writing the mapping
            for system1Index in self.mappingMCSLigandSystem1To2:
                system1Index = system1Index
                system2Index = self.mappingMCSLigandSystem1To2[system1Index]
                system1IndexReduced = system1Index - self.system1.atomCount["protein"]
                system2IndexReduced = self.mappingMCSLigandSystem1To2[system1Index] - self.system2.atomCount["protein"]
                mappingFile.write(str(system1IndexReduced).rjust(5) + " " + str(system1Index).rjust(5) + " " + self.system1.atomIndexToName[system1Index].strip().ljust(5) + " " + str(
                    system2IndexReduced).rjust(5) + " " + str(system2Index).rjust(5) + " " + self.system2.atomIndexToName[system2Index].strip().ljust(5) + "\n")
