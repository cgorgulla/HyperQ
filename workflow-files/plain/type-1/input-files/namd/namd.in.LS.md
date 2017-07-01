#############################################################
## JOB DESCRIPTION                                         ##
#############################################################

# Minimization and MD Simulation of 
# Ebp1 in a Water Box


#############################################################
## ADJUSTABLE PARAMETERS                                   ##
#############################################################
# Names
set inputname1  merged_wb_ion
#set inputname2  ${inputname1}_md1

# Input files
structure          ../common/charmm36/${inputname1}.psf
coordinates        ../common/charmm36/${inputname1}.pdb

# Continuation of previous simulation
#bincoordinates     ${inputname2}.coor
#binvelocities      ${inputname2}.vel
#extendedSystem     ${inputname2}.xsc

set temperature    310
set outputname     namd.out


#############################################################
## SIMULATION PARAMETERS                                   ##
#############################################################

# Input
paraTypeCharmm	    on
parameters          ../common/charmm36/par_all36_prot.prm
parameters          ../common/charmm36/toppar_water_ions_namd.str
# parameters          ../common/charmm36/par_all36_na.prm
parameters          ../common/charmm36/par_all36_lipid.prm
parameters          ../common/charmm36/par_all36_carb.prm
# parameters          ../common/charmm36/par_all35_ethers.prm
parameters          ../common/charmm36/par_all36_cgenff.prm


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
langevinHydrogen    off    ;# don't couple langevin bath to hydrogens


# Periodic Boundary Conditions
cellBasisVector1    108.449996948    0.0   0.0
cellBasisVector2     0.0  119.998001099   0.0
cellBasisVector3     0.0    0   105.065998077
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

langevinPiston        on
langevinPistonTarget  1.01325 ;#  in bar -> 1 atm
langevinPistonPeriod  100.0
langevinPistonDecay   50.0
langevinPistonTemp    $temperature


# Output
outputName          $outputname

restartfreq         500     ;# 500steps = every 1ps
dcdfreq             250
xstFreq             250
outputEnergies      100
outputPressure      100


#############################################################
## EXTRA PARAMETERS                                        ##
#############################################################


#############################################################
## EXECUTION SCRIPT                                        ##
#############################################################

# Minimization
# minimize            10000

# MD Simulationi
run     5000000     ;# 10 ns


