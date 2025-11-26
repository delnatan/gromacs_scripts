#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 3: PRODUCTION MD <<<"

MDP_FILE="params/md.mdp"
TPR_FILE="md_0_1.tpr"
CPT_FILE="md_0_1.cpt"

# 1. Update Temperature in MDP (just in case)
sed -i "s/ref_t.*=.*/ref_t                   = $TEMP/" $MDP_FILE

# 2. Calculate Total Target Time (ps)
DT=$(grep "dt" $MDP_FILE | awk '{print $3}' | sed 's/;//')
if [ -z "$DT" ]; then DT=0.002; fi

TOTAL_PS=$(echo "$SIM_TIME_NS * 1000" | bc)
NSTEPS=$(echo "$TOTAL_PS / $DT" | bc)

echo "--> Target Simulation Time: $SIM_TIME_NS ns ($TOTAL_PS ps)"

# 3. Prepare the TPR File
if [ ! -f "$TPR_FILE" ]; then
    # CASE A: New Simulation
    echo "--> No existing run found. Preparing new run..."
    
    # Update steps in mdp
    sed -i "s/nsteps.*=.*/nsteps                  = $NSTEPS/" $MDP_FILE
    
    $GMX grompp -f $MDP_FILE -c npt.gro -t npt.cpt -p topol.top -o $TPR_FILE
else
    # CASE B: Extending Existing Simulation
    echo "--> Existing run found. Extending/Syncing to $SIM_TIME_NS ns..."
    
    # -until extends the run UNTIL absolute time $TOTAL_PS
    $GMX convert-tpr -s $TPR_FILE -until $TOTAL_PS -o $TPR_FILE
fi

# 4. Run (or Continue) Production MD
CPI_FLAGS=""
if [ -f "$CPT_FILE" ]; then
    echo "--> Checkpoint found. Resuming..."
    CPI_FLAGS="-cpi $CPT_FILE -append"
else
    echo "--> Starting from beginning..."
fi

echo "--> Running Production MD (verbose mode)..."
$MPI_CMD $GMX mdrun -v -deffnm md_0_1 $GPU_FLAGS $CPI_FLAGS

# 5. Analysis
if [ -f "md_0_1.xtc" ]; then
    echo "--> Analyzing RMSD..."
    
    # RMSD: Group 4 (Backbone) for fit, Group 4 for calculation
    { echo "4"; echo "4"; } | $GMX rms -s $TPR_FILE -f md_0_1.xtc -o $RESULTS_DIR/rmsd.xvg -tu ns
    
    gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
        "$RESULTS_DIR/rmsd.xvg" \
        "$RESULTS_DIR/4_rmsd.png" \
        "Backbone RMSD" \
        "Time (ns)" \
        "RMSD (nm)" \
        2 \
        0

    echo "--> Analyzing Gyration..."
    # Gyration: Group 1 (Protein)
    { echo "1"; } | $GMX gyrate -s $TPR_FILE -f md_0_1.xtc -o $RESULTS_DIR/gyrate.xvg
    
    gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
        "$RESULTS_DIR/gyrate.xvg" \
        "$RESULTS_DIR/4_gyrate.png" \
        "Radius of Gyration" \
        "Time (ps)" \
        "Rg (nm)" \
        2 \
        0

    echo "--> Plots saved to $RESULTS_DIR/"
fi

echo ">>> SIMULATION COMPLETE <<<"
