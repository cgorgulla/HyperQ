"""
Summary:


Copyright (C) 2016, Christoph Gorgulla

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http.//www.gnu.org/licenses/>.


Classes:

"""
from __future__ import division
import math
import matplotlib.pyplot as plt
plt.switch_backend('agg')
from hyperq.functions import *

class BAR:
    
    def __init__(self, U1_U1_filename, U1_U2_filename, U2_U1_filename, U2_U2_filename, C_filename, temp, outputFilename):
        # The first potential is always the sampling potential, the second one is the evaluating potential.\n\n

        # Reading in the values of the input files into lists
        filenames = [U1_U1_filename, U1_U2_filename, U2_U1_filename, U2_U2_filename, C_filename]
        # value_types = ["U1_U1_values", "U1_U2_values", "U2_U1_values", "U2_U2_values", "C_values"]
        self.values = dict.fromkeys(filenames)
        for filename in filenames:
            self.values[filename] = np.loadtxt(filename)
    
        # Variables 
        self.U1_U1_filename = U1_U1_filename
        self.U1_U2_filename = U1_U2_filename
        self.U2_U1_filename = U2_U1_filename
        self.U2_U2_filename = U2_U2_filename
        self.C_filename = C_filename
        self.C_values_accepted = [] # We only need the C-values for which the sum2 is not zero, since we are skipping such ones
        self.delta_F_1 = []
        self.delta_F_1_reduced = []
        self.delta_F_2 = []
        self.delta_F_2_reduced = []
        self.temp = float(temp)  # Kelvin
        # self.energyFactor = 627.509469           # hartree -> kcal/mole    # https://en.wikipedia.org/wiki/Hartree
        self.energyFactor = 1
        self.k_b = 0.0019872041  # in kcal/(mol*K)
        self.plt = None
        self.outputFilename = outputFilename
    
    def compute_bar(self):
        # Loop for each C-value
        for C in self.values[self.C_filename]:
            
            # Printing some information
            print "=======================    C=%07.3f   =======================" % C
    
            # First BAR equation
            sum_1 = 0
            sum_2 = 0
            n_1 = 0
            n_2 = 0
            # Checking if the number of values provided are the same for each pair
            if len(self.values[self.U1_U1_filename]) == len(self.values[self.U1_U2_filename]):
                n_1 = len(self.values[self.U1_U1_filename])  # The number of snapshots from the sampling wrt to U1 -> coordinates of U1 MD
            else:
                errorMessage="Error: The files " + self.U1_U1_filename + " and " + self.U1_U2_filename + " contain an unequal number of values."
                raise TypeError(errorMessage)
            if len(self.values[self.U2_U1_filename]) == len(self.values[self.U2_U2_filename]):
                n_2 = len(self.values[self.U2_U2_filename])  # The number of snapshots from the sampling wrt to U2 -> coordinates of U2 MD
            else:
                errorMessage="Error: The files " + self.U2_U1_filename + " and " + self.U2_U2_filename + " contain an unequal number of values."
                raise TypeError(errorMessage)
            for i in range(0, n_2 - 1):
                sum_2 += fermi_function((self.k_b * self.temp) ** (-1) * self.energyFactor * (self.values[self.U2_U1_filename][i] - self.values[self.U2_U2_filename][i]) + C)
            for i in range(0, n_1 - 1):
                sum_1 += fermi_function((self.k_b * self.temp) ** (-1) * self.energyFactor * (self.values[self.U1_U2_filename][i] - self.values[self.U1_U1_filename][i]) - C)

            # If sum_2 is 0 we cannot use it... -> math error
            if sum_2 == 0:
                print("Warning: sum_2 is zero. Skipping this C-value...")
                continue

            self.delta_F_1_reduced.append(math.log(sum_2 / sum_1) + C - math.log(n_2 / n_1))
            self.delta_F_1.append(-(self.k_b * self.temp) * (math.log(sum_2 / sum_1) + C - math.log(n_2 / n_1)))  # https://en.wikipedia.org/wiki/Boltzmann_constant
            self.C_values_accepted.append(C)

            # Second BAR equation
            self.delta_F_2_reduced.append(C - math.log(n_2 / n_1))
            self.delta_F_2.append(-(self.k_b * self.temp) * (C - math.log(n_2 / n_1)))
    
            # Printing some information
            print "delta_F_1_reduced (eqn_1) =", self.delta_F_1_reduced[-1]
            print "delta_F_2_reduced (eqn_2) =", self.delta_F_2_reduced[-1]
            print "delta_F_1 (eqn_1) =", self.delta_F_1_reduced[-1]
            print "delta_F_2 (eqn_2) =", self.delta_F_2_reduced[-1]

    
        # Finding the intersection/least distance
        self.diff_F = np.absolute(np.asarray(self.delta_F_2) - np.asarray(self.delta_F_1))
        self.diff_F_min_index = np.argmin(self.diff_F)
        if isinstance(self.diff_F_min_index, np.ndarray):
            self.diff_F_min_index = self.diff_F_min_index[0]

        self.diff_F_min_1 = self.delta_F_1[self.diff_F_min_index]
        self.diff_F_min_2 = self.delta_F_2[self.diff_F_min_index]
        self.diff_F_min_1_reduced = self.delta_F_1_reduced[self.diff_F_min_index]
        self.diff_F_min_2_reduced = self.delta_F_2_reduced[self.diff_F_min_index]
        print
        print "                    Final results"
        print "****************************************************************"
        print "Min (Delta F_eqn1 - F_eqn2) at value C=", self.C_values_accepted[self.diff_F_min_index]
        print "Delta_F equation 1: ", self.diff_F_min_1, " kcal/mol"
        print "Delta_F equation 2: ", self.diff_F_min_2, " kcal/mol"
        print "Delta_F equation 1 reduced: ", self.diff_F_min_1_reduced
        print "Delta_F equation 2 reduced: ", self.diff_F_min_2_reduced
    
    
    def write_delta_F_values(self):
        # Writing out the values
        with open("bar.out.eqn_1_reduced", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_1_reduced[i]) + "\n")

        with open("bar.out.eqn_1", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_1[i]) + "\n")

        with open("bar.out.eqn_2_reduced", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_2_reduced[i]) + "\n")

        with open("bar.out.eqn_2", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_2[i]) + "\n")
                
        
    def write_results(self):

        with open(self.outputFilename+".values", "w") as file:
            
            file.write("Min (Delta F_eqn1 - F_eqn2) at value C=" + str(self.C_values_accepted[self.diff_F_min_index]) + "\n")
            file.write("Delta_F equation 1: " + str(self.diff_F_min_1) + " kcal/mol" + "\n")
            file.write("Delta_F equation 2: "+ str(self.diff_F_min_2) + " kcal/mol" + "\n")
            file.write("Delta_F equation 1 reduced: " + str(self.diff_F_min_1_reduced) + "\n")
            file.write("Delta_F equation 2 reduced: " + str(self.diff_F_min_2_reduced) + "\n")

    
    def plot(self, mode):
        
        # Creating the plot for the full (unreduced) equation
        print "\n\n Creating the plot related to the bar-method"
        plt.plot(self.C_values_accepted, self.delta_F_1, 'm--', label="Equation 1")
        plt.plot(self.C_values_accepted, self.delta_F_2, 'k--', label="Equation 2")
        plt.xlabel('C')
        plt.ylabel('Free energy difference [kcal/mole]')

        # Saving/displaying the plot
        # Commented out because we set plt.switch_backend('agg'), which does not support showing plots
        if mode == "plot":
            plt.switch_backend('TkAgg')
            plt.show()
        
        # Showing the plot
        elif mode == "save":
            plt.savefig(self.outputFilename +".plot.unreduced.png", bbox_inches='tight')
            plt.savefig(self.outputFilename +".plot.unreduced.pdf", bbox_inches='tight')

        # Creating the plot for the reduced equation
        plt.clf()
        print "\n\n Creating the plot related to the bar-method"
        plt.plot(self.C_values_accepted, self.delta_F_1_reduced, 'm--', label="Equation 1")
        plt.plot(self.C_values_accepted, self.delta_F_2_reduced, 'k--', label="Equation 2")
        plt.xlabel('C')
        plt.ylabel('Free energy difference [kcal/mole]')

        # Saving/displaying the plot
        # Commented out because we set plt.switch_backend('agg'), which does not support showing plots
        if mode == "plot":
            plt.switch_backend('TkAgg')
            plt.show()

        # Showing the plot
        elif mode == "save":
            plt.savefig(self.outputFilename +".plot.reduced.png", bbox_inches='tight')
            plt.savefig(self.outputFilename +".plot.reduced.pdf", bbox_inches='tight')
