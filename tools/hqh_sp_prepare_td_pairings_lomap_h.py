#!/usr/bin/env python

import lomap
import sys
import networkx as nx


def main(ligandFolder, outputFileBasename="lomap", ncpus=1, time=20, draw_pairwise_mcs="false"):
    # Create the molecule database by using .mol2 files
    # The DBMolecule class must be created with a valid
    # directory name
    
    #db_mol = lomap.DBMolecules('test/basic/', output=True)
    print "* Creating the molecule database."
    db_mol = lomap.DBMolecules(ligandFolder, name=outputFileBasename, parallel=ncpus, output=True, display=False, saveFigure=True, time=time)
    
    # Generate the strict and loose symmetric similarity 
    # score matrices          
    print "* Generating the strict and loose symmetric similarity matrices"
    strict, loose = db_mol.build_matrices()
    
    # Convert the matrices in standard numpy matrices
    print "* Converting the matrices into standard numpy matrices"
    strict_numpy = strict.to_numpy_2D_array()
    loose_numpy = loose.to_numpy_2D_array()
    
    # Networkx graph generation based on the similarity 
    # score matrices
    print "* Building the graph"
    db_mol.build_graph() 
    #print(nx_graph.edges(data=True))
    
    # Calculate the Maximum Common Subgraph (MCS) between 
    # the first two molecules in the molecule database
    #MC = {}
    #for i in range(0, len(db_mol.dic_mapping)):
    #    for j in range(0, len(db_mol.dic_mapping)):
    #        print "* Drawing MCS of molecules " + str(i) + " and " + str(j)
    #        MC[i,j] = lomap.MCS(db_mol[i].getMolecule(), db_mol[j].getMolecule())
    #        # Output the MCS in a .png file
    #        print "* Generating the png file " + "mcs." + str(i) + "_" + str(j) + ".png"
    #        MC[i,j].draw_mcs(i, j, fname="mcs." + str(i) + "_" + str(j) + ".png")
    
    
    # Getting the MCS of the graph
    MC_noh = {}
    edges = db_mol.Graph.edges()
    for edge in edges:
        atomIndex1 = edge[0]
        atomIndex2 = edge[1]
        MC_noh[atomIndex1, atomIndex2] = lomap.MCS(db_mol[atomIndex1].getMolecule(), db_mol[atomIndex2].getMolecule(), timeout=time)
        
    if draw_pairwise_mcs.lower() == "true":
        for edge in edges:
            print " * Drawing MCS of molecules " + str(atomIndex1) + " and " + str(atomIndex2)
            atomIndex1 = edge[0]
            atomIndex2 = edge[1]
            # Output the MCS in a .png file
            print " * Generating the png file " + "mcs." + str(atomIndex1) + "_" + str(atomIndex2) + ".png"
            try:
                MC_noh[atomIndex1,atomIndex2].draw_mcs(atomIndex1, atomIndex2, fname='mcs_noh' + str(atomIndex1) + "_" + str(atomIndex2) + '.png')
            except:
                print "Failed to generate image for this pair of molecules."
    
    MC_h ={}
    for edge in edges:
        print " * Creating mapping file between molecules " + str(atomIndex1) + " and " + str(atomIndex2)
        atomIndex1 = edge[0]
        atomIndex2 = edge[1]
        try:
            MC_h[atomIndex1, atomIndex2] = lomap.MCS.getMapping(db_mol[0].getMolecule(), db_mol[1].getMolecule(), hydrogens=True, fname='mcs_h' + str(atomIndex1) + "_" + str(atomIndex2) + '.png')
        except:
            print "* Trying again without hydrogens."
            MC_h[atomIndex1, atomIndex2] = lomap.MCS.getMapping(db_mol[0].getMolecule(), db_mol[1].getMolecule(), hydrogens=False, fname='mcs_h' + str(atomIndex1) + "_" + str(atomIndex2) + '.png')
        with open("mcs_mapping_" + str(atomIndex1) + "_" + str(atomIndex2), "w") as mappingFile:  # cg
            for item in MC_h[atomIndex1,atomIndex2]._MCS__map_moli_molj:  # cg
                mappingFile.write(str(item[0] + 1) + " " + str(item[1] + 1) + "\n")  # Lomap indices start at 0, we need a start at 1 (used by prepare_cp2k_mapping) # cg


# Checking the output file
def help():
    print "\nUsage: hqh_sp_prepare_td_pairings_lomap_h.py <input file folder> <output filename> <ncpus> <time> <draw pairwise MSC maps flag>\n\n"

# Checking if this file is run as the main program 
if __name__ == '__main__':
    # Checking the number of arguments 
    if (len(sys.argv) != 6):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 5 input arguments. Exiting..."
        help()
        exit(1)

    else:
        main(sys.argv[1], outputFileBasename=sys.argv[2], ncpus=int(sys.argv[3]), time=int(sys.argv[4]), draw_pairwise_mcs=sys.argv[5])