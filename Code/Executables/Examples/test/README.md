# Figure 10: sector versus nominal controller

Run in MATLAB from this directory:

```matlab
compare_stn_gpe_nominal
```

To regenerate the figure from the saved comparison without synthesis or simulation:

```matlab
compare_stn_gpe_nominal('plot')
```

The script loads the exact open-loop and sector-controller trajectories from
`../stn_gpe_sector_simulation.mat`. It preserves Figure 10's six panels,
coordinates, colors, time range, sector limits, and disturbance. Purple
dash-dot curves add the nominal controller's nonlinear trajectories and
control effort. The legend has two rows to accommodate the additional entry;
vertical limits expand where needed to show the new curves.

The nominal controller is synthesized with **Delta = 0**, so its design model
is `T*x_dot = A*x + B2*u`. This removes the shifted sigmoid feedback entirely;
it is not a linearization using the sigmoid's equilibrium slope. The design
uses the same stability-feasibility executive, `veryheavy` polynomial settings,
separable storage, control location/scaling, and MOSEK solver as the sector
example. There is no added performance objective or tuning of the nominal law.
Disconnected input/output ports retain their dimensions with zero operators
and a decoupled negative identity multiplier block; the remaining LPI is
`T*X*A' + T*Z*B2' + adjoint <= 0`, with recovered `K = Z'*inv(X)`.

Both controllers are evaluated on the **full shifted nonlinear system** with
the original delays, zero deviation history, and the same `[10;-10]`
sine-squared disturbance pulse on `[0.10,0.14]` seconds. The nominal simulation
uses Figure 10's time grid and tolerances. Control effort is converted to
paper units using `u_paper = 0.006*4600*u_code`. Sector lines describe the
sector controller's certificate; they are not a nominal robustness guarantee.

Validation checks solver feasibility and relative residual, nominal closed-loop
discretized eigenvalues at N=24 and N=32, nonlinear trajectory convergence
between those orders (relative tolerance 1e-3), identical disturbance/time
grids, and preservation of the baseline trajectory arrays.

Outputs are saved only in this directory:

- `stn_gpe_sector_vs_nominal.pdf`, `.png`, `.fig`: comparison figure.
- `stn_gpe_nominal_comparison.mat`: controllers, baseline and nominal
  trajectories, solver diagnostics, convergence checks, and source snapshot.
- `stn_gpe_comparison_metrics.csv`: peaks, final state norm, and input maxima.
- `stn_gpe_nominal_comparison.log`: synthesis and validation output.

Dependencies: repository code, PIETOOLS, MOSEK, and the existing Figure 10 cache.
The paper and its figures are not modified.
