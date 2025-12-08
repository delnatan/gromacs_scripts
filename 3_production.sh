#!/bin/bash
source 0_config.sh

echo ">>> STARTING STEP 3: PRODUCTION MD <<<"

MODE=$1
NUM_REPLICAS=3

if [[ "$MODE" == "replicates" ]]; then
    echo ">>> MODE: New replicas <<<"
    echo "   generating $NUM_REPLICAS independent simulations."
    echo "   starting from NPT with new random velocities."

    START=1
    END=$NUM_REPLICAS

    SET_GEN_VEL="yes"
    SET_CONTINUATION="no"

elif [[ "$MODE" == "extend_replicates" ]]; then
    # CASE B: Extend Existing Replicates (100ns -> 200ns)
    echo ">>> MODE: EXTEND REPLICATES <<<"
    START=1
    END=$NUM_REPLICAS
    SET_GEN_VEL="no"       # Do not regen velocities
    SET_CONTINUATION="yes" # Keep constraints
    
elif [[ "$MODE" == "continue" ]]; then
    echo ">>> MODE: continue / extend <<<"
    echo "    extending existing simulation "
    START=1
    END=1
    SET_GEN_VEL="no"
    SET_CONTINUATION="yes"
else
    echo "Usage: ./3_production.sh [replicates | extend_replicates | continue]"
    exit 1
fi


# ==========================================
# 1. Prepare Parameters (Template Strategy)
# ==========================================
# Calculate total duration in ps and steps
TOTAL_PS=$(echo "$SIM_TIME_NS * 1000" | bc)
NSTEPS=$(echo "$TOTAL_PS / $DT" | bc)

for (( i=$START; i<=$END; i++ ))
do
    if [[ "$MODE" == "replicates" ]] || [[ "$MODE" == "extend_replicates" ]]; then
        PREFIX="md_rep_${i}"
    else
        PREFIX="md_0_1"
    fi

    MD_MDP="$WORKDIR/${PREFIX}.mdp"
    TPR_FILE="$WORKDIR/${PREFIX}.tpr"
    CPT_FILE="$WORKDIR/${PREFIX}.cpt"
    FINAL_GRO="$WORKDIR/${PREFIX}.gro" # The file GROMACS writes when 100% done

    echo "Processing: $PREFIX"

    if [[ -f "$FINAL_GRO" && "$MODE" == "replicates" ]]; then
        echo "--> simulation $PREFIX appears COMPLETED"
        echo "skipping ...."
        continue
    fi

    # 1. prepare parameters (from template)
    # Generate the MD parameter file from template
    # We use the config variables to fill in the blanks
    sed -e "s/REPLACEME_TEMP/$TEMP/g" \
        -e "s/REPLACEME_STEPS/$NSTEPS/g" \
        -e "s/REPLACEME_DT/$DT/g" \
        -e "s/GENERATEVELO_TEMP/$SET_GEN_VEL/g" \
        -e "s/SET_CONTINUATION/$SET_CONTINUATION/g" \
        params/md.mdp.template > $MD_MDP

    # 2. Prepare TPR

    if [[ "$MODE" == "replicates" ]]; then
        if [[ -f "$TPR_FILE" ]]; then
            echo "--> TPR exists. Preserving."
        else
            echo "--> Assembling new binary input..."
            $GMX grompp -f $MD_MDP \
                 -c $WORKDIR/npt.gro \
                 -t $WORKDIR/npt.cpt \
                 -p $WORKDIR/topol.top \
                 -o $TPR_FILE
        fi
    
    elif [[ "$MODE" == "continue" ]] || [[ "$MODE" == "extend_replicates" ]]; then
        if [[ -f "$TPR_FILE" ]]; then
            echo "--> Extending run to $SIM_TIME_NS ns..."
            # This updates the TPR limit to the new time
            $GMX convert-tpr -s $TPR_FILE -until $TOTAL_PS -o $TPR_FILE
        else
            echo "!! ERROR: Cannot extend $PREFIX.tpr - file not found."
            continue
        fi
    fi

    # 3. Execution (Smart Resume)
    CPI_FLAGS=""
    if [ -f "$CPT_FILE" ]; then
        echo "--> Checkpoint found. Resuming from last saved step..."
        CPI_FLAGS="-cpi $CPT_FILE -append"
    fi

    echo "--> Running Production MD..."
    # -deffnm sets the default filename for all outputs (log, edr, xtc, trr)
    # We point this to $WORKDIR/md_0_1 to keep root clean
    $MPI_CMD $GMX mdrun -v -deffnm $WORKDIR/$PREFIX $GPU_FLAGS $CPI_FLAGS

done
