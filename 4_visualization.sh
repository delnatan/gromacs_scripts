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
# 1. Make molecules 'whole'
# ==========================================
echo "1/5 undoing PBC on system"
echo "System" | $GMX trjconv -s $TPR_FILE -F $XTC_FILE \
                     -o $WORKDIR/tmp_whole.xtc \
                     -pbc whole \
                     -quiet

# ==========================================
# 2. Center & Unwrap
# ==========================================
# "Backbone" centers the protein. "System" is output.
# "-pbc mol" keeps molecules together.
echo "--> 2/5 Centering protein and unwrapping PBC..."
echo -e "Backbone\nSystem" | $GMX trjconv -s $TPR_FILE \
                                  -f $WORKDIR/tmp_whole.xtc \
                                  -o $WORKDIR/tmp_centered.xtc \
                                  -center -pbc mol -ur compact\
                                  -dt $DT_VIZ \
                                  -quiet

# ==========================================
# 3. Fit (Remove Rotation/Translation)
# ==========================================
# "Backbone" is used for least-squares fitting. "non-Water" is output.
# This makes the protein look like it's standing still while water moves around it.
echo "--> 3/5 Aligning trajectory (Rot+Trans fit)..."
echo -e "Backbone\nSystem" | $GMX trjconv -s $TPR_FILE \
                                  -f $WORKDIR/tmp_centered.xtc \
                                  -o $WORKDIR/tmp_aligned.xtc \
                                  -fit rot+trans \
                                  -quiet

# ==========================================
# 4. Smooth (Filter)
# ==========================================
# High-frequency vibrations can be distracting in videos. 
# This averages positions over $SMOOTH_FRAMES.
echo "--> 4/5 Smoothing trajectory (Average over $SMOOTH_FRAMES frames)..."

echo -e "non-Water" | $GMX filter -s $TPR_FILE -f $WORKDIR/tmp_aligned.xtc \
                           -ol $WORKDIR/tmp_smoothed \
                           -nf $SMOOTH_FRAMES -all \
                           -quiet

# ==========================================
# 5. Generate Reference PDB with matching trajectory
# ==========================================
# We dump the FIRST frame of the NEW, aligned, smoothed trajectory.
# This ensures the PDB atoms are in the exact same box/orientation as the XTC.
echo "--> 5/5 Extracting reference PDB..."

FINAL_PDB="$VIZ_DIR/${PDB_NAME}_ref.pdb"
echo -e "non-Water" | $GMX trjconv -s $TPR_FILE -f $WORKDIR/tmp_smoothed.xtc \
                           -o $FINAL_PDB \
                           -dump 0 \
                           -quiet

FINAL_TRAJ="$VIZ_DIR/${PDB_NAME}_clean_traj.xtc"
echo -e "non-Water" | $GMX trjconv -s $TPR_FILE -f $WORKDIR/tmp_smoothed.xtc \
                           -o $FINAL_TRAJ \
                           -quiet

# Cleanup
rm $WORKDIR/tmp_centered.xtc $WORKDIR/tmp_aligned.xtc $WORKDIR/tmp_smoothed.xtc

echo ">>> VISUALIZATION PREP COMPLETE <<<"
echo "To view in ChimeraX/PyMOL:"
echo "1. Open $FINAL_PDB"
echo "2. Load $FINAL_TRAJ into it"
