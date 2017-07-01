#!/usr/bin/env python
import sys

def main(dotFilename):
    
    moleculeNames = {}
    edges = []
    with open(dotFilename, "r") as dotFile:
        for line in dotFile:
            lineSplit = line.split()
            if lineSplit[0].isdigit():
                if lineSplit[1] == "--":
                    edges.append([lineSplit[0], lineSplit[2]])
                else:
                    lineSplit_2 = line.split("\"")
                    moleculeName = lineSplit_2[1].split(".")[0]
                    moleculeNames[lineSplit[0]] = moleculeName
                    
    with open("td.pairings", "w") as pairingsFile:
        for edge in edges:
            pairingsFile.write(str(edge[0]) + " " + str(edge[1]) + " " + moleculeNames[edge[0]] + " " + moleculeNames[edge[1]] + "\n")

    with open("td.pairings.molecules", "w") as moleculesFile:
        for moleculeIndex in sorted(moleculeNames.keys()):
            moleculesFile.write(str(moleculeIndex + " " + moleculeNames[moleculeIndex] + "\n"))
            
            
def help():
    print "Usage: hqh_sp_prepare_td-pairings.py <lomap dot filename preprocessed>"

# Checking if this file is run as the main program 
if __name__ == '__main__':

    # Checking the number of arguments 
    if (len(sys.argv) != 2):
        help()
    else:
        main(*sys.argv[1:])