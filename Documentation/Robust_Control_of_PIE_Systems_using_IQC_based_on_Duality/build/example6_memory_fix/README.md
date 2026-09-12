# Example 6: coupled heat equations

## Run

- Example_6.m: matched primal and dual robust-gain analyses.
- Example_6_nominal.m: matched primal/dual nominal or known-parameter gain
  analysis for the unshifted unit-diffusion plant.
- Example_6_timing.m: one primal and one dual timing run for each
  $\nu=0,1,2,3$ at fixed $\alpha=0.5$ and $\rho=-1$; it writes MAT/CSV
  results and the manuscript's LaTeX timing table.
- plot_Example_6.m: plot the gain-versus-pole sweep.
- example.tex: plant equations and multiplier description.

The main scripts contain their own plant and filter construction.
All runs use lpisettings('veryheavy'). In Example_6.m, alpha is the fixed
uncertainty radius, nu the temporal multiplier order, and rho its negative
pole. With runPoleSweep=false, the script runs one matched primal--dual
proof of concept. Set runPoleSweep=true to evaluate the complete, identical
grid on both sides. The squared gain is optimized directly, and the script
saves side-specific result files.

The uncertainty is one constant real scalar repeated across both spatial
channels and all positions. The multiplier has static block
[alpha^2 Q, alpha S; -alpha S, -Q], with Q positive and S skew-adjoint.
Its temporal basis is lifted to R0 PI operators. The hard-IQC family is a
sufficient subclass of the source paper's frequency-domain multiplier search.

## Retained results

- Example_6_*.mat and Example_6_timing_dual.csv: saved user runs.
- proof_of_concept.mat: consolidated certificates and diagnostics for the
  static dual, dynamic dual and dynamic primal proof-of-concept cases.
- proof_of_concept.csv and .pdf: comparison table and figure.

The previously saved robust and nominal bounds were generated for the older
shifted plant and must not be used for the unshifted unit-diffusion model.
The historical static proof-of-concept candidate is approximately 4.42343;
its saved acceptance flag is false because the former helper imposed an
extra 1e-5 relative-residual cutoff. These saved diagnostics are distinct
from the settings in the current main script.

## Required support

PIETOOLS_IQC_repeated_real.m supplies the multiplier.
compat/lpi_eq.m and compat/Sedumi2Mosek.m contain the local sparse
compatibility fixes needed by the robust analysis. The installed toolbox
is unchanged. Old helper copies, validation scripts, duplicate per-case
proof files and diagnostic logs have been removed.


## Figure 7 plot style

The plotting entry point requires matched primal and dual grids. It exports
only example1_primal.pdf, example1_dual.pdf, and example1_difference.pdf directly
to the manuscript Figures directory. The first two use the shared
../plot_veenman_fig7.m renderer: red curves, tall
logarithmic panels, negative pole labels and alpha | best-gain labels as in
Veenman et al. Figure 7. There is one panel per entry of result.nu, in that
order; nu=0 uses the narrow static strip only when requested. Figure width
adapts to the number of degrees. No legend or point markers are added.
Missing bounds remain gaps. Labels use the minimum of the available sampled
bounds; no interpolation or optimization is performed by the plotter.
An optional second argument [ymin ymax] fixes the shared logarithmic gain
limits; otherwise they adapt to the computed minima. The source paper's
numerical bounds are not substituted for this example's results.
The third plot stacks one pointwise gamma_primal-gamma_dual error axis per
filter order. Each axis has its own symmetric zero-centered linear scale; a
logarithmic axis is not valid for signed differences.

## Memory during sweeps

Example_6.m runs each analysis sequentially in a fresh MATLAB process using
Example_6_run_point.m and Example_6_worker.m. When that process exits, Windows
reclaims its MATLAB and MOSEK allocations before the next point starts. This
prevents allocator or solver memory from accumulating over a long sweep,
without changing polynomial degrees, the model, or solver settings. The
tradeoff is MATLAB startup overhead for each point; no Parallel Computing
Toolbox is needed. A single solve still needs its usual peak memory.

Sweep diagnostics retain gains and solver information only. Successful full
certificates are saved in a unique run directory under Example_6_certificates;
each diagnostic's certificateFile points to a MAT file containing result.storage
and result.multiplier. Load that file when a certificate is needed. Existing
saved results remain readable by plot_Example_6.m. Temporary worker input/output
files are removed after each point, including on worker failure.

Each completed point checkpoints its side-specific Example_6_Fig7_*.mat file.
The new snapshot is fully written to a temporary file before replacing the
previous checkpoint. With resumeSweep=true (the default), restarting skips
completed points if the plant, settings, side, and grids match. Older result
files without checkpoint metadata are not treated as resumable. Solver failures
with exceptions are recorded but retried on restart; solved infeasible points
are marked complete. Set resumeSweep=false to recompute the entire grid.
Pilot runs also save the partial comparison after each side finishes.
