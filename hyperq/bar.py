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
import scipy.optimize as spo


class BAR:
    def __init__(self, U1_U1_filename, U1_U2_filename, U2_U1_filename, U2_U2_filename, delta_F_min, delta_F_max, outputFilename, temp, C_absolute_tolerance):
        # The first potential is always the sampling potential, the second one is the evaluating potential.

        # Reading in the values of the input files into lists
        filenames = [U1_U1_filename, U1_U2_filename, U2_U1_filename, U2_U2_filename]
        self.values = dict.fromkeys(filenames)
        for filename in filenames:
            self.values[filename] = np.loadtxt(filename)

        # Variables
        self.U1_U1_filename = U1_U1_filename
        self.U1_U2_filename = U1_U2_filename
        self.U2_U1_filename = U2_U1_filename
        self.U2_U2_filename = U2_U2_filename
        self.C_values_accepted = []  # We only need the C-values for which the sum2 is not zero, since we are skipping such ones
        self.delta_F_1 = []
        self.delta_F_2 = []
        self.temp = float(temp)  # Kelvin
        # self.energyFactor = 627.509469           # hartree -> kcal/mol    # https://en.wikipedia.org/wiki/Hartree
        self.energyFactor = 1
        self.k_b = 0.0019872041  # in kcal/(mol*K)
        self.beta = 1. / (self.k_b * self.temp)
        self.outputFilename = outputFilename
        self.delta_F_min = float(delta_F_min)
        self.delta_F_max = float(delta_F_max)
        self.C_absolute_tolerance = float(C_absolute_tolerance)

    def compute_bar(self):

        # Basic setup

        # First BAR equation
        sum_1 = 0
        sum_2 = 0
        # Checking if the number of values provided are the same for each pair
        if len(self.values[self.U1_U1_filename]) == len(self.values[self.U1_U2_filename]):
            self.n_1 = len(self.values[
                          self.U1_U1_filename])  # The number of snapshots from the sampling wrt to U1 -> coordinates of U1 MD
        else:
            errorMessage = "Error: The files " + self.U1_U1_filename + " and " + self.U1_U2_filename + " contain an unequal number of values."
            raise TypeError(errorMessage)
        if len(self.values[self.U2_U1_filename]) == len(self.values[self.U2_U2_filename]):
            self.n_2 = len(self.values[
                          self.U2_U2_filename])  # The number of snapshots from the sampling wrt to U2 -> coordinates of U2 MD
        else:
            errorMessage = "Error: The files " + self.U2_U1_filename + " and " + self.U2_U2_filename + " contain an unequal number of values."
            raise TypeError(errorMessage)

        # C-values
        self.C_min = self.beta * self.delta_F_min + math.log(self.n_2 / self.n_1) # Delta F = k_b*T*(C-ln(n_2/n_1)) <=> C= beta*DeltaF+ln(n_2/n_1)
        self.C_max = self.beta * self.delta_F_max + math.log(self.n_2 / self.n_1)
        self.C_count = int((self.C_max - self.C_min) / self.C_absolute_tolerance)
        self.C_values = np.linspace(self.C_min, self.C_max, self.C_count)

        # Loop for each C-value
        for C in self.C_values:

            # Printing some information
            print "=======================    C=%07.3f   =======================" % C

            if 1.6 <= C <= 2.2:
                print "flag"

            sum_1 = 0
            sum_2 = 0
            for i in range(0, self.n_2):
                sum_2 += fermi_function(self.beta * self.energyFactor * (self.values[self.U2_U1_filename][i] - self.values[self.U2_U2_filename][i]) + C)
            for i in range(0, self.n_1):
                sum_1 += fermi_function(self.beta * self.energyFactor * (self.values[self.U1_U2_filename][i] - self.values[self.U1_U1_filename][i]) - C)

            # If sum_2 is 0 we cannot use it... -> math error
            if sum_2 == 0:
                print("Warning: sum_2 is zero. Skipping this C-value...")
                continue

            # self.delta_F_1_reduced.append(math.log(sum_2 / sum_1) + C - math.log(n_2 / n_1))
            self.delta_F_1.append((self.k_b * self.temp) * (math.log(sum_2 / sum_1) + C - math.log(self.n_2 / self.n_1)))  # https://en.wikipedia.org/wiki/Boltzmann_constant
            self.C_values_accepted.append(C)

            # Second BAR equation
            # self.delta_F_2_reduced.append(C - math.log(n_2 / n_1))
            self.delta_F_2.append((self.k_b * self.temp) * (C - math.log(self.n_2 / self.n_1)))

            # Printing some information
            # print "delta_F_1_reduced (eqn_1) =", self.delta_F_1_reduced[-1]
            # print "delta_F_2_reduced (eqn_2) =", self.delta_F_2_reduced[-1]
            print "delta_F_1 (eqn_1) =", self.delta_F_1[-1]
            print "delta_F_2 (eqn_2) =", self.delta_F_2[-1]

        # Finding the intersection/least distance
        self.diff_F = np.absolute(np.asarray(self.delta_F_2) - np.asarray(self.delta_F_1))
        self.diff_F_min_index = np.argmin(self.diff_F)
        if isinstance(self.diff_F_min_index, np.ndarray):
            self.diff_F_min_index = self.diff_F_min_index[0]

        self.diff_F_min_1 = self.delta_F_1[self.diff_F_min_index]
        self.diff_F_min_2 = self.delta_F_2[self.diff_F_min_index]
        # self.diff_F_min_1_reduced = self.delta_F_1_reduced[self.diff_F_min_index]
        # self.diff_F_min_2_reduced = self.delta_F_2_reduced[self.diff_F_min_index]

        print
        print "                           BAR Summary"
        print "****************************************************************"
        print "delta_F_min (input parameter): ", self.delta_F_min
        print "delta_F_max (input parameter): ", self.delta_F_max
        print "Absolute tolerance w.r.t. C:", self.C_absolute_tolerance
        print "n_1: ", self.n_1
        print "n_2: ", self.n_2
        print "C_min: ", self.C_min
        print "C_max: ", self.C_max
        print "Temperature [K]: ", self.temp
        print "Min (Delta F_eqn1 - F_eqn2) at value C=", self.C_values_accepted[self.diff_F_min_index]
        print "Delta_F equation 1: ", self.diff_F_min_1, " kcal/mol"
        print "Delta_F equation 2: ", self.diff_F_min_2, " kcal/mol"
        print

    def write_delta_F_values(self):
        # Writing out the values
        with open("bar.out.eqn_1", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_1[i]) + "\n")

        with open("bar.out.eqn_2", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_2[i]) + "\n")

    def write_results(self):

        with open(self.outputFilename + ".values", "w") as file:
            file.write("Min (Delta F_eqn1 - F_eqn2) found at location C=" + str(
                self.C_values_accepted[self.diff_F_min_index]) + "\n")
            file.write("Delta_F equation 1: " + str(self.diff_F_min_1) + " kcal/mol" + "\n")
            file.write("Delta_F equation 2: " + str(self.diff_F_min_2) + " kcal/mol" + "\n")

    def plot(self, mode):

        # Creating the plot for the full (unreduced) equation
        print " * Creating the plot related to the BAR method"
        print
        plt.plot(self.C_values_accepted, self.delta_F_1, 'm--', label="BAR Equation 1")
        plt.plot(self.C_values_accepted, self.delta_F_2, 'k--', label="BAR Equation 2")
        plt.title("Plot of the two BAR equations")
        plt.legend(fontsize='small', loc=0, title="Fitted normal distributions")
        plt.xlabel('C')
        plt.ylabel('Free energy difference [kcal/mole]')

        # Saving/displaying the plot
        # Commented out because we set plt.switch_backend('agg'), which does not support showing plots
        if mode == "plot":
            plt.switch_backend('TkAgg')
            plt.show()

        # Showing the plot
        elif mode == "save":
            plt.savefig(self.outputFilename + ".plot.unreduced.png", bbox_inches='tight')
            plt.savefig(self.outputFilename + ".plot.unreduced.pdf", bbox_inches='tight')


