#!/usr/bin/env python
import sys
import numpy as np
import scipy
from scipy.optimize import leastsq
import matplotlib.pyplot as plt

iteration = 0

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
    delta_U_mesh_centers = np.linspace(delta_U_min, delta_U_max, binCount)
    mesh_size = (delta_U_max-delta_U_min)/binCount
    delta_U_mesh_edges = np.linspace(delta_U_min-mesh_size/2, delta_U_max+mesh_size/2, binCount+1)
    delta_U_mesh_plot = np.linspace(delta_U_min-mesh_size/2, delta_U_max+mesh_size/2, plotMeshCount)
    hist_U1_values = np.histogram(delta_U1_values, delta_U_mesh_edges, normed=True)[0]
    hist_U2_values = np.histogram(delta_U2_values, delta_U_mesh_edges, normed=True)[0]

    # Fitting the distribution to the data
    ## Model functions
    ### Normal distribution
    def dist_normal(x, model_fct_paras):
        # paras[0] : sigma
        # paras[1] : mu
        return (2*(model_fct_paras[0]**2)*np.pi)**(-0.5)*(np.exp(-((x-model_fct_paras[1])**2)/(2*model_fct_paras[0]**2)))
    ### Bimodal normal distribution 
    def dist_normal_2(x, model_fct_paras):
        # paras[0] : sigma
        # paras[1] : mu
        global iteration
        iteration = iteration + 1
        print "LS Iteration: " + str(iteration)
        print "model_fct_paras: " + str(model_fct_paras)

        return (2*(model_fct_paras[0]**2)*np.pi)**(-0.5)*(np.exp(-((x-model_fct_paras[1])**2)/(2*model_fct_paras[0]**2))) + (2*(model_fct_paras[2]**2)*np.pi)**(-0.5)*(np.exp(-((x-model_fct_paras[3])**2)/(2*model_fct_paras[2]**2)))

    ### Rayleigh distribution
    def dist_vonmises(x, model_fct_paras):
        # paras[0] : kappa
        value = np.exp(model_fct_paras[0] * np.cos(x)) / (2*np.pi*scipy.special.iv(0,model_fct_paras[0]))
        print value
        return value
    
    # Residual function - fitting p1 directly 
    def residual_fct_1(paras):
        residues = np.zeros(len(delta_U_mesh_centers) * 2)
        # Residuals of the first distribution
        model_fct_U1_values = model_fct(delta_U_mesh_centers, paras[1:])
        residues[0:len(delta_U_mesh_centers)] = model_fct_U1_values - hist_U1_values

        # Computing the values of the second distribution
        model_fct_U2_values = np.exp((-(k_b*T)**(-1))*paras[0] - delta_U_mesh_centers) * model_fct_U1_values
                                     
        # Residuals of the second distribution
        residues[len(delta_U_mesh_centers):] = model_fct_U2_values - hist_U2_values
        print "hist_u1_values"
        print hist_U1_values
        print "model_fct_U1_values"
        print model_fct_U1_values
        print "hist_u2_values"
        print hist_U2_values
        print "model_fct_U2_values"
        print model_fct_U2_values
        print "residues"
        print residues
        
        # Returning the residuals
        return residues
    
    # Residual function - fitting p2 directly 
    def residual_fct_2(paras):
        residues = np.zeros(len(delta_U_mesh_centers) * 2)
        # Residuals of the first distribution
        model_fct_U2_values = model_fct(delta_U_mesh_centers, paras[1:])
        residues[0:len(delta_U_mesh_centers)] = model_fct_U2_values - hist_U2_values

        # Computing the values of the second distribution
        model_fct_U1_values = model_fct_U2_values / np.exp((-(k_b*T)**(-1))*paras[0] - delta_U_mesh_centers)
        # Residuals of the second distribution
        residues[len(delta_U_mesh_centers):] = model_fct_U1_values - hist_U1_values
        print "hist_U1_values"
        print hist_U1_values
        print "model_fct_U1_values"
        print model_fct_U1_values
        print "hist_u2_values"
        print hist_U2_values
        print "model_fct_U2_values"
        print model_fct_U2_values
        print "residues"
        print residues

        # Returning the residuals
        return residues
    
    # Residual function 
    def residual_fct_1_test(paras):
        model_fct_U1_values = model_fct(delta_U_mesh_centers, paras[1:])
        # Computing the values of the second distribution
        model_fct_U2_values = np.exp((-(k_b*T)**(-1))*paras[0] - delta_U_mesh_centers) * model_fct_U1_values
        # Residuals of the second distribution
        residues = model_fct_U2_values - hist_U2_values
        print "hist_u2_values"
        print hist_U2_values
        print "model_fct_U2_values"
        print model_fct_U2_values
        print "residues"
        print residues
        # Returning the residuals
        return residues

    # Least squares fitting
    #paras_initial = np.array([0, 10, 0]) # normal distribution
    paras_initial = np.array([0, 10, 0, 10, 0]) # normal distribution_2
    #paras_initial = np.array([0, 1]) # von mises 
    model_fct = dist_normal_2
    paras_final, success = leastsq(residual_fct_1, paras_initial[:], ftol=1.49012e-8, xtol=1.49012e-8)  # Switching function
        
    # Printing the results of the LS fit
    print "Estimated parameteres"
    print "****************************"
    print "Estimated Delta FE: ", paras_final[0]
    print "Model function parameters: ", paras_final[1:]    
    
    # Plotting the resulting fit
    model_fct_U1_values_fit = model_fct(delta_U_mesh_centers, paras_final[1:]) # Switchting this two with the next two
    model_fct_U2_values_fit = np.exp((-(k_b*T)**(-1))*paras_final[0] - delta_U_mesh_centers) * model_fct_U1_values_fit
    
    #model_fct_U2_values_fit = model_fct(delta_U_mesh_centers, paras_final[1:])
    #model_fct_U1_values_fit = model_fct_U2_values_fit / np.exp((-(k_b*T)**(-1))*paras_final[0] - delta_U_mesh_centers)
    
    plt.plot(delta_U_mesh_centers,model_fct_U1_values_fit,'m-')
    plt.plot(delta_U_mesh_centers, hist_U1_values, 'ko')
    # plt.plot(delta_U_mesh_centers,hist_U1_values,'bo', delta_U_mesh_plot,model_fct_U1_values_fit,'b-', delta_U_mesh_centers,hist_U2_values,'ko', delta_U_mesh_plot,model_fct_U2_values_fit,'m-')
    plt.plot(delta_U_mesh_centers,hist_U2_values,'bo')
    plt.plot(delta_U_mesh_centers, model_fct_U2_values_fit, 'c-')

    plt.show()
    

def help():
    print "Usage: hqf_fec_run_bar_ip.py <file with U1_U2-U1_U1 values> <file with U2_U2-U2_U1 values>"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"


# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 3):
        help()
    else:
        bar_ip(sys.argv[1], sys.argv[2])
