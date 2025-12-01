#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 2: EQUILIBRATION <<<"

# 1. Generate Parameters from Templates (Non-destructive)
# We calculate steps here using the DT defined in 0_config.sh
NVT_STEPS=$(echo "$NVT_TIME_PS / $DT" | bc)
NPT_STEPS=$(echo "$NPT_TIME_PS / $DT" | bc)

echo "--> Generating MDP files in $WORKDIR..."

# Create NVT mdp
sed -e "s/REPLACEME_TEMP/$TEMP/g" \
    -e "s/REPLACEME_STEPS/$NVT_STEPS/g" \
    -e "s/REPLACEME_DT/$DT/g" \
    params/nvt.mdp.template > $WORKDIR/nvt.mdp

# Create NPT mdp
sed -e "s/REPLACEME_TEMP/$TEMP/g" \
    -e "s/REPLACEME_STEPS/$NPT_STEPS/g" \
    -e "s/REPLACEME_DT/$DT/g" \
    params/npt.mdp.template > $WORKDIR/npt.mdp


# ==========================================
# PHASE 1: NVT (Temperature)
# ==========================================
echo "--> Running NVT Equilibration..."

# Define file paths
NVT_TPR="$WORKDIR/nvt.tpr"
NVT_OUT="$WORKDIR/nvt" # Base name for output
EM_GRO="$WORKDIR/em.gro" # Assumes step 1 put files in WORKDIR

# Check if input exists
if [ ! -f "$EM_GRO" ]; then
    echo "!! ERROR: $EM_GRO not found. Did you run Step 1?"
    exit 1
fi

$GMX grompp -f $WORKDIR/nvt.mdp \
     -c $EM_GRO -r $EM_GRO \
     -p $WORKDIR/topol.top -o $NVT_TPR

$MPI_CMD $GMX mdrun -deffnm $NVT_OUT -v $GPU_FLAGS

# --- NVT ANALYSIS (Inline Gnuplot) ---
if [ -f "${NVT_OUT}.edr" ]; then
    echo "--> Analyzing NVT Temperature..."
    
    # Extract Data
    { echo "Temperature"; echo "0"; } | $GMX energy -f ${NVT_OUT}.edr -o $RESULTS_DIR/temperature.xvg

    # Plot directly here!
    gnuplot <<-EOF
        set terminal pngcairo size 800,600 enhanced font 'Arial,12'
        set output "$RESULTS_DIR/2_temperature.png"
        set title "NVT Equilibration ($TEMP K)"
        set xlabel "Time (ps)"
        set ylabel "Temperature (K)"
        set grid
        
        # Draw a line at target temp (Bash variable injection!)
        set arrow from graph 0,first $TEMP to graph 1,first $TEMP nohead lc rgb "red" dt 2
        
        plot "$RESULTS_DIR/temperature.xvg" using 1:2 with lines lc rgb "blue" title "System Temp"
EOF

    echo "--> Plot saved to $RESULTS_DIR/2_temperature.png"
else
    echo "!! ERROR: NVT failed."
    exit 1
fi


# ==========================================
# PHASE 2: NPT (Pressure)
# ==========================================
echo "--> Running NPT Equilibration..."

NPT_TPR="$WORKDIR/npt.tpr"
NPT_OUT="$WORKDIR/npt"

$GMX grompp -f $WORKDIR/npt.mdp \
     -c ${NVT_OUT}.gro -r ${NVT_OUT}.gro -t ${NVT_OUT}.cpt \
     -p $WORKDIR/topol.top -o $NPT_TPR

$MPI_CMD $GMX mdrun -deffnm $NPT_OUT -v $GPU_FLAGS

# --- NPT ANALYSIS (Inline Gnuplot) ---
if [ -f "${NPT_OUT}.edr" ]; then
    echo "--> Analyzing NPT Pressure/Density..."
    
    # Extract
    { echo "Pressure"; echo "0"; } | $GMX energy -f ${NPT_OUT}.edr -o $RESULTS_DIR/pressure.xvg
    { echo "Density"; echo "0"; } | $GMX energy -f ${NPT_OUT}.edr -o $RESULTS_DIR/density.xvg

    # Plot Pressure
    gnuplot <<-EOF
        set terminal pngcairo size 800,600 enhanced font 'Arial,12'
        set output "$RESULTS_DIR/3_pressure.png"
        set title "NPT Pressure"
        set xlabel "Time (ps)"
        set ylabel "Pressure (bar)"
        set grid
        plot "$RESULTS_DIR/pressure.xvg" using 1:2 with lines lc rgb "green" title "Pressure"
EOF

    # Plot Density
    gnuplot <<-EOF
        set terminal pngcairo size 800,600 enhanced font 'Arial,12'
        set output "$RESULTS_DIR/3_density.png"
        set title "NPT Density"
        set xlabel "Time (ps)"
        set ylabel "Density (kg/m^3)"
        set grid
        plot "$RESULTS_DIR/density.xvg" using 1:2 with lines lc rgb "purple" title "Density"
EOF
        
    echo "--> Plots saved to $RESULTS_DIR/"
else
    echo "!! ERROR: NPT failed."
    exit 1
fi
