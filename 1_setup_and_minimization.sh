#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 1: SETUP AND MINIMIZATION <<<"

# Ensure clean work state
mkdir -p $WORKDIR

# ==========================================
# 1. Topology Generation
# ==========================================
echo "--> Generating topology (Forcefield: $FF, Water: $WATER)..."

# Input: Root PDB ($PDB_NAME.pdb)
# Output: work_files/topol.top, work_files/processed.gro
$GMX pdb2gmx -f ${PDB_NAME}.pdb \
    -o $WORKDIR/processed.gro \
    -p $WORKDIR/topol.top \
    -i $WORKDIR/posre.itp \
    -water $WATER -ff $FF -ignh

# [FIX] pdb2gmx wrote "work_files/posre.itp" into the include line of topol.top.
# Since topol.top is ALREADY in work_files, this creates a double path error.
# We use sed to strip the directory prefix so it just looks for "posre.itp".
sed -i "s|$WORKDIR/posre.itp|posre.itp|g" $WORKDIR/topol.top

# ==========================================
# 2. Define Box
# ==========================================
echo "--> Defining $BOX_TYPE simulation box..."
$GMX editconf -f $WORKDIR/processed.gro \
    -o $WORKDIR/newbox.gro \
    -c -d 1.0 -bt $BOX_TYPE

# ==========================================
# 3. Solvate
# ==========================================
echo "--> Solvating system..."
$GMX solvate -cp $WORKDIR/newbox.gro \
    -cs spc216.gro \
    -o $WORKDIR/solvated.gro \
    -p $WORKDIR/topol.top

# ==========================================
# 4. Add Ions
# ==========================================
echo "--> Adding ions ($SALT_CONC M)..."

# We use the static ions.mdp from params/ directly (no templating needed usually)
$GMX grompp -f params/ions.mdp \
    -c $WORKDIR/solvated.gro \
    -p $WORKDIR/topol.top \
    -o $WORKDIR/ions.tpr

# Use echo to select "SOL" (Solvent) group for replacement
echo "SOL" | $GMX genion -s $WORKDIR/ions.tpr \
    -o $WORKDIR/solvated_ions.gro \
    -p $WORKDIR/topol.top \
    -pname NA -nname CL -neutral -conc $SALT_CONC

# ==========================================
# 5. Energy Minimization
# ==========================================
echo "--> Running Energy Minimization..."

# We use the static minim.mdp from params/
$GMX grompp -f params/minim.mdp \
    -c $WORKDIR/solvated_ions.gro \
    -p $WORKDIR/topol.top \
    -o $WORKDIR/em.tpr

$MPI_CMD $GMX mdrun -v -deffnm $WORKDIR/em $GPU_FLAGS

# ==========================================
# 6. Analysis (Potential Energy)
# ==========================================
if [ -f "$WORKDIR/em.edr" ]; then
    echo "--> Analyzing Minimization Results..."
    
    # Extract Potential Energy
    { echo "Potential"; echo "0"; } | $GMX energy -f $WORKDIR/em.edr -o $RESULTS_DIR/potential.xvg

    # Inline Gnuplot
    gnuplot <<-EOF
        set terminal pngcairo size 800,600 enhanced font 'Arial,12'
        set output "$RESULTS_DIR/1_potential_energy.png"
        set title "Energy Minimization"
        set xlabel "Steps"
        set ylabel "Potential Energy (kJ/mol)"
        set grid
        
        # Plot using column 1 (steps) and 2 (energy)
        plot "$RESULTS_DIR/potential.xvg" using 1:2 with lines lc rgb "black" title "Potential Energy"
EOF

    echo "--> Plot saved to $RESULTS_DIR/1_potential_energy.png"
else
    echo "!! ERROR: Minimization failed. Check $WORKDIR/em.log"
    exit 1
fi
