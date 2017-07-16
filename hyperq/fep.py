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
import numpy

class FEP:
    
    def __init__(self, U1_U1_filename, U1_U2_filename, temp):
        # The first potential is always the sampling potential, the second one is the evaluating potential.\n\n

        # Reading in the values of the input files into lists
        filenames = [U1_U1_filename, U1_U2_filename]
        self.values = dict.fromkeys(filenames)
        for filename in filenames:
            self.values[filename] = np.loadtxt(filename)
    
        # Variables 
        self.U1_U1_filename = U1_U1_filename
        self.U1_U2_filename = U1_U2_filename
        self.delta_F = []
        self.temp = float(temp)  # Kelvin
        # self.energyFactor = 627.509469           # hartree -> kcal/mole    # https://en.wikipedia.org/wiki/Hartree
        # self.energyFactor = 1
        self.k_b = 0.0019872041  # in kcal/(mol*K)

    def compute_fep(self):
        # Loop for each C-value

        # Variables
        sum_1 = 0

        # Checking if the number of values provided are the same for each pair
        if len(self.values[self.U1_U1_filename]) == len(self.values[self.U1_U2_filename]):
            n_1 = len(self.values[self.U1_U1_filename])  # The number of snapshots from the sampling wrt to U1 -> coordinates of U1 MD
        else:
            errorMessage="Error: The files " + self.U1_U1_filename + " and " + self.U1_U2_filename + " contain an unequal number of values."
            raise TypeError(errorMessage)
        for i in range(0, n_1 - 1):
            sum_1 += math.exp(-(self.values[self.U1_U2_filename][i] - self.values[self.U1_U1_filename][i])/(self.k_b*self.temp))

        self.delta_F = -self.k_b * self.temp * numpy.log(sum_1/n_1)

        # Printing some information
        return self.delta_F