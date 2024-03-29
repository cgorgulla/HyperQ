#!/usr/bin/env python
from __future__ import division
import sys
import numpy as np
import scipy
from scipy.optimize import leastsq
import matplotlib.pyplot as plt
plt.switch_backend('agg')
import math


def bar_ip(delta_U1_filename, delta_U2_filename):
    # TODO: compute histograms, max overlap like GK, and if required abort. max overlap by min of of both historgrams, then max of the mins. use x values like in bar-ip -> joint
    # Reading in the files
    k_b = 0.0019872041
    T = 300
    #beta = 1/(k_b * T)
    delta_U1_values = np.loadtxt(delta_U1_filename)
    delta_U2_values = np.loadtxt(delta_U2_filename)
    #delta_U1_values = delta_U1_values /(k_b * T)
    #delta_U2_values = delta_U2_values /(k_b * T)
    n_1 = len(delta_U1_values)
    n_2 = len(delta_U2_values)

    # Creating the histograms
    binCount = int(math.sqrt(n_1+ n_2))
    plotMeshCount = 1000
    delta_U_min =  min(delta_U1_values.min(),delta_U2_values.min())
    delta_U_max =  max(delta_U1_values.max(),delta_U2_values.max())
    delta_U_mesh_centers = np.linspace(delta_U_min, delta_U_max, binCount)
    mesh_size = (delta_U_max-delta_U_min)/binCount
    delta_U_mesh_edges = np.linspace(delta_U_min-mesh_size/2, delta_U_max+mesh_size/2, binCount+1)
    delta_U_mesh_plot = np.linspace(delta_U_min-mesh_size/2, delta_U_max+mesh_size/2, plotMeshCount)
    hist_U1_values = np.histogram(delta_U1_values, delta_U_mesh_edges, normed=True)[0]
    hist_U2_values = np.histogram(delta_U2_values, delta_U_mesh_edges, normed=True)[0]
    # The problem with using automatic bin size determination is that the regions will be different for U1, U2 -> problems plotting? and we want the IP also to consider the space in between, right? Or not?

    # Fitting the distribution to the data
    ## Model functions
    ### Normal distribution
    def dist_normal(x_values, model_fct_paras):
        # paras[0] : sigma
        # paras[1] : mu
        results = []
        for x_value in x_values:
            results.append(((2*(model_fct_paras[0]**2)*np.pi)**(-0.5)*(np.exp(-((x_value-model_fct_paras[1])**2)/(2*model_fct_paras[0]**2)))))
        return np.array(results)

    ### Bimodal normal distribution 
    def dist_normal_2(x, model_fct_paras):
        # paras[0] : sigma
        # paras[1] : mu

        return (2*(model_fct_paras[0]**2)*np.pi)**(-0.5)*(np.exp(-((x-model_fct_paras[1])**2)/(2*model_fct_paras[0]**2))) + (2*(model_fct_paras[2]**2)*np.pi)**(-0.5)*(np.exp(-((x-model_fct_paras[3])**2)/(2*model_fct_paras[2]**2)))

    ### Rayleigh distribution
    def dist_vonmises(x, model_fct_paras):
        # paras[0] : kappa
        value = np.exp(model_fct_paras[0] * np.cos(x)) / (2*np.pi*scipy.special.iv(0,model_fct_paras[0]))
        return value


    # Residual function - fitting p1 directly
    model_fct_U2_values = None
    def residual_fct_1(paras):
        residues = np.zeros(len(delta_U_mesh_centers) * 2)
        # Residuals of the first distribution
        model_fct_U1_values = model_fct(delta_U_mesh_centers, paras[1:])
        residues[0:len(delta_U_mesh_centers)] = model_fct_U1_values - hist_U1_values
        print "residues 1"
        print residues
        # Computing the values of the second distribution
        #model_fct_U2_values = np.exp((-(k_b*T)**(-1))*paras[0] - delta_U_mesh_centers) * model_fct_U1_values
        model_fct_U2_values = np.exp(paras[0] - delta_U_mesh_centers) * model_fct_U1_values
        # Residuals of the second distribution
        residues[len(delta_U_mesh_centers):] = model_fct_U2_values - hist_U2_values
        print "residues 2"
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
        #model_fct_U1_values = model_fct_U2_values / np.exp((-(k_b*T)**(-1))*paras[0] - delta_U_mesh_centers)
        model_fct_U1_values = model_fct_U2_values / np.exp(paras[0] - delta_U_mesh_centers)
        # Residuals of the second distribution
        residues[len(delta_U_mesh_centers):] = model_fct_U1_values - hist_U1_values

        # Returning the residuals
        return residues

    # Least squares fitting
    paras_initial = np.array([0, 10, 0]) # normal distribution, first value is the delta_G
    #paras_initial = np.array([0, 10, 0, 10, 0]) # normal distribution_2
    #paras_initial = np.array([0, 1]) # von mises 
    model_fct = dist_normal
    leastsq_results = leastsq(residual_fct_1, paras_initial, ftol=1.49012e-8, xtol=1.49012e-8)  # Switching function
    paras_final = leastsq_results[0]
    Delta_F_final_unreduced = k_b * T * paras_final[0]
    #Delta_F_final = paras_final[0]

    # Printing the results of the LS fit
    print "Estimated parameteres"
    print "****************************"
    print "Estimated Delta FE: ", Delta_F_final_unreduced
    print "Model function parameters: ", paras_final[1:]    
    
    # Plotting the resulting fit
    # residual_fct_1
    model_fct_U1_values_fit = model_fct(delta_U_mesh_centers, paras_final[1:]) # Switchting this two with the next two
    #model_fct_U2_values_fit = np.exp((-(k_b*T)**(-1))*paras_final[0] - delta_U_mesh_centers) * model_fct_U1_values_fit
    model_fct_U2_values_fit = np.exp(paras_final[0] - delta_U_mesh_centers) * model_fct_U1_values_fit


    # residual_fct_2
    #model_fct_U2_values_fit = model_fct(delta_U_mesh_centers, paras_final[1:])
    #model_fct_U1_values_fit = model_fct_U2_values_fit / np.exp((-(k_b*T)**(-1))*paras_final[0] - delta_U_mesh_centers)
    
    plt.plot(delta_U_mesh_centers, model_fct_U1_values_fit,'m-')
    plt.plot(delta_U_mesh_centers, hist_U1_values, 'ko')
    # plt.plot(delta_U_mesh_centers,hist_U1_values,'bo', delta_U_mesh_plot,model_fct_U1_values_fit,'b-', delta_U_mesh_centers,hist_U2_values,'ko', delta_U_mesh_plot,model_fct_U2_values_fit,'m-')
    plt.plot(delta_U_mesh_centers, hist_U2_values,'bo')
    plt.plot(delta_U_mesh_centers, model_fct_U2_values_fit, 'c-')
    plt.xlabel('DeltaU')
    plt.ylabel('p(Delta U)')
    #plt.xticks(np.arange(min(delta_U_mesh_centers), max(delta_U_mesh_centers) + 1, 1.0))

    #plt.savefig("plot.unreduced.png", bbox_inches='tight')
    #plt.savefig("plot.unreduced.pdf", bbox_inches='tight')
    plt.savefig("bar_ip.plot.png", bbox_inches='tight')


def help():
    print "\nUsage: hqf_fec_run_bar_ip.py <file with U1_U2-U1_U1 values> <file with U2_U2-U2_U1 values>"
    print "The first potential is always the sampling potential, the second one is the evaluating potential.\n\n"


# Checking if this file is run as the main program
if __name__ == '__main__':
    # Checking the number of arguments
    if (len(sys.argv) != 3):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 2 input arguments. Exiting..."
        help()
        exit(1)

    else:
        bar_ip(sys.argv[1], sys.argv[2])