class BAR_DeltaU:
    def __init__(self, U1_U2_minus_U1_U1_filename, U2_U1_minus_U2_U2_filename, delta_F_min, delta_F_max, outputFilename, temp, C_absolute_tolerance):
        # The first potential is always the sampling potential, the second one is the evaluating potential.

        # Reading in the values of the input files into lists
        filenames = [U1_U2_minus_U1_U1_filename, U2_U1_minus_U2_U2_filename]
        self.values = dict.fromkeys(filenames)
        for filename in filenames:
            self.values[filename] = np.loadtxt(filename)

        # Variables
        self.U1_U2_minus_U1_U1_filename = U1_U2_minus_U1_U1_filename
        self.U2_U1_minus_U2_U2_filename = U2_U1_minus_U2_U2_filename
        self.C_values_accepted = []  # We only need the C-values for which the sum2 is not zero, since we are skipping such ones
        self.delta_F_1 = []
        self.delta_F_2 = []
        self.temp = float(temp)  # Kelvin
        # self.energyFactor = 627.509469           # hartree -> kcal/mol    # https://en.wikipedia.org/wiki/Hartree
        self.energyFactor = 1
        self.k_b = 0.0019872041  # in kcal/(mol*K)
        self.beta = 1. / (self.k_b * self.temp)
        self.outputFilename = outputFilename
        self.delta_F_min = float(delta_F_min)
        self.delta_F_max = float(delta_F_max)
        self.C_absolute_tolerance = float(C_absolute_tolerance)

    def compute_bar(self):

        # Basic setup

        # First BAR equation
        self.n_1 = len(self.values[self.U1_U2_minus_U1_U1_filename])  # The number of snapshots from the sampling wrt to U1 -> coordinates of U1 MD
        self.n_2 = len(self.values[self.U2_U1_minus_U2_U2_filename])  # The number of snapshots from the sampling wrt to U1 -> coordinates of U1 MD

        # C-values
        self.C_min = self.beta * self.delta_F_min + math.log(self.n_2 / self.n_1) # Delta F = k_b*T*(C-ln(n_2/n_1)) <=> C= beta*DeltaF+ln(n_2/n_1)
        self.C_max = self.beta * self.delta_F_max + math.log(self.n_2 / self.n_1)
        self.C_count = int((self.C_max - self.C_min) / self.C_absolute_tolerance)
        self.C_values = np.linspace(self.C_min, self.C_max, self.C_count)

        # Loop for each C-value
        for C in self.C_values:

            # Printing some information
            print "=======================    C=%07.3f   =======================" % C

            if 1.6 <= C <= 2.2:
                print "flag"

            sum_1 = 0
            sum_2 = 0
            for i in range(0, self.n_2):
                sum_2 += fermi_function(self.beta * self.energyFactor * self.values[self.U2_U1_minus_U2_U2_filename][i] + C)
            for i in range(0, self.n_1):
                sum_1 += fermi_function(self.beta * self.energyFactor * self.values[self.U1_U2_minus_U1_U1_filename][i] - C)

            # If sum_2 is 0 we cannot use it... -> math error
            if sum_2 == 0:
                print("Warning: sum_2 is zero. Skipping this C-value...")
                continue

            # self.delta_F_1_reduced.append(math.log(sum_2 / sum_1) + C - math.log(n_2 / n_1))
            self.delta_F_1.append((self.k_b * self.temp) * (math.log(sum_2 / sum_1) + C - math.log(self.n_2 / self.n_1)))  # https://en.wikipedia.org/wiki/Boltzmann_constant
            self.C_values_accepted.append(C)

            # Second BAR equation
            # self.delta_F_2_reduced.append(C - math.log(n_2 / n_1))
            self.delta_F_2.append((self.k_b * self.temp) * (C - math.log(self.n_2 / self.n_1)))

            # Printing some information
            # print "delta_F_1_reduced (eqn_1) =", self.delta_F_1_reduced[-1]
            # print "delta_F_2_reduced (eqn_2) =", self.delta_F_2_reduced[-1]
            print "delta_F_1 (eqn_1) =", self.delta_F_1[-1]
            print "delta_F_2 (eqn_2) =", self.delta_F_2[-1]

        # Finding the intersection/least distance
        self.diff_F = np.absolute(np.asarray(self.delta_F_2) - np.asarray(self.delta_F_1))
        self.diff_F_min_index = np.argmin(self.diff_F)
        if isinstance(self.diff_F_min_index, np.ndarray):
            self.diff_F_min_index = self.diff_F_min_index[0]

        self.diff_F_min_1 = self.delta_F_1[self.diff_F_min_index]
        self.diff_F_min_2 = self.delta_F_2[self.diff_F_min_index]
        # self.diff_F_min_1_reduced = self.delta_F_1_reduced[self.diff_F_min_index]
        # self.diff_F_min_2_reduced = self.delta_F_2_reduced[self.diff_F_min_index]

        print
        print "                           BAR Summary"
        print "****************************************************************"
        print "delta_F_min (input parameter): ", self.delta_F_min
        print "delta_F_max (input parameter): ", self.delta_F_max
        print "Absolute tolerance w.r.t. C:", self.C_absolute_tolerance
        print "n_1: ", self.n_1
        print "n_2: ", self.n_2
        print "C_min: ", self.C_min
        print "C_max: ", self.C_max
        print "Temperature [K]: ", self.temp
        print "Min (Delta F_eqn1 - F_eqn2) at value C=", self.C_values_accepted[self.diff_F_min_index]
        print "Delta_F equation 1: ", self.diff_F_min_1, " kcal/mol"
        print "Delta_F equation 2: ", self.diff_F_min_2, " kcal/mol"
        print


    def write_delta_F_values(self):
        # Writing out the values
        with open("bar.out.eqn_1", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_1[i]) + "\n")

        with open("bar.out.eqn_2", "w") as file:
            for i in range(0, len(self.C_values_accepted) - 1):
                file.write(str(self.delta_F_2[i]) + "\n")

    def write_results(self):

        with open(self.outputFilename + ".values", "w") as file:
            file.write("Min (Delta F_eqn1 - F_eqn2) found at location C=" + str(
                self.C_values_accepted[self.diff_F_min_index]) + "\n")
            file.write("Delta_F equation 1: " + str(self.diff_F_min_1) + " kcal/mol" + "\n")
            file.write("Delta_F equation 2: " + str(self.diff_F_min_2) + " kcal/mol" + "\n")

    def plot(self, mode):

        # Creating the plot for the full (unreduced) equation
        print " * Creating the plot related to the BAR method"
        print
        plt.plot(self.C_values_accepted, self.delta_F_1, 'm--', label="BAR Equation 1")
        plt.plot(self.C_values_accepted, self.delta_F_2, 'k--', label="BAR Equation 2")
        plt.title("Plot of the two BAR equations")
        plt.legend(fontsize='small', loc=0, title="Fitted normal distributions")
        plt.xlabel('C')
        plt.ylabel('Free energy difference [kcal/mole]')

        # Saving/displaying the plot
        # Commented out because we set plt.switch_backend('agg'), which does not support showing plots
        if mode == "plot":
            plt.switch_backend('TkAgg')
            plt.show()

        # Showing the plot
        elif mode == "save":
            plt.savefig(self.outputFilename + ".plot.unreduced.png", bbox_inches='tight')
            plt.savefig(self.outputFilename + ".plot.unreduced.pdf", bbox_inches='tight')


