#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 2: EQUILIBRATION <<<"

# Helper to update temp in mdp
update_temp() {
    sed -i "s/ref_t.*=.*/ref_t                   = $2/" $1
    sed -i "s/gen_temp.*=.*/gen_temp                = $2/" $1
}

# Helper to update nsteps based on time (ps)
update_steps() {
    local file=$1
    local time_ps=$2
    
    # Get timestep (dt) from file, default to 0.002 if missing
    local dt=$(grep "dt" $file | awk '{print $3}' | sed 's/;//')
    if [ -z "$dt" ]; then dt=0.002; fi

    # Calculate steps
    local steps=$(echo "$time_ps / $dt" | bc)
    
    echo "--> Setting $file to $time_ps ps ($steps steps)"
    sed -i "s/nsteps.*=.*/nsteps                  = $steps/" $file
}

echo "--> Updating temperature to $TEMP K..."
update_temp params/nvt.mdp $TEMP
update_temp params/npt.mdp $TEMP

# ==========================================
# PHASE 1: NVT (Temperature)
# ==========================================
echo "--> Configuring NVT..."
update_steps params/nvt.mdp $NVT_TIME_PS

echo "--> Running NVT..."
$GMX grompp -f params/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
$MPI_CMD $GMX mdrun -deffnm -v nvt $GPU_FLAGS

if [ -f "nvt.edr" ]; then
    echo "--> Analyzing NVT Temperature..."
    { echo "Temperature"; echo "0"; } | $GMX energy -f nvt.edr -o $RESULTS_DIR/temperature.xvg

    gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
        "$RESULTS_DIR/temperature.xvg" \
        "$RESULTS_DIR/2_temperature.png" \
        "NVT Equilibration" \
        "Time (ps)" \
        "Temperature (K)" \
        2 \
        10

    echo "--> Plot saved to $RESULTS_DIR/2_temperature.png"
else
    echo "!! ERROR: NVT failed."
    exit 1
fi

# ==========================================
# PHASE 2: NPT (Pressure & Density)
# ==========================================
echo "--> Configuring NPT..."
update_steps params/npt.mdp $NPT_TIME_PS

echo "--> Running NPT..."
$GMX grompp -f params/npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
$MPI_CMD $GMX mdrun -deffnm npt -v $GPU_FLAGS

if [ -f "npt.edr" ]; then
    echo "--> Analyzing NPT Pressure and Density..."
    
    # Pressure
    { echo "Pressure"; echo "0"; } | $GMX energy -f npt.edr -o $RESULTS_DIR/pressure.xvg
    gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
        "$RESULTS_DIR/pressure.xvg" \
        "$RESULTS_DIR/3_pressure.png" \
        "NPT Equilibration" \
        "Time (ps)" \
        "Pressure (bar)" \
        2 \
        20

    # Density
    { echo "Density"; echo "0"; } | $GMX energy -f npt.edr -o $RESULTS_DIR/density.xvg
    gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
        "$RESULTS_DIR/density.xvg" \
        "$RESULTS_DIR/3_density.png" \
        "NPT Equilibration" \
        "Time (ps)" \
        "Density (kg/m^3)" \
        2 \
        20
        
    echo "--> Plots saved to $RESULTS_DIR/"
else
    echo "!! ERROR: NPT failed."
    exit 1
fi
