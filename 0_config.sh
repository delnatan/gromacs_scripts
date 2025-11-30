#!/bin/bash
# dont create backup parameter files (these would clutter the directory)
export GMX_MAXBACKUP=-1

# --- INPUT & OUTPUT FILES ---
# The name of your input PDB file (without extension)
PDB_NAME="Ndj1_27-352"

# organize output & script folders
RESULTS_DIR="results"
WORKDIR="work_files"
mkdir -p $RESULTS_DIR
mkdir -p $WORKDIR

# --- EXECUTABLE SETTINGS --- 
GMX="gmx_mpi"       # Executable name
MPI_CMD=""          # MPI Runner (Leave empty if on workstation)
GPU_FLAGS="-nb gpu" # run on GPU 


# --- SIMULATION PARAMETERS ---
TEMP=310.15           # kelvin (-273.15 to celcius)
SALT_CONC=0.15        # in mol/liter, 0.15 is 'physiological'
                      # Production Simulation time in Nanoseconds
NVT_TIME_PS=100
NPT_TIME_PS=500
SIM_TIME_NS=10        # change this to production length
DT=0.002              # standard 2 fs step size, picosecond unit

FF="charmm36-jul2022" # install from https://mackerell.umaryland.edu/charmm_ff.shtml
WATER="tip3p"         # standard water model for CHARMM36
BOX_TYPE="dodecahedron"