class BAR_rfa:
    def __init__(self, U1_U1_filename, U1_U2_filename, U2_U1_filename, U2_U2_filename, delta_F_min=-100, delta_F_max=100, outputFilename="bar.out", iteration_max=1000, temp=300, C_absolute_tolerance=0.001):
        # The first potential is always the sampling potential, the second one is the evaluating potential.

        # Reading in the values of the input files into lists
        filenames = [U1_U1_filename, U1_U2_filename, U2_U1_filename, U2_U2_filename]
        # value_types = ["U1_U1_values", "U1_U2_values", "U2_U1_values", "U2_U2_values", "C_values"]
        self.values = dict.fromkeys(filenames)
        for filename in filenames:
            self.values[filename] = np.loadtxt(filename)

        # Variables
        self.U1_U1_filename = U1_U1_filename
        self.U1_U2_filename = U1_U2_filename
        self.U2_U1_filename = U2_U1_filename
        self.U2_U2_filename = U2_U2_filename
        self.C_values_final = None
        self.delta_F_1_final = None
        self.delta_F_2_final = None
        self.temp = float(temp)  # Kelvin
        # self.energyFactor = 627.509469           # hartree -> kcal/mol    # https://en.wikipedia.org/wiki/Hartree
        self.energyFactor = 1
        self.k_b = 0.0019872041  # in kcal/(mol*K)
        self.beta = 1. / (self.k_b * self.temp)
        self.plt = None
        self.outputFilename = outputFilename
        self.iteration_max = int(iteration_max)
        self.delta_F_min = float(delta_F_min)
        self.delta_F_max = float(delta_F_max)
        self.C_absolute_tolerance = float(C_absolute_tolerance)
        self.n_1 = 0
        self.n_2 = 0

    def compute_bar(self):

        # Checking if the number of values provided are the same for each pair
        if len(self.values[self.U1_U1_filename]) == len(self.values[self.U1_U2_filename]):
            self.n_1 = len(self.values[
                          self.U1_U1_filename])  # The number of snapshots from the sampling wrt to U1 -> coordinates of U1 MD
        else:
            errorMessage = "Error: The files " + self.U1_U1_filename + " and " + self.U1_U2_filename + " contain an unequal number of values."
            raise TypeError(errorMessage)
        if len(self.values[self.U2_U1_filename]) == len(self.values[self.U2_U2_filename]):
            self.n_2 = len(self.values[
                          self.U2_U2_filename])  # The number of snapshots from the sampling wrt to U2 -> coordinates of U2 MD
        else:
            errorMessage = "Error: The files " + self.U2_U1_filename + " and " + self.U2_U2_filename + " contain an unequal number of values."
            raise TypeError(errorMessage)

        print self.n_1
        self.C_min = self.beta * self.delta_F_min + math.log(self.n_2 / self.n_1) # Delta F = k_b*T*(C-ln(n_2/n_1)) <=> C=beta*DeltaF+ln(n_2/n_1)
        self.C_max = self.beta * self.delta_F_max + math.log(self.n_2 / self.n_1)
        # Solving the two BAR equations selfconsistently via the bisection method
        print
        print " * Starting to solve the two BAR equations selfconsistently via the bisection method"
        self.C_opt = spo.bisect(self.BAR_difference, self.C_min, self.C_max, maxiter=self.iteration_max)

        # Computing the results
        self.delta_F_1_final = self.compute_BAR_equation_1(self.C_opt)
        self.delta_F_2_final = self.compute_BAR_equation_2(self.C_opt)

        print
        print "                           BAR Summary"
        print "****************************************************************"
        print "delta_F_min (input parameter): ", self.delta_F_min
        print "delta_F_max (input parameter): ", self.delta_F_max
        print "Absolute tolerance w.r.t. C:", self.C_absolute_tolerance
        print "C_min: ", self.C_min
        print "C_max: ", self.C_max
        print "Temperature [K]: ", self.temp
        print "Optimal value of C: ", self.C_opt
        print "Delta_F equation 1: ", self.delta_F_1_final, " kcal/mol"
        print "Delta_F equation 2: ", self.delta_F_2_final, " kcal/mol"


    def compute_BAR_equation_1(self, C):

        # First BAR equation
        sum_1 = 0
        sum_2 = 0
        for i in range(0, self.n_2):
            sum_2 += fermi_function(self.beta * self.energyFactor * (
            self.values[self.U2_U1_filename][i] - self.values[self.U2_U2_filename][i]) + C)
        for i in range(0, self.n_1):
            sum_1 += fermi_function(self.beta * self.energyFactor * (
            self.values[self.U1_U2_filename][i] - self.values[self.U1_U1_filename][i]) - C)

        # If sum_2 is 0 we cannot use it... -> math error
        if sum_2 == 0:
            print("Warning: sum_2 is zero. Skipping this C-value...")
            return np.nan

        # self.delta_F_1_reduced.append(math.log(sum_2 / sum_1) + C - math.log(n_2 / n_1))
        delta_F_1 = ((self.k_b * self.temp) * (math.log(sum_2 / sum_1) + C - math.log(self.n_2 / self.n_1)))  # https://en.wikipedia.org/wiki/Boltzmann_constant
        return delta_F_1


    def compute_BAR_equation_2(self, C):
        delta_F_2 = (self.k_b * self.temp) * (C - math.log(self.n_2 / self.n_1))
        return delta_F_2


    def BAR_difference(self, C):
        delta_F_1_minus_DeltaF_2 = self.compute_BAR_equation_1(C) - self.compute_BAR_equation_2(C)
        return delta_F_1_minus_DeltaF_2


    def write_results(self):

        with open(self.outputFilename + ".values", "w") as file:
            file.write("Min (Delta F_eqn1 - F_eqn2) found at location C=" + str(self.C_opt) + "\n")
            file.write("Delta_F equation 1: " + str(self.delta_F_1_final) + " kcal/mol" + "\n")
            file.write("Delta_F equation 2: " + str(self.delta_F_2_final) + " kcal/mol" + "\n")



class BAR_DeltaU_rfa:
    def __init__(self, U1_U2_minus_U1_U1_filename, U2_U1_minus_U2_U2_filename, delta_F_min=-100, delta_F_max=100, outputFilename="bar.out", iteration_max=1000, temp=300, C_absolute_tolerance=0.001):
        # The first potential is always the sampling potential, the second one is the evaluating potential.

        # Reading in the values of the input files into lists
        filenames = [U1_U2_minus_U1_U1_filename, U2_U1_minus_U2_U2_filename]
        # value_types = ["U1_U1_values", "U1_U2_values", "U2_U1_values", "U2_U2_values", "C_values"]
        self.values = dict.fromkeys(filenames)
        for filename in filenames:
            self.values[filename] = np.loadtxt(filename)

        # Variables
        self.U1_U2_minus_U1_U1_filename = U1_U2_minus_U1_U1_filename
        self.U2_U1_minus_U2_U2_filename = U2_U1_minus_U2_U2_filename
        self.C_values_final = None
        self.delta_F_1_final = None
        self.delta_F_2_final = None
        self.temp = float(temp)  # Kelvin
        # self.energyFactor = 627.509469           # hartree -> kcal/mol    # https://en.wikipedia.org/wiki/Hartree
        self.energyFactor = 1
        self.k_b = 0.0019872041  # in kcal/(mol*K)
        self.beta = 1. / (self.k_b * self.temp)
        self.plt = None
        self.outputFilename = outputFilename
        self.iteration_max = int(iteration_max)
        self.delta_F_min = float(delta_F_min)
        self.delta_F_max = float(delta_F_max)
        self.C_absolute_tolerance = float(C_absolute_tolerance)

    def compute_bar(self):

        # Basics
        self.n_1 = len(self.values[self.U1_U2_minus_U1_U1_filename])
        self.n_2 = len(self.values[self.U2_U1_minus_U2_U2_filename])  # The number of snapshots from the sampling wrt to U2 -> coordinates of U2 MD
        self.C_min = self.beta * self.delta_F_min + math.log(self.n_2 / self.n_1) # Delta F = k_b*T*(C-ln(n_2/n_1)) <=> C=beta*DeltaF+ln(n_2/n_1)
        self.C_max = self.beta * self.delta_F_max + math.log(self.n_2 / self.n_1)
        # Solving the two BAR equations selfconsistently via the bisection method
        print
        print " * Starting to solve the two BAR equations selfconsistently via the bisection method"
        self.C_opt = spo.bisect(self.BAR_difference, self.C_min, self.C_max, maxiter=self.iteration_max)

        # Computing the results
        self.delta_F_1_final = self.compute_BAR_equation_1(self.C_opt)
        self.delta_F_2_final = self.compute_BAR_equation_2(self.C_opt)

        print
        print "                           BAR Summary"
        print "****************************************************************"
        print "delta_F_min (input parameter): ", self.delta_F_min
        print "delta_F_max (input parameter): ", self.delta_F_max
        print "Absolute tolerance w.r.t. C:", self.C_absolute_tolerance
        print "C_min: ", self.C_min
        print "C_max: ", self.C_max
        print "Temperature [K]: ", self.temp
        print "Optimal value of C: ", self.C_opt
        print "Delta_F equation 1: ", self.delta_F_1_final, " kcal/mol"
        print "Delta_F equation 2: ", self.delta_F_2_final, " kcal/mol"


    def compute_BAR_equation_1(self, C):

        # First BAR equation
        sum_1 = 0
        sum_2 = 0
        for i in range(0, self.n_2):
            sum_2 += fermi_function(
                self.beta * self.energyFactor * (self.values[self.U2_U1_minus_U2_U2_filename][i]) + C)

        for i in range(0, self.n_1):
            sum_1 += fermi_function(
                self.beta * self.energyFactor * (self.values[self.U1_U2_minus_U1_U1_filename][i]) - C)

        # If sum_2 is 0 we cannot use it... -> math error
        if sum_2 == 0:
            print("Warning: sum_2 is zero. Skipping this C-value...")
            return np.nan

        # self.delta_F_1_reduced.append(math.log(sum_2 / sum_1) + C - math.log(n_2 / n_1))
        delta_F_1 = ((self.k_b * self.temp) * (math.log(sum_2 / sum_1) + C - math.log(self.n_2 / self.n_1)))  # https://en.wikipedia.org/wiki/Boltzmann_constant
        return delta_F_1


    def compute_BAR_equation_2(self, C):
        delta_F_2 = (self.k_b * self.temp) * (C - math.log(self.n_2 / self.n_1))
        return delta_F_2


    def BAR_difference(self, C):
        delta_F_1_minus_DeltaF_2 = self.compute_BAR_equation_1(C) - self.compute_BAR_equation_2(C)
        return delta_F_1_minus_DeltaF_2


    def write_results(self):

        with open(self.outputFilename + ".values", "w") as file:
            file.write("Min (Delta F_eqn1 - F_eqn2) found at location C=" + str(self.C_opt) + "\n")
            file.write("Delta_F equation 1: " + str(self.delta_F_1_final) + " kcal/mol" + "\n")
            file.write("Delta_F equation 2: " + str(self.delta_F_2_final) + " kcal/mol" + "\n")