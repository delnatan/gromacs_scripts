#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 5: POST-PROCESSING AND ANALYSIS <<<"

# Define filenames
RAW_TRAJ="md_0_1.xtc"
TPR_FILE="md_0_1.tpr"

# Output files
PROTEIN_TRAJ="${RESULTS_DIR}/protein_only.xtc"
PROTEIN_PDB="${RESULTS_DIR}/protein.pdb"

RMSD_FILE="${RESULTS_DIR}/final_rmsd.xvg"
RMSF_FILE="${RESULTS_DIR}/final_rmsf.xvg"

# Check if raw trajectory exists
if [ ! -f "$RAW_TRAJ" ]; then
    echo "!! ERROR: $RAW_TRAJ not found. Run production first."
    exit 1
fi

# ==========================================
# 1. PREPARE VMD FILES (Protein Only)
# ==========================================
echo "--> Generating VMD-friendly files..."

# A. Extract the Protein Structure (PDB)
# FIX: Added '-pbc mol -ur compact'
# This ensures the PDB structure itself is not split across the box.
# If the PDB is split, VMD will define the bonds incorrectly from the start.
echo "1" | $GMX trjconv -s $TPR_FILE -f $RAW_TRAJ -o $PROTEIN_PDB -pbc mol -center -ur compact

# B. Extract the Protein Trajectory (Rotated & Fitted)
# FIX: Added '-pbc mol'
# We fit the protein (rot+trans) AND ensure molecules are whole (-pbc mol).
# Select Group 1 (Protein) for Fit, Group 1 (Protein) for Output.
{ echo "1"; echo "1"; } | $GMX trjconv -s $TPR_FILE -f $RAW_TRAJ -o $PROTEIN_TRAJ -fit rot+trans -pbc mol 

echo "--> VMD Files Generated:"
echo "    1. Structure:  $PROTEIN_PDB"
echo "    2. Trajectory: $PROTEIN_TRAJ"


# ==========================================
# 2. RMSD ANALYSIS
# ==========================================
echo "--> Calculating RMSD (Backbone)..."
# 4 = Backbone (Fit), 4 = Backbone (Calc)
{ echo "4"; echo "4"; } | $GMX rms -s $TPR_FILE -f $PROTEIN_TRAJ -o $RMSD_FILE -tu ns

gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
    "$RMSD_FILE" \
    "${RESULTS_DIR}/5_final_rmsd.png" \
    "Backbone RMSD (Stabilized)" \
    "Time (ns)" \
    "RMSD (nm)" \
    2 \
    0
 
echo "--> RMSD plot saved to ${RESULTS_DIR}/5_final_rmsd.png"


# ==========================================
# 3. RMSF ANALYSIS (Residue Flexibility)
# ==========================================
echo "--> Calculating RMSF (C-alpha)..."
# 3 = C-alpha
{ echo "3"; } | $GMX rmsf -s $TPR_FILE -f $PROTEIN_TRAJ -o $RMSF_FILE -res

gnuplot -c $SCRIPTS_DIR/plot_generic.gp \
    "$RMSF_FILE" \
    "${RESULTS_DIR}/5_final_rmsf.png" \
    "Residue Fluctuation (RMSF)" \
    "Residue Number" \
    "Fluctuation (nm)" \
    2 \
    0  # No smoothing for RMSF

echo "--> RMSF plot saved to ${RESULTS_DIR}/5_final_rmsf.png"
echo ">>> ANALYSIS COMPLETE <<<"
