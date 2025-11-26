# Collection of GROMACS scripts

Collection of shell scripts for setting up and running molecular dynamics protein simulation a local linux PC on NVIDIA GPU.

This script was written following the article by Justin Lemkul ("Introductory Tutorials for Simulating Protein Dynamics with GROMACS"). See [here](https://pubs.acs.org/doi/full/10.1021/acs.jpcb.4c04901).

1. Clone this repo into a folder containing your initial PDB file.
2. Change the permission for all `.sh` files so they're executable.
3. Configure variables in 0_config.sh. Generally just make sure the name of the PDB file is correct and the temperature is what you want.
3. Run 1_setup_and_minimization.sh
4. Run 2_equilibration.sh
5. Run 3_production.sh

For visualization, see the script `scripts/post_process_trajectory.sh` to generate a reference PDB and a downsampled trajectory file that you can open using ChimeraX.