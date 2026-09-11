# Example 6: coupled heat equations

## Run

- Example_6.m: robust gain analysis, with side='dual' or 'primal'.
- Example_6_nominal.m: nominal/known-parameter gain analysis.
- plot_Example_6.m: plot the gain-versus-pole sweep.
- example.tex: plant equations and multiplier description.

The main scripts contain their own plant and filter construction.
All runs use lpisettings('veryheavy'). In Example_6.m, alpha is the fixed
uncertainty radius, nu the temporal multiplier order, and rho its negative
pole. Set runPoleSweep=true to run the grids in that script. The squared
gain is optimized directly. Current scripts save side-specific result files.

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

At alpha=.5, nu=1, rho=-1, the saved dynamic bounds are 2.4225533 (dual)
and 2.4225536 (primal). The nominal reference is approximately 1.44725795.
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
