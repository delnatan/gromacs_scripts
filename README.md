# GROMACS MD Pipeline (Streamlined)

A streamlined collection of shell scripts for setting up and running molecular dynamics protein simulations on a local Linux PC (with NVIDIA GPU support). 

This workflow automates the "Introductory Tutorial" by Justin Lemkul ([DOI: 10.1021/acs.jpcb.4c04901](https://pubs.acs.org/doi/full/10.1021/acs.jpcb.4c04901)).

## Key Features
* **Replicate Support:** Easily run N=3 independent replicates with randomized velocities to ensure statistical validity.
* **Multi-Chain Support:** Automatically handles clustering for protein complexes (chains A, B, etc.) during visualization.
* **Centralized Config:** Control everything (Temperature, Time, PDB Name) from `0_config.sh`.
* **Auto-Resume:** The scripts detect crashes and resume automatically.

## Prerequisites
* **GROMACS** (installed as `gmx` or `gmx_mpi`)
* **Gnuplot** (for automatic graph generation)
* `bc` (basic calculator for time step math)

## Quick Start

1.  **Setup:**
    Clone this repo and place your clean PDB file in the root folder.
    ```bash
    chmod +x *.sh
    ```

2.  **Configure:**
    Edit `0_config.sh`. This is the **only** file you need to touch.
    * Set `PDB_NAME` to match your `.pdb` file.
    * Set `TEMP` (e.g., 310) and `SIM_TIME_NS` (e.g., 100).
    * Set `GPU_FLAGS` if you have an NVIDIA card.

3.  **Run the Pipeline:**

    * **Step 1: Setup & Minimization**
        ```bash
        ./1_setup_and_minimization.sh
        ```
        *Generates topology, adds solvent/ions, and minimizes energy.*

    * **Step 2: Equilibration (NVT & NPT)**
        ```bash
        ./2_equilibration.sh
        ```
        *Heats the system to target temp and stabilizes pressure.*

    * **Step 3: Production MD**
        Choose your preferred mode:
        
        * **Option A: Independent Replicates (Recommended)**
            ```bash
            ./3_production.sh replicates
            ```
            *Generates 3 independent simulations (`md_rep_1`, `2`, `3`) with randomized initial velocities.*
            *To extend these runs later (e.g., 100ns -> 200ns), use: `./3_production.sh extend_replicates`*

        * **Option B: Single Continuous Run**
            ```bash
            ./3_production.sh continue
            ```
            *Runs/Extends a single trajectory (`md_0_1`).*

    * **Step 4: Visualization Prep**
        Process your trajectories for viewing (centers protein, fixes PBC for multi-chain complexes, smooths jitter).
        ```bash
        ./4_visualization.sh [input_name]
        ```
        * For Replicates: `./4_visualization.sh md_rep_1`
        * For Single Run: `./4_visualization.sh` (defaults to `md_0_1`)

## Output Structure

* `results/`: Contains all **Graphs** (PNG), **Data** (XVG), and the final **Cleaned Trajectories** (`_clean.xtc`) and **Reference PDBs** (`_ref.pdb`).
* `work_files/`: Contains all intermediate GROMACS files (`.tpr`, `.gro`, `.log`, `.cpt`). 
* `params/`: Contains the immutable MDP templates. **Do not edit these during a run.**

## How to Customize Physics

Do **not** edit the files in `work_files/` (like `nvt.mdp`). They are overwritten every time you run a script.

To change physics settings (e.g., changing the thermostat or cutoffs):
1.  Edit the **Template** files in `params/` (e.g., `params/md.mdp.template`).
2.  Keep the placeholders (e.g., `REPLACEME_TEMP`) intact if you want them controlled by `0_config.sh`.

## Visualization Notes
* **ChimeraX:** Open the `_ref.pdb` first, then load the `_clean.xtc`.
* **Chain IDs:** GROMACS trajectories often strip chain IDs. In ChimeraX, you can restore them or select by index.
* **Multi-Chain:** The visualization script uses `-pbc cluster`, so your protein complex should stay bound together visually.