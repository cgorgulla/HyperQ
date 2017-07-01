&GLOBAL
  PROJECT system
  RUN_TYPE geo_opt
  PRINT_LEVEL low
&END global

&MOTION
  &GEO_OPT
    MAX_ITER 100
    OPTIMIZER lbfgs
  &END GEO_OPT
  &MD
    ENSEMBLE langevin
    &LANGEVIN 
      GAMMA [fs^-1] 1.0E-3                        # "Langevin" gamma (adapt for your system) 
      NOISY_GAMMA [fs^-1] 3.0E-5                  # dissipative gamma (adapt for your system) 
    &END LANGEVIN
    STEPS 5000000
    TIMESTEP 0.5
    TEMPERATURE 300.0
    &THERMOSTAT
#      &NOSE
#        LENGTH 3
#        YOSHIDA 3
#        TIMECON [wavenumber_t] 2000
#        MTS 2
#      &END NOSE
      REGION global
      TYPE csvr
      &CSVR
        TIMECON 1
      &END CSVR      
      &PRINT
        &TEMPERATURE on
          FILENAME =cp2k.out.temperature
          &EACH
            MD 10
          &END EACH
        &END TEMPERATURE
      &END PRINT
    &END THERMOSTAT
#    &BAROSTAT
#      PRESSURE 1.0
#      TIMECON 100
#    &END BAROSTAT    
    &PRINT
      &ENERGY
        FILENAME =cp2k.out.energy
          &EACH
            MD 10
          &END EACH
      &END ENERGY
    &END PRINT   
  &END MD  
  &PRINT
    &TRAJECTORY on
      FORMAT pdb
      FILENAME =cp2k.out.trajectory.pdb
      &EACH
        MD 10
        GEO_OPT 1
      &END EACH
    &END TRAJECTORY
    &RESTART on
      FILENAME =cp2k.out.restart
      &EACH
        MD 1000
      &END EACH
    &END RESTART
    &RESTART_HISTORY off
    &END RESTART_HISTORY
    &STRESS ON
      FILENAME =cp2k.out.pressure
      &EACH
        MD 10
      &END EACH
    &END STRESS
    &CELL on
      FILENAME =cp2k.out.cell
      &EACH
        MD 10
      &END EACH
    &END CELL
  &END PRINT
&END MOTION

&MULTIPLE_FORCE_EVALS
   FORCE_EVAL_ORDER 2 3 4 5
   MULTIPLE_SUBSYS true
&END

&FORCE_EVAL
  STRESS_TENSOR analytical
  METHOD mixed
  &MIXED
    MIXING_TYPE genmix
    &GENERIC
      # a: H1   : Hamiltonian of system 1
      # b: H2d  : Hamiltonian of system 2 dummies
      # c: H1d  : Hamiltonian of system 1 dummies
      # d: H2   : Hamltionian of system 2
      VARIABLES a b c d
      MIXING_FUNCTION (1-k_value)*(a+b)+k_value*(c+d)
    &END
    @include ../../cp2k.in.mapping.opt
  &END
  &SUBSYS
    &TOPOLOGY
      CONNECTIVITY off
      COORDINATE pdb
      COORD_FILE_NAME ../../system.a1c1.pdb
    &END TOPOLOGY
    &CELL
      ABC 58.558 60.576 42.820
    &END CELL
  &END SUBSYS
  &PRINT
    &FORCES off
      FILENAME =cp2k.out.forces.H_total
      COMMON_ITERATION_LEVELS 10000
      &EACH
        MD 100
      &END EACH
    &END FORCES
  &END PRINT
&END FORCE_EVAL

&FORCE_EVAL
  STRESS_TENSOR analytical
  METHOD fist
  &MM
    &FORCEFIELD
      IGNORE_MISSING_CRITICAL_PARAMS true
      PARM_FILE_NAME ../../system1.prm
      PARMTYPE chm
      &SPLINE
         EMAX_SPLINE 100000
         RCUT_NB 10.
      &END
    &END FORCEFIELD
    &NEIGHBOR_LISTS
      GEO_CHECK false
    &END NEIGHBOR_LISTS
    &POISSON
      &EWALD
        EWALD_TYPE spme
        ALPHA .44
        GMAX 36
        O_SPLINE 6
      &END EWALD
    &END POISSON
  &END MM
  &SUBSYS
    &CELL
      ABC 58.558 60.576 42.820
    &END CELL
    &TOPOLOGY
      COORDINATE pdb
      COORD_FILE_NAME ../../system1.pdb
      CONN_FILE_FORMAT psf
      CONN_FILE_NAME ../../system1.psf
    &END TOPOLOGY
    @include ../../cp2k.in.kind.1
    @include ../../cp2k.in.kind.2
    @include ../../cp2k.in.kind.3
  &END SUBSYS
  &PRINT
    &FORCES off
      FILENAME =cp2k.out.forces.H1
      COMMON_ITERATION_LEVELS 10000
      &EACH
        MD 100
      &END EACH
    &END FORCES
  &END PRINT
