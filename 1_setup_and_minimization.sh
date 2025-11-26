#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 1: SETUP AND MINIMIZATION <<<"

# 1. Topology
echo "--> Generating topology..."
$GMX pdb2gmx -f ${PDB_NAME}.pdb -o ${PDB_NAME}_processed.gro -water $WATER -ff $FF -ignh

# 2. Box
echo "--> Defining box..."
$GMX editconf -f ${PDB_NAME}_processed.gro -o ${PDB_NAME}_newbox.gro -c -d 1.0 -bt $BOX_TYPE

# 3. Solvate
echo "--> Solvating..."
$GMX solvate -cp ${PDB_NAME}_newbox.gro -cs spc216.gro -o ${PDB_NAME}_solv.gro -p topol.top

# 4. Ions
echo "--> Adding ions..."
$GMX grompp -f params/ions.mdp -c ${PDB_NAME}_solv.gro -p topol.top -o ions.tpr
echo "SOL" | $GMX genion -s ions.tpr -o ${PDB_NAME}_solv_ions.gro -p topol.top -pname NA -nname CL -neutral -conc $SALT_CONC

# 5. Minimization
echo "--> Running Energy Minimization..."
$GMX grompp -f params/minim.mdp -c ${PDB_NAME}_solv_ions.gro -p topol.top -o em.tpr
$MPI_CMD $GMX mdrun -v -deffnm em $GPU_FLAGS

# ==========================================
# ANALYSIS: POTENTIAL ENERGY
# ==========================================
if [ -f "em.edr" ]; then
    echo "--> Analyzing Minimization Results..."
    
    # 1. Extract Data (10=Potential in standard GMX map, but we use echo string for safety)
    # The output goes into the results folder
    { echo "Potential"; echo "0"; } | $GMX energy -f em.edr -o $RESULTS_DIR/potential.xvg

    # 2. Plot Data using the generic script
    # Usage: input output "Title" "X" "Y" Column
    gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
        "$RESULTS_DIR/potential.xvg" \
        "$RESULTS_DIR/1_potential.png" \
        "Energy Minimization" \
        "Steps" \
        "Potential (kJ/mol)" \
        2 \
        0

    echo "--> Plot saved to $RESULTS_DIR/1_potential.png"
else
    echo "!! ERROR: Minimization failed (em.edr not found)."
    exit 1
fi
