#!/usr/bin/env python
from scipy.stats import norm
import matplotlib.mlab as mlab
import matplotlib.pyplot as plt
plt.switch_backend('agg')
import math
import sys
import matplotlib.patheffects as pe

def main(data1_filename, data2_filename, fitting_type, outputfile_basename):

    # Reading the data from text files, one number per line
    values1 = []
    for item in open(data1_filename,'r'):
        item = item.strip()
        if item != '':
            try:
                values1.append(float(item))
            except ValueError:
                pass
    values2 = []
    for item in open(data2_filename,'r'):
        item = item.strip()
        if item != '':
            try:
                values2.append(float(item))
            except ValueError:
                pass

    # the histogram of the data
    bin_count_1=int(math.sqrt(len(values1)))
    n_1, bins_1, patches = plt.hist(values1, bin_count_1, normed=1, facecolor='purple', alpha=0.75)
    bin_count_2=int(math.sqrt(len(values2)))
    n_1, bins_2, patches = plt.hist(values2, bin_count_2, normed=1, facecolor='blue', alpha=0.75)

    # Adding a fit of the data
    if fitting_type == "normal":
        # Fitting data1
        (fit1_mu, fit1_sigma) = norm.fit(values1)
        hist_values_1 = mlab.normpdf( bins_1, fit1_mu, fit1_sigma)
        line_1, = plt.plot(bins_1, hist_values_1, 'm', linewidth=2, label="$ \Delta_1 U $: $ \mu=%.3f,\ \sigma=%.3f $" %(fit1_mu, fit1_sigma), path_effects=[pe.Stroke(linewidth=3, foreground='k'), pe.Normal()])

        # Fitting data2
        (fit2_mu, fit2_sigma) = norm.fit(values2)
        hist_values_2 = mlab.normpdf( bins_2, fit2_mu, fit2_sigma)
        line_2, = plt.plot(bins_2, hist_values_2, 'b', linewidth=2, label="$ \Delta_2 U $: $ \mu=%.3f,\ \sigma=%.3f $" %(fit2_mu, fit2_sigma), path_effects=[pe.Stroke(linewidth=3, foreground='k'), pe.Normal()])

        plt.legend(fontsize='small', loc=0, title="Fitted normal distributions")
        plt.title(r'Histograms and of $ \Delta_1 U $ and $ \Delta_2 U $')
    elif fitting_type == "none":
        plt.title(r'$\mathrm{Histogram\ of\ \Delta U}')

    #plot
    plt.xlabel('$\Delta U$')
    plt.ylabel('P($\Delta U$)')
    plt.grid(True)
    plt.savefig(outputfile_basename + ".png", bbox_inches='tight')


def help():
    print "\nUsage: hqh_fec_plot_hist.py <data file 1> <data file 2> <fitting type> <outputfile_basename>\n"
    print "The data file is a text file with one column of values."
    print "Fitting types: normal, none\n\n"

# Checking if this file is run as the main program 
if __name__ == '__main__':

    # Checking the number of arguments 
    if (len(sys.argv) != 5):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 4 parameters. Exiting..."
        help()
        exit(1)

    else:
        main(*sys.argv[1:])