# GROMACS MD Pipeline (Streamlined)

A streamlined collection of shell scripts for setting up and running molecular dynamics protein simulations on a local Linux PC (with NVIDIA GPU support). 

This workflow automates the "Introductory Tutorial" by Justin Lemkul ([DOI: 10.1021/acs.jpcb.4c04901](https://pubs.acs.org/doi/full/10.1021/acs.jpcb.4c04901)).

## Key Features
* **Centralized Config:** Control everything (Temperature, Time, PDB Name) from `0_config.sh`.
* **Clean Workspace:** All intermediate files (tpr, gro, log) are hidden in `work_files/`.
* **Auto-Resume:** The production script automatically detects checkpoints and extends simulations if you increase the time in the config.
* **Inline Analysis:** Plots (PNG) are generated automatically after every step.

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
    You can run the steps individually:

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
        ```bash
        ./3_production.sh
        ```
        *Runs the production simulation. Re-run this script to extend the simulation if you change `SIM_TIME_NS`.*

    * **Step 4: Visualization Prep**
        ```bash
        ./4_visualization.sh
        ```
        *Centers the protein, removes water/ions, and smooths the trajectory for viewing in PyMOL/ChimeraX.*

## Output Structure

* `results/`: Contains all **Graphs** (PNG), **Data** (XVG), and the final **Cleaned Trajectory** for visualization.
* `work_files/`: Contains all intermediate GROMACS files (`.tpr`, `.gro`, `.log`, `.cpt`). 
* `params/`: Contains the immutable MDP templates. **Do not edit these during a run.**

## How to Customize Physics

Do **not** edit the files in `work_files/` (like `nvt.mdp`). They are overwritten every time you run a script.

To change physics settings (e.g., changing the thermostat or cutoffs):
1.  Edit the **Template** files in `params/` (e.g., `params/nvt.mdp.template`).
2.  Keep the placeholders (e.g., `REPLACEME_TEMP`) intact if you want them controlled by `0_config.sh`.