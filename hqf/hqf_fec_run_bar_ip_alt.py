#!/usr/bin/env python
import sys
import numpy as np
import scipy
from scipy.optimize import leastsq
import matplotlib.pyplot as plt

def bar_ip(delta_U1_filename, delta_U2_filename):
    
    # Reading in the files
    k_b = 0.0019872041
    T = 300 
    delta_U1_values = np.loadtxt(delta_U1_filename)
    delta_U2_values = np.loadtxt(delta_U2_filename)
    delta_U1_values = delta_U1_values /(k_b * T)
    delta_U2_values = delta_U2_values /(k_b * T)
    # Creating the histograms
    binCount = 100
    plotMeshCount = 1000
    delta_U_min =  min(delta_U1_values.min(),delta_U2_values.min())
    delta_U_max =  max(delta_U1_values.max(),delta_U2_values.max())
    delta_U_min = -200
    delta_U_mesh_centers = np.linspace(delta_U_min, delta_U_max, binCount)
    mesh_size = (delta_U_max-delta_U_min)/binCount
    delta_U_mesh_edges = np.linspace(delta_U_min-mesh_size/2, delta_U_max+mesh_size/2, binCount+1)
    delta_U_mesh_plot = np.linspace(delta_U_min-mesh_size/2, delta_U_max+mesh_size/2, plotMeshCount)
    hist_U1_values = np.histogram(delta_U1_values, delta_U_mesh_edges, normed=True)[0]
    hist_U2_values = np.histogram(delta_U2_values, delta_U_mesh_edges, normed=True)[0]
    
    # Computing 
    line_U1 = np.log(hist_U1_values) - 0.5 * delta_U_mesh_centers
    line_U2 = np.log(hist_U2_values) + 0.5 * delta_U_mesh_centers
    # line_combi = -((k_b*T)**(-1))*(np.log(hist_U2_values) - np.log(hist_U1_values) + delta_U_mesh_centers)
    
    
    # Plotting the resulting fit

    plt.plot(delta_U_mesh_centers, line_U1,'bo', delta_U_mesh_centers, line_U2, 'ko')
    #plt.plot(delta_U_mesh_centers,line_combi, 'bo')
    plt.show()    

def help():
    print "Usage: hqf_fec_run_bar_ip_alt.py <file with U1_U2-U1_U1 values> <file with U2_U2-U2_U1 values>"


# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 3):
        help()
    else:
        bar_ip(sys.argv[1], sys.argv[2])
