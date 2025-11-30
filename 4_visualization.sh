#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 4: VISUALIZATION PREP <<<"

# Define Inputs (from WorkDir)
TPR_FILE="$WORKDIR/md_0_1.tpr"
XTC_FILE="$WORKDIR/md_0_1.xtc"

# Define Output Folder
VIZ_DIR="$RESULTS_DIR/visualization"
mkdir -p $VIZ_DIR

# Settings for Visualization
# Skip frames to make file smaller (e.g., 100ps = 0.1ns)
DT_VIZ=100 
# Smooth out jittery atoms (averages N frames)
SMOOTH_FRAMES=4

echo "--> Configuration:"
echo "    Input:  $XTC_FILE"
echo "    Output: $VIZ_DIR"
echo "    Step:   ${DT_VIZ}ps"

if [ ! -f "$XTC_FILE" ]; then
    echo "!! ERROR: Trajectory not found. Run Step 3 first."
    exit 1
fi

# ==========================================
# 1. Center & Unwrap
# ==========================================
# "Backbone" centers the protein. "System" is output.
# "-pbc mol" keeps molecules together.
echo "--> 1/4 Centering protein and unwrapping PBC..."
echo -e "Backbone\nSystem" | $GMX trjconv -s $TPR_FILE -f $XTC_FILE \
    -o $WORKDIR/tmp_centered.xtc \
    -center -pbc mol -dt $DT_VIZ \
    -quiet

# ==========================================
# 2. Fit (Remove Rotation/Translation)
# ==========================================
# "Backbone" is used for least-squares fitting. "System" is output.
# This makes the protein look like it's standing still while water moves around it.
echo "--> 2/4 Aligning trajectory (Rot+Trans fit)..."
echo -e "Backbone\nSystem" | $GMX trjconv -s $TPR_FILE -f $WORKDIR/tmp_centered.xtc \
    -o $WORKDIR/tmp_aligned.xtc \
    -fit rot+trans \
    -quiet

# ==========================================
# 3. Smooth (Filter)
# ==========================================
# High-frequency vibrations can be distracting in videos. 
# This averages positions over $SMOOTH_FRAMES.
echo "--> 3/4 Smoothing trajectory (Average over $SMOOTH_FRAMES frames)..."
FINAL_TRAJ="$VIZ_DIR/${PDB_NAME}_clean_traj.xtc"

echo -e "System" | $GMX filter -s $TPR_FILE -f $WORKDIR/tmp_aligned.xtc \
    -ol $FINAL_TRAJ \
    -nf $SMOOTH_FRAMES -all \
    -quiet

# ==========================================
# 4. Generate Reference PDB
# ==========================================
# We dump the FIRST frame of the NEW, aligned trajectory.
# This ensures the PDB atoms are in the exact same box/orientation as the XTC.
echo "--> 4/4 Extracting reference PDB..."
FINAL_PDB="$VIZ_DIR/${PDB_NAME}_ref.pdb"

echo -e "System" | $GMX trjconv -s $TPR_FILE -f $FINAL_TRAJ \
    -o $FINAL_PDB \
    -dump 0 \
    -quiet

# Cleanup
rm $WORKDIR/tmp_centered.xtc $WORKDIR/tmp_aligned.xtc

echo ">>> VISUALIZATION PREP COMPLETE <<<"
echo "To view in ChimeraX/PyMOL:"
echo "1. Open $FINAL_PDB"
echo "2. Load $FINAL_TRAJ into it"
