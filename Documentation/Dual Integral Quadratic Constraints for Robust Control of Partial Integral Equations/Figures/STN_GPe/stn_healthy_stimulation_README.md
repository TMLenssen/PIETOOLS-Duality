# Healthy-network stimulation example

Run `stn_healthy_stimulation.m` in MATLAB. It saves PNG, vector PDF, MATLAB
figure, CSV and MAT files next to the script. Change the `stim` settings at
the top to change the pulse train; choose `dt_s` so every pulse edge falls on
the time grid. The script checks this rather than silently rounding pulses.

Plots have no titles and transparent backgrounds, with trajectory axes
labelled `spikes/s` and `t`. The healthy current panel retains its mA label.
Transparent PNG export uses `render_stn_plot.py` (Python with PyMuPDF) to
render the vector PDF, because MATLAB's raster export does not preserve alpha.

The second plot, `stn_healthy_input_spikes.png` (also PDF/FIG), displays the
model input `u(t)=4600*current_mA(t)` in spikes/s. Its pulse amplitude is
920 spikes/s for the same 0.2 mA stimulus; the pulse frequency remains 100 Hz.
The trajectories are identical. The main script exports both views; run
`stn_healthy_input_spikes` alone to regenerate the second from saved results.

The default is ten pulses at 100 pulses/s, starting at 0.1 s, each with an
amplitude of 0.2 mA and a width of 0.3 ms. The burst frequency and count follow
the burst structure discussed in the reference. The amplitude and width are
illustrative simulation choices, not values claimed to reproduce Figure 3
or treatment settings.

## Model and source

Equation (21) in the manuscript is implemented using its exactly equivalent
delay representation, `phi_ij(t,1) = x_i(t - tau_ij)`. The numerical method
does not discretize the transport PDE in space. The two rate equations are

```
tauS * xS_dot = deltaS(-wGS*xG(t-tauGS)) - xS + u(t)
tauG * xG_dot = deltaG(wSG*xS(t-tauSG)-wGG*xG(t-tauGG)) - xG
delta_i(v)   = sigma_i(z_i_star+v) - sigma_i(z_i_star)
sigma_i(q)   = (M_i/2)*tanh(2*q/M_i)
z_i_star     = q_i_star - (M_i/4)*log((M_i-B_i)/B_i)
F_i(q)       = M_i / (1 + exp(-4*q/M_i)*(M_i-B_i)/B_i)
u(t)         = 4600 * current_mA(t)
```

The healthy equilibrium is recomputed using the healthy weights, including
the cortical and striatal terms. All histories start at that equilibrium.
Both plots show the shifted states `x_S` and `x_G`, in spikes/s, with the
equilibrium at zero. Absolute rates (equilibrium plus `x`) are retained only
as additional data in the MAT/CSV exports. Stimulation in the healthy case
enters **outside** the sigmoid, as in the source, so the sigmoid's maximum
is not a hard cap on the externally driven STN rate.

Parameters are from Nevado Holgado et al. (2010), *Analysis of the conditions
for the generation of beta oscillations in the subthalamic nucleus-globus
pallidus network*, J. Neurosci. 30, 12340-12352,
DOI: 10.1523/JNEUROSCI.0817-10.2010, Tables 1 and 3 and Equations (3), (5).
Equation (21) is the manuscript's numbering; Equation (5) is the original
paper's stimulated model.

| Weight | Healthy | Parkinsonian |
|---|---:|---:|
| STN to GPe, wSG | 19.0 | 20.0 |
| GPe to STN, wGS | 1.12 | 10.7 |
| GPe to GPe, wGG | 6.60 | 12.3 |
| Cortex to STN, wCS | 2.42 | 9.2 |
| Striatum to GPe, wXG | 15.1 | 139.4 |

These are fitted animal-model parameters. The reference models GPe as one
population; the existing diagrams use 'Proto' as a schematic stand-in, not
a separately identified prototypical-neuron model. The stimulation conversion
4600 (spikes/s)/mA is fitted for the healthy case. This population model does
not resolve individual spikes, electrode geometry, tissue fields or the
charge-balancing phase of a physical stimulation waveform.

## Numerical verification

The script uses RK4 with interpolated delayed history, with current held
constant over each integration interval. Pulse edges are explicitly aligned
to the grid, including the interval endpoints in RK4. It compares 20 and
10 microsecond steps, verifies that no stimulation leaves the equilibrium
unchanged, checks pulse count and total current-time integral, and checks
recovery after the burst.

## Matching transparent diagrams

`stn_proto_aligned/weights_healthy.png` and
`stn_proto_aligned/weights_parkinsonian.png` use the same canvas and circuit
coordinates as the existing diagrams. Annotation-only versions have the
suffix `_overlay.png`. All are included in `stn_proto_aligned.zip` and are
generated from `stn_proto_overlay_set.tex` by `render_stn_proto_overlay_set.py`.

## Parkinsonian comparison

Run `stn_parkinsonian_stimulation.m` for the counterpart with all five
Parkinsonian weights from Table 3. Its outputs use the prefix
`stn_parkinsonian_stimulation` (the filename is retained for existing links).
The displayed time window and population colors match the healthy example.
There are no pulses and no current panel: `u(t)=0` for the entire run.

The diseased equilibrium is recomputed. A constant 1 spike/s STN deviation
in the initial history seeds the instability. The full evolution from this
small perturbation is shown, without hiding a warm-up period. The dotted
horizontal line marks the shifted equilibrium at zero. The script verifies
persistent oscillations, time-step convergence and that an exactly zero
history stays at zero. No current conversion is needed in the diseased run.
