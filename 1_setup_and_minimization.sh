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

# Input: Root PDB ($PDB_NAME.pdb)
# Output: work_files/topol.top, work_files/processed.gro
$GMX pdb2gmx -f ${PDB_NAME}.pdb \
    -o $WORKDIR/processed.gro \
    -p $WORKDIR/topol.top \
    -i $WORKDIR/posre.itp \
    -water $WATER -ff $FF -ignh > pdb2gmx_attempt1.log 2>&1

# capture exit code
EXIT_CODE=$?

# re-enable 'exit on error'
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo ">> Standard pdb2gmx setup successful."
    rm pdb2gmx_attempt1.log
else
    echo ">> Choosing termini 'manually'"
    printf "1\n0\n" | $GMX pdb2gmx -f ${PDB_NAME}.pdb \
    -o $WORKDIR/processed.gro \
    -p $WORKDIR/topol.top \
    -i $WORKDIR/posre.itp \
    -water $WATER -ff $FF -ignh -ter
    echo ">> Interactive pdb2gmx setup complete."
fi

# ==========================================
# 2. Define Box
# ==========================================
echo "--> Defining $BOX_TYPE simulation box..."
$GMX editconf -f $WORKDIR/processed.gro \
    -o $WORKDIR/newbox.gro \
    -c -d 1.2 -bt $BOX_TYPE

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
        set
