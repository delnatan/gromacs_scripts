#!/bin/bash
# avoid generating backup files
export GMX_MAXBACKUP=-1 
# exit if command fails
set -e

# --- CONFIGURATION --- #
TPR="md_0_1.tpr"
XTC="md_0_1.xtc"
OUT_NAME_PREFIX=$1

# save frame every X picoseconds to reduce file size
DT=100

# trajectory smoothing by frame numbers to be averaged
SMOOTH_NF=4

GRP_CENTER="Backbone"
GRP_FIT="Backbone"
GRP_OUT="System"

echo "================================================================="

echo "1. Centering protein, fixing PBC, and coarsening (dt=${DT} ps)..."
echo -e "$GRP_CENTER\n$GRP_OUT" | gmx trjconv -s "$TPR" -f "$XTC" -o \
                                      temp_centered.xtc \
                                      -center \
                                      -pbc mol \
                                      -dt "$DT" -quiet

echo "2. Aligning trajectory (fitting to $GRP_FIT)... "
echo -e "$GRP_FIT\n$GRP_OUT" | gmx trjconv -s "$TPR" -f temp_centered.xtc \
                                   -o temp_aligned.xtc \
                                   -fit rot+trans -quiet

echo "3. Averaging trajectory by $SMOOTH_NF frames..."
echo -e "$GRP_OUT" | gmx filter -s "$TPR" -f temp_aligned.xtc \
                         -ol "${OUT_NAME_PREFIX}_traj_${DT}ps_${SMOOTH_NF}smooth.xtc" \
                         -nf "$SMOOTH_NF" -all \
                         -quiet

echo "4. Extracting reference PDB for processed trajectory"
echo -e "$GRP_OUT" | gmx trjconv -s "$TPR" \
                         -f "${OUT_NAME_PREFIX}_traj_${DT}ps_${SMOOTH_NF}smooth.xtc" \
                         -o "${OUT_NAME_PREFIX}_ref.pdb" -dump 0 -quiet

echo "5. Cleaning up temporary files..."
rm temp_centered.xtc temp_aligned.xtc

echo "================================================================="
echo "DONE!"
echo "Files created: "
echo "   1. Structure: ${OUT_NAME_PREFIX}_ref.pdb"
echo "   2. Trajectory: ${OUT_NAME_PREFIX}_traj_${DT}ps_${SMOOTH_NF}smooth.xtc"
echo "================================================================="
