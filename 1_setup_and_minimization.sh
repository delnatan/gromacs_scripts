#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 1: SETUP AND MINIMIZATION <<<"

# Ensure clean work state
mkdir -p $WORKDIR

# ==========================================
# 1. Topology Generation
# ==========================================
echo "--> Generating topology (Forcefield: $FF, Water: $WATER)..."

# temporarily disable 'exit on error'
set +e

# ATTEMPT 1: Try Automatic (Quiet)
# [FIX]: Removed '-i' to allow auto-naming of posre files for multiple chains
$GMX pdb2gmx -f ${PDB_NAME}.pdb \
    -o $WORKDIR/processed.gro \
    -p $WORKDIR/topol.top \
    -water $WATER -ff $FF -ignh \
    > pdb2gmx_attempt1.log 2>&1

EXIT_CODE=$?
set -e # Re-enable exit-on-error

if [ $EXIT_CODE -eq 0 ]; then
    echo ">> Standard pdb2gmx setup successful (Defaults accepted)."
    rm pdb2gmx_attempt1.log
else
    echo ">> Default setup failed (likely ambiguous termini)."
    echo ">> Attempting interactive setup with pre-filled inputs..."

    # ATTEMPT 2: Manual Fallback
    # [CRITICAL UPDATE]: We send "1\n0" four times. 
    # This covers up to 4 chains (Dimer = 4 inputs, Trimer = 6 inputs).
    # GROMACS stops reading when it's done, so providing 'extra' inputs is safe.
    # 1 = N-terminus choice (User preference)
    # 0 = C-terminus choice (User preference)
    
    printf "1\n0\n1\n0\n1\n0\n1\n0\n" | $GMX pdb2gmx -f ${PDB_NAME}.pdb \
        -o $WORKDIR/processed.gro \
        -p $WORKDIR/topol.top \
        -water $WATER -ff $FF -ignh \
        -ter 
        
    echo ">> Interactive pdb2gmx setup complete."
fi

# [FIX]: Strip absolute paths from the topology include lines
# This handles the fact that we removed '-i' and GROMACS named the files itself
sed -i "s|$WORKDIR/||g" $WORKDIR/topol.top

# move ITP files to work directory
mv *.itp $WORKDIR/

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