&END FORCE_EVAL

&FORCE_EVAL
  STRESS_TENSOR analytical
  METHOD FIST
  &MM
    &NEIGHBOR_LISTS
      GEO_CHECK false
    &END NEIGHBOR_LISTS
    &FORCEFIELD
      IGNORE_MISSING_CRITICAL_PARAMS true
      &SPLINE
        EMAX_SPLINE 100000000.0
      &END
      &NONBONDED
        @include ../../cp2k.in.LJ.system2
      &END NONBONDED
      @include ../../cp2k.in.bonds.system2
      @include ../../cp2k.in.angles.system2
      @include ../../cp2k.in.dihedrals.system2
    &END FORCEFIELD
    &POISSON
      &EWALD
        EWALD_TYPE spme
        ALPHA .5
        GMAX 36
        O_SPLINE 6
      &END EWALD
    &END POISSON
  &END MM
  &SUBSYS
    &TOPOLOGY
      COORDINATE pdb
      COORD_FILE_NAME ../../system2.pdb
      CONN_FILE_FORMAT psf
      CONN_FILE_NAME ../../system2.dummy.psf      
      &GENERATE 
        BONDLENGTH_MAX 10000
      &END GENERATE
    &END TOPOLOGY
    &CELL
      ABC 58.558 60.576 42.820
    &END CELL
  &END SUBSYS
  &PRINT
    &FORCES off
      FILENAME =cp2k.out.forces.H2d
      COMMON_ITERATION_LEVELS 10000
      &EACH
        MD 100
      &END EACH
    &END FORCES
  &END PRINT
&END FORCE_EVAL

&FORCE_EVAL
  STRESS_TENSOR analytical
  METHOD FIST
  &MM
    &NEIGHBOR_LISTS
      GEO_CHECK false
    &END NEIGHBOR_LISTS
    &FORCEFIELD
      IGNORE_MISSING_CRITICAL_PARAMS true
      &SPLINE
        EMAX_SPLINE 100000000.0
      &END
      &NONBONDED
        @include ../../cp2k.in.LJ.system1
      &END NONBONDED
      @include ../../cp2k.in.bonds.system1
      @include ../../cp2k.in.angles.system1
      @include ../../cp2k.in.dihedrals.system1
    &END FORCEFIELD
    &POISSON
      &EWALD
        EWALD_TYPE spme
        ALPHA .5
        GMAX 36
        O_SPLINE 6
      &END EWALD
    &END POISSON
  &END MM
  &SUBSYS
    &TOPOLOGY
      COORDINATE pdb
      COORD_FILE_NAME ../../system1.pdb
      CONN_FILE_FORMAT psf
      CONN_FILE_NAME ../../system1.dummy.psf      
      &GENERATE 
        BONDLENGTH_MAX 10000
      &END GENERATE
    &END TOPOLOGY
    &CELL
      ABC 58.558 60.576 42.820
    &END CELL
  &END SUBSYS
  &PRINT
    &FORCES off
      FILENAME =cp2k.out.forces.H1d
      COMMON_ITERATION_LEVELS 10000
      &EACH
        MD 100
      &END EACH
    &END FORCES
  &END PRINT
&END FORCE_EVAL

&FORCE_EVAL
  STRESS_TENSOR analytical
  METHOD fist
  &MM
    &FORCEFIELD
      IGNORE_MISSING_CRITICAL_PARAMS true
      PARM_FILE_NAME ../../system2.prm
      PARMTYPE chm
      &SPLINE
         EMAX_SPLINE 100000
         RCUT_NB 10.
      &END
    &END FORCEFIELD
    
    &NEIGHBOR_LISTS
      GEO_CHECK false
    &END NEIGHBOR_LISTS
    &POISSON
      &EWALD
        EWALD_TYPE spme
        ALPHA .44
        GMAX 36
        O_SPLINE 6
      &END EWALD
    &END POISSON
  &END MM
  &SUBSYS
    &CELL
      ABC 58.558 60.576 42.820
    &END CELL
    &TOPOLOGY
      COORDINATE pdb
      COORD_FILE_NAME ../../system2.pdb
      CONN_FILE_FORMAT psf
      CONN_FILE_NAME ../../system2.psf
    &END TOPOLOGY
    @include ../../cp2k.in.kind.1
    @include ../../cp2k.in.kind.2
    @include ../../cp2k.in.kind.3
  &END SUBSYS
  &PRINT
    &FORCES off
      FILENAME =cp2k.out.forces.H2
      COMMON_ITERATION_LEVELS 10000
      &EACH
        MD 100
      &END EACH
    &END FORCES
  &END PRINT
&END FORCE_EVAL
