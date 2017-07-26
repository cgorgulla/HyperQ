#!/usr/bin/env python
from scipy.stats import norm
import matplotlib.mlab as mlab
import matplotlib.pyplot as plt
plt.switch_backend('agg')
import math
import sys

def main(data_filename, fitting_type, outputfile_basename):

    # Reading the data from a text file, one number per line
    values = []
    for item in open(data_filename,'r'):
        item = item.strip()
        if item != '':
            try:
                values.append(float(item))
            except ValueError:
                pass

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
    print "Usage: hqh_fec_plot_hist.py <data file> <fitting type> <outputfile_basename>"
    print "The data file is a text file with one column of values."
    print "Fitting types: normal, none"

# Checking if this file is run as the main program 
if __name__ == '__main__':

    # Checking the number of arguments 
    if (len(sys.argv) != 4):
        help()
    else:
        main(*sys.argv[1:])