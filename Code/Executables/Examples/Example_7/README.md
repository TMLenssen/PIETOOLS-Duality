# Example 7: boundary-feedback synthesis

## Run

- Example_7.m: construct the PDE with pde_var/convert and synthesize feedback.
- Example_7_timing.m: time synthesis for nuGrid=i:j.
- plot_Example_7.m: plot the synthesis gain-versus-pole sweep.
- closed_loop_equations.tex: exact uncertain and nominal plant coefficients,
  with u left as the boundary-control input.

This example performs synthesis only. The boundary actuator is

    v(t,0)=0, v_s(t,1)=[1;0]*x_b(t), x_b_dot(t)=u(t).

The performance output is [z_p;0.1*u]. Example 6's disturbance and repeated
real uncertainty interconnection are retained, including J in the state
uncertainty input. No extra J belongs in its differentiated z_Delta equation.

Set alpha, nu and rho in Example_7.m. Synthesis uses veryheavy settings,
ddM=3 and separable storage, as in the existing synthesis examples.
At nu=0, the controller is u=K*[x_b;v_ss]. At higher orders, K includes a
filter-state block; its implementation requires the paper's dynamic-filter
controller realization.

## Single point or Figure 7 sweep

Example_7.m now follows Example_6.m's workflow, replacing each analysis call
with PIETOOLS_IQC_controller_synthesis through synthesize_boundary_gain.
The default is runPoleSweep=false, alpha=.5, nu=1, rho=-1.
The single-point result is saved in Example_7_synthesis.mat.

Set runPoleSweep=true for the same grids as Example 6:
alpha=[.03,.27,.46,.60,.71,.80,.89,.96], rho=-logspace(3,-3,25), nu=0:3.
Each point synthesizes its own controller. Static results are reused across
poles. Failed points retain diagnostics and a NaN gain. Results are saved
after each solve in Example_7_Fig7_dual.mat, then plotted in one panel per
filter order with one curve per uncertainty radius. PDF/PNG files are named
fig7_boundary_heat_dual. The sweep starts fresh on each run.

The synthesis executive is dual-only. The boundary actuator, control-effort
output and synthesis storage settings remain as defined above.

## Timing

Run Example_7 once to save the generalized plant and synthesis settings.
Use the single-point mode for this prerequisite.
Example_7_timing loads Example_7_synthesis.mat, then solves a new synthesis
problem for each order i:j. No analysis or simulation is called.

Set repetitions for repeated measurements. By default,
recoverController=false skips numerical controller inversion during timing;
set it to true to include recovery.

- SolverSeconds: solver-reported solinfo.info.cpusec.
- TotalSeconds: construction, LPI assembly, simplification, conversion,
  solving and extraction, plus controller recovery if enabled.
- AssemblySeconds: preparation before the synthesis executive.

Total time excludes toolbox startup and file/plot export. Every trial,
including failures, is checkpointed to CSV/MAT; the completed sweep exports
PDF/PNG plots. The retained timing files contain the nu=0 validation run:
12.99 solver seconds, 25.97 total seconds, gain .71147, accepted=true.

## Required files and saved results

- synthesize_boundary_gain.m: shared synthesis implementation.
- boundary_lifted_basis.m: R0-lifted temporal basis.
- PIETOOLS_IQC_repeated_real.m: repeated-real multiplier.
- compat/: local sparse zero-test and MOSEK-conversion fixes.
- Example_7_synthesis.mat: saved plant, settings and recovered controller;
  required as input to the timing script.
- Example_7_synthesis_timing.mat, .csv and .pdf: timing data and figure.

The previously saved synthesis at alpha=.5, nu=0 returned gain .71147,
numerr=0 and relative residual 3.98e-9. Solver acceptance follows the
existing examples' status, feasibility-ratio and finite-residual checks.


## Figure 7 plot style

The plot uses the shared ../plot_veenman_fig7.m renderer: red curves, tall
logarithmic panels, negative pole labels and alpha | best-gain labels as in
Veenman et al. Figure 7. There is one panel per entry of result.nu, in that
order; nu=0 uses the narrow static strip only when requested. Figure width
adapts to the number of degrees. No legend or point markers are added.
Missing bounds remain gaps. Labels use the minimum of the available sampled
bounds; no interpolation or optimization is performed by the plotter.
An optional second argument [ymin ymax] fixes the shared logarithmic gain
limits; otherwise they adapt to the computed minima. The source paper's
numerical bounds are not substituted for this example's results.
