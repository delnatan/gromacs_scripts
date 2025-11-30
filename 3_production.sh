#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 3: PRODUCTION MD <<<"

# Define paths to keep main folder clean
MD_MDP="$WORKDIR/md.mdp"
TPR_FILE="$WORKDIR/md_0_1.tpr"
CPT_FILE="$WORKDIR/md_0_1.cpt"
TRAJ_FILE="$WORKDIR/md_0_1.xtc"

# ==========================================
# 1. Prepare Parameters (Template Strategy)
# ==========================================
# Calculate total duration in ps and steps
TOTAL_PS=$(echo "$SIM_TIME_NS * 1000" | bc)
NSTEPS=$(echo "$TOTAL_PS / $DT" | bc)

echo "--> Configuration: Target time is $SIM_TIME_NS ns ($TOTAL_PS ps)"

# Generate the MD parameter file from template
# We use the config variables to fill in the blanks
sed -e "s/REPLACEME_TEMP/$TEMP/g" \
    -e "s/REPLACEME_STEPS/$NSTEPS/g" \
    -e "s/REPLACEME_DT/$DT/g" \
    params/md.mdp.template > $MD_MDP

# ==========================================
# 2. Prepare Run Input (.tpr)
# ==========================================
if [ ! -f "$TPR_FILE" ]; then
    # CASE A: New Simulation
    echo "--> No existing run found. Assembling new binary input (tpr)..."
    
    # Check if NPT finished
    if [ ! -f "$WORKDIR/npt.gro" ]; then
        echo "!! ERROR: NPT output ($WORKDIR/npt.gro) not found. Did Step 2 finish?"
        exit 1
    fi

    # Create the run file
    $GMX grompp -f $MD_MDP \
        -c $WORKDIR/npt.gro \
        -t $WORKDIR/npt.cpt \
        -p $WORKDIR/topol.top \
        -o $TPR_FILE
else
    # CASE B: Extending Existing Simulation
    echo "--> Existing run found. Ensuring it extends to $SIM_TIME_NS ns..."
    
    # 'convert-tpr' extends the run time inside the binary file
    # If the file is already 50ns and you request 50ns, this does nothing.
    $GMX convert-tpr -s $TPR_FILE -until $TOTAL_PS -o $TPR_FILE
fi

# ==========================================
# 3. Execution (Smart Resume)
# ==========================================
CPI_FLAGS=""
if [ -f "$CPT_FILE" ]; then
    echo "--> Checkpoint found. Resuming from last saved step..."
    CPI_FLAGS="-cpi $CPT_FILE -append"
fi

echo "--> Running Production MD..."
# -deffnm sets the default filename for all outputs (log, edr, xtc, trr)
# We point this to $WORKDIR/md_0_1 to keep root clean
$MPI_CMD $GMX mdrun -v -deffnm $WORKDIR/md_0_1 $GPU_FLAGS $CPI_FLAGS


# ==========================================
# 4. Analysis (RMSD)
# ==========================================
if [ -f "$TRAJ_FILE" ]; then
    echo "--> Analyzing Backbone RMSD..."
    
    # RMSD: Group 4 (Backbone) for fit, Group 4 for calculation
    # We use 'echo' to select the groups automatically
    { echo "4"; echo "4"; } | $GMX rms -s $TPR_FILE -f $TRAJ_FILE -o $RESULTS_DIR/rmsd.xvg -tu ns
    
    # Inline Gnuplot
    gnuplot <<-EOF
        set terminal pngcairo size 800,600 enhanced font 'Arial,12'
        set output "$RESULTS_DIR/4_rmsd.png"
        set title "Backbone RMSD ($SIM_TIME_NS ns)"
        set xlabel "Time (ns)"
        set ylabel "RMSD (nm)"
        set grid
        
        # Plot column 1 (time) vs 2 (RMSD)
        plot "$RESULTS_DIR/rmsd.xvg" using 1:2 with lines lc rgb "dark-blue" title "Backbone"
EOF

    echo "--> Plot saved to $RESULTS_DIR/4_rmsd.png"
else
    echo "!! ERROR: Simulation did not produce a trajectory file."
    exit 1
fi
