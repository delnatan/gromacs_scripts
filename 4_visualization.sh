#!/bin/bash
source 0_config.sh

# ==========================================
# 0. Setup & Arguments
# ==========================================
# Usage: ./4_visualization.sh [input_prefix]
# Example: ./4_visualization.sh md_rep_1
# Default: md_0_1
INPUT_PREFIX=${1:-md_0_1}

echo ">>> STARTING STEP 4: VISUALIZATION PREP ($INPUT_PREFIX) <<<"

# Define Inputs
TPR_FILE="$WORKDIR/${INPUT_PREFIX}.tpr"
XTC_FILE="$WORKDIR/${INPUT_PREFIX}.xtc"

# Define Output Folder
VIZ_DIR="$RESULTS_DIR/visualization"
mkdir -p $VIZ_DIR

# --- Settings ---
# Skip frames to make file smaller (e.g., 100ps = 0.1ns)
DT_VIZ=100
# Toggle trajectory smoothing (true/false)
ENABLE_SMOOTHING=true
# Smoothing window (frames)
SMOOTH_FRAMES=4

if [ ! -f "$XTC_FILE" ]; then
    echo "!! ERROR: Trajectory $XTC_FILE not found."
    exit 1
fi

# ==========================================
# 1. Make molecules 'whole'
# ==========================================
# Fixes broken bonds across PBC (Standard first step)
echo "--> 1/5 Undoing PBC (Make Whole)..."
echo "System" | $GMX trjconv -s $TPR_FILE -f $XTC_FILE \
                     -o $WORKDIR/tmp_whole.xtc \
                     -pbc whole \
                     -quiet

# ==========================================
# 2. Cluster Complexes (The Universal Fix)
# ==========================================
# - Multi-chain: Groups chains together so they don't drift apart.
# - Single-chain: Harmlessly treats the chain as a cluster of 1.
echo "--> 2/5 Clustering molecules..."
echo -e "Protein\nSystem" | $GMX trjconv -s $TPR_FILE \
                                -f $WORKDIR/tmp_whole.xtc \
                                -o $WORKDIR/tmp_clustered.xtc \
                                -pbc cluster \
                                -quiet

# ==========================================
# 3. Center & Unwrap
# ==========================================
# Centers the Protein in the box.
echo "--> 3/5 Centering protein..."
echo -e "Protein\nSystem" | $GMX trjconv -s $TPR_FILE \
                                  -f $WORKDIR/tmp_clustered.xtc \
                                  -o $WORKDIR/tmp_centered.xtc \
                                  -center -pbc mol -ur compact\
                                  -dt $DT_VIZ \
                                  -quiet

# ==========================================
# 4. Fit (Remove Rotation/Translation)
# ==========================================
# Aligns the protein backbone to the reference structure.
echo "--> 4/5 Aligning trajectory (Rot+Trans fit)..."
echo -e "Backbone\nSystem" | $GMX trjconv -s $TPR_FILE \
                                  -f $WORKDIR/tmp_centered.xtc \
                                  -o $WORKDIR/tmp_aligned.xtc \
                                  -fit rot+trans \
                                  -quiet

# ==========================================
# 5. Optional Smoothing & Final Output
# ==========================================
FINAL_INPUT="$WORKDIR/tmp_aligned.xtc"

if [ "$ENABLE_SMOOTHING" = true ]; then
    echo "--> [OPTIONAL] Smoothing trajectory (Average over $SMOOTH_FRAMES frames)..."
    echo -e "System" | $GMX filter -s $TPR_FILE -f $WORKDIR/tmp_aligned.xtc \
                               -ol $WORKDIR/tmp_smoothed.xtc \
                               -nf $SMOOTH_FRAMES -all \
                               -quiet
    FINAL_INPUT="$WORKDIR/tmp_smoothed.xtc"
fi

# ==========================================
# 6. Extract Reference PDB & Trajectory
# ==========================================
echo "--> 6/6 Extracting final files..."

FINAL_PDB="$VIZ_DIR/${INPUT_PREFIX}_ref.pdb"
FINAL_TRAJ="$VIZ_DIR/${INPUT_PREFIX}_clean.xtc"

# Dump PDB (using non-Water to keep file size small for loading)
# We use frame 0 of the ALIGNED trajectory so it matches the XTC perfectly.
echo -e "non-Water" | $GMX trjconv -s $TPR_FILE -f $FINAL_INPUT \
                           -o $FINAL_PDB \
                           -dump 0 \
                           -quiet

# Dump Clean XTC (non-Water)
echo -e "non-Water" | $GMX trjconv -s $TPR_FILE -f $FINAL_INPUT \
                           -o $FINAL_TRAJ \
                           -quiet

# Cleanup temp files
rm $WORKDIR/tmp_whole.xtc $WORKDIR/tmp_clustered.xtc $WORKDIR/tmp_centered.xtc $WORKDIR/tmp_aligned.xtc 2>/dev/null
[ "$ENABLE_SMOOTHING" = true ] && rm $WORKDIR/tmp_smoothed.xtc 2>/dev/null

echo ">>> VISUALIZATION PREP COMPLETE <<<"
echo "Output PDB: $FINAL_PDB"
echo "Output XTC: $FINAL_TRAJ"
