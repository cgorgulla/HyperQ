#!/usr/bin/env python
from scipy.stats import norm
import matplotlib.mlab as mlab
import matplotlib.pyplot as plt
plt.switch_backend('agg')
import math
import sys

def createPlot(values, fitting_type, outputfile_basename):

    # the histogram of the data
    bin_count=int(math.sqrt(len(values)))
    n, bins, patches = plt.hist(values, bin_count, normed=1, facecolor='purple', alpha=0.75)

    # Adding a fit of the data
    if fitting_type == "normal":
        (mu, sigma) = norm.fit(values)
        y = mlab.normpdf( bins, mu, sigma)
        l = plt.plot(bins, y, 'b--', linewidth=2)
        plt.title(r'$\mathrm{Histogram\ of\ \Delta U:}\ \mu=%.3f,\ \sigma=%.3f$' %(mu, sigma))
    elif fitting_type == "none":
        plt.title(r'$\mathrm{Histogram\ of\ \Delta U}')

    #plot
    plt.xlabel('$\Delta U$')
    plt.ylabel('P($\Delta U$)')
    plt.grid(True)
    plt.savefig(outputfile_basename + ".png", bbox_inches='tight')


def help():
    print "\nUsage: hqh_fec_plot_hist.py <data file> <fitting type> <outputfile_basename>\n"
    print "The data file is a text file with one column of values."
    print "Fitting types: normal, none\n\n"

# Checking if this file is run as the main program 
if __name__ == '__main__':

    # Checking the number of arguments 
    if (len(sys.argv) != 4):
        print "Error: " + str(len(sys.argv[1:])) + " arguments provided: " + str(sys.argv)
        print "Required are 3 input arguments. Exiting..."
        help()
        exit(1)

    else:

        # Variables
        data_filename = sys.argv[1]
        fitting_type = sys.argv[2]
        outputfile_basename = sys.argv[3]

        # Reading the data from the input text file, one number per line
        values = []
        for item in open(data_filename,'r'):
            item = item.strip()
            if item != '':
                itemFloat = float(item)
                try:
                    values.append(itemFloat)
                except ValueError:
                    pass

        # Creating the plot
        createPlot(values, fitting_type, outputfile_basename)