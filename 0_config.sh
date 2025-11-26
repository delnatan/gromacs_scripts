#!/bin/bash
export GMX_MAXBACKUP=-1

# --- INPUT & OUTPUT FILES ---
# The name of your input PDB file (without extension)
PDB_NAME="Ndj1_27-352"

# organize output & script folders
RESULTS_DIR="results"
SCRIPTS_DIR="scripts"
mkdir -p $RESULTS_DIR
mkdir -p $SCRIPTS_DIR

# --- EXECUTABLE --- 
# Executable name
GMX="gmx_mpi"

# MPI Runner (Leave empty if on workstation)
MPI_CMD=""

# GPU Settings
GPU_FLAGS="-nb gpu"


# --- SIMULATION PARAMETERS ---
# Temperature in Kelvin
TEMP=310

# Salt concentration in mol/liter (M)
# 0.15 is physiological (150mM).
SALT_CONC=0.15

# Production Simulation time in Nanoseconds
NVT_TIME_PS=100
NPT_TIME_PS=500
SIM_TIME_NS=200

# --- GROMACS SETTINGS ---
# Forcefield
# The PDF likely uses "charmm36" or "charmm36-jul2022".
# NOTE: If 'pdb2gmx' fails saying it can't find this, you may need to 
# download the charmm36.ff folder and place it in your working directory.
FF="charmm36-jul2022"

# Water Model
# CHARMM36 is typically parameterized for use with TIP3P water.
WATER="tip3p"

# Box Shape
# 'dodecahedron' is ~30% faster than 'cubic' because it uses less water
# to maintain the same periodic distance.
BOX_TYPE="dodecahedron"

