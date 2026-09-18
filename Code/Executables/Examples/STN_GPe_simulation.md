# Figure 10: shifted STN--GPe coordinates

Run from `Code/Executables/Examples` in MATLAB:

```matlab
generate_stn_gpe_figures('synthesize');
generate_stn_gpe_figures('simulate');
```

The generator explicitly selects `lambdaSector=1`, `lambdaZF=0` in its
generated copy of `Example_4/Example_4_synthesis.m`. It saves the controller
in `stn_gpe_sector_controller.mat`. The simulation loads this controller and
integrates the shifted nonlinearities and equilibrium deviations, with delay
transport states discretized using PIESIM. The initial condition and delay
states are zero in shifted coordinates, and a `[10;-10]` sine-squared
pulse acts at the activation outputs on `[0.10,0.14]` seconds.

`stn_gpe_sector_simulation.mat` stores the shifted trajectories, validation,
controller, synthesis results, and source provenance. `plot-trajectories`
replots these data when available. It exports the paper's existing
`Figures/stn_gpe_sector_trajectories.pdf`.

The September 18, 2026 run certified alpha=0.4921875, with feasible primal
and dual analysis. Equilibrium rates are `[20.44251554,21.83661841]` spikes/s.
Shifted sector limits are `[119.088146,201.850931]`; peak control effort is
approximately 19.15 spikes/s. Relative N=24/32 spatial-convergence errors
are below 2.4e-6. The `simulate-unshifted` mode remains available for
coordinate-equivalence checks (previous errors below 7e-9). An independent
`dde23` simulation with the physical delays agrees with the open loop to
within 5e-9 relative error. The raw synthesis plant is used to avoid
rescaling cached PIE realizations twice; `PIE_sim_nl` now returns the
original unscaled realization for safe reuse. Passing the
sector checks along these simulated trajectories does not prove invariance
for other initial histories or disturbances.

For comparison, `Figures/stn_gpe_reference_5c.pdf` reproduces the reference
paper's zero-rate initial history without a disturbance. Figure 10 instead
starts at equilibrium (zero shifted initial condition), including consistent
equilibrium delay states, and retains the disturbance pulse.
