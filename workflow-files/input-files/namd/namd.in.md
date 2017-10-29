#############################################################
## JOB DESCRIPTION                                         ##
#############################################################

# Minimization and MD Simulation

#############################################################
## ADJUSTABLE PARAMETERS                                   ##
#############################################################

# Input files
structure          ../../system1.psf
coordinates        ../../system1.pdb

# Continuation of previous simulation
#bincoordinates     filename.coor
#binvelocities      filename.vel
#extendedSystem     filename.xsc

set temperature    300
set outputname     namd.out
firsttimestep 0 

#############################################################
## SIMULATION PARAMETERS                                   ##
#############################################################

# Input
paraTypeCharmm	    on
parameters          ../../system1.prm


# Force-Field Parameters
exclude             scaled1-4
1-4scaling          1.0
cutoff              12.0
switching           on
switchdist          10.0
pairlistdist        14.0


# Integrator Parameters
timestep            2.0  ;# 2fs/step
rigidBonds          all  ;# needed for 2fs steps
nonbondedFreq       1
fullElectFrequency  2
stepspercycle       10


# Constant Temperature Control
temperature         $temperature
langevin            on    ;# do langevin dynamics
langevinDamping     1     ;# damping coefficient (gamma) of 1/ps
langevinTemp        $temperature
langevinHydrogen    off    ;# dont couple langevin bath to hydrogens


# Periodic Boundary Conditions
cellBasisVector1 61.143 0 0
cellBasisVector2 0 66.135 0
cellBasisVector3 0 0 68.876
cellOrigin          0 0 0 
wrapAll             on


# PME (for full-system periodic electrostatics)
PME                 yes
PMEGridSpacing      1.0

#manual grid definition
#PMEGridSizeX        45
#PMEGridSizeY        45
#PMEGridSizeZ        48


# Constant Pressure Control (variable volume)
useGroupPressure      yes ;# needed for rigidBonds
useFlexibleCell       no
useConstantArea       no
margin                5


# Output
outputName          $outputname

restartfreq         10000     ;# 500steps = every 1ps
dcdfreq             10000
xstFreq             10000
outputEnergies      10000
outputPressure      10000


#############################################################
## EXTRA PARAMETERS                                        ##
#############################################################


#############################################################
## EXECUTION SCRIPT                                        ##
#############################################################

# Minimization
minimize            10000

# Heating up
#langevinPiston      off
#reassignTemp        0          ;# initial temperature
#reassignIncr        5          ;# increase temperature by this value at each reassignment step
#reassignFreq        1000       ;# Reassign the temperature after so many steps
#reassignHold        310        ;# target temperature
#run                 100000     ;# 200 ps

# Equillibration & Production
langevinPiston        on
langevinPistonTarget  1.01325 ;#  in bar -> 1 atm
langevinPistonPeriod  100.0
langevinPistonDecay   50.0
langevinPistonTemp    $temperature
run                   500000000     ;# 1000 ns
