# Parkinsonian GPe–STN sector simulation

Open **STN-GPe sector simulation.html** in a browser for offline playback, pause and scrubbing. The file contains its own simulation data. Use **STN-GPe sector simulation.mp4** in PowerPoint (Insert → Video → This Device). It is a 16:9 white-background H.264 animation. The PNG is a still image. No presentation or speaker notes are modified by these exports.

The simulation reproduces `Figures/STN_GPe/stn_parkinsonian_stimulation.m`: Parkinsonian weights wSG=20, wGS=10.7, wGG=12.3; delays 6, 6, 4 ms; time constants 6 and 14 ms; constant initial history xS=1, xG=0; no external stimulation. It runs for 400 ms, slowed to 12 seconds of playback plus a 2-second hold in the video.

The two activation curves are the actual equilibrium-shifted sigmoids, with equilibrium firing rates (20.44251554, 21.83661841) spikes/s and centered activation inputs (-196.16933348, -285.17380246). The activation outputs w are different from the firing-rate deviations x. The main view contains only a 2-by-2 plot layout: STN nonlinearity, GPe nonlinearity, Response, and Supply function. Response shows both firing-rate deviations. Supply function retains the accumulated supply, explicitly identified by its integral axis label. Plot styling follows the existing PowerPoint response figure: Arial, thin open axes, outward ticks, blue STN and red GPe traces. Playback controls appear on hover or keyboard focus; model explanations remain in this README.

## Tight global bounds

For each channel, beta=max(delta(v)/v). The maximum is at the positive tangency v delta'(v)=delta(v):

| Channel | Sector | Tangency input |
|---|---|---|
| STN | [0, 0.7344121335837432] | 281.66788314129474 |
| GPe | [0, 0.7048314668921489] | 406.9372963710829 |

These are sector bounds, not derivative bounds. The centered sigmoid derivative reaches 1. Its derivative increases to the positive inflection point and then decreases. For positive v, the derivative of the secant slope has the sign of h(v)=v delta'(v)-delta(v); h increases up to the inflection point, then strictly decreases to a negative limit. This gives a unique positive global maximum. For negative v, the secant slope is below delta'(0). The lower global bound is zero, approached in either saturation tail. The numerical bounds use bisection at the unique positive root, checked against a dense independent grid including both tails and the tangency points.

The manuscript's alpha_sec=0.492 is a **local controller certificate**, with the connected intervals containing zero ending at about 119.09 and 201.85. The uncontrolled oscillating trajectory leaves these intervals, so 0.492 cannot be used as a global sector bound in this animation.

## Definition 5 and dissipativity

At every instant, qi(t)=wi(t)(beta_i zi(t)-wi(t)) >= 0. With B=diag(betaS,betaG), choose Psi=I and V=[[0,B/2],[B/2,-I]], acting on [zS,zG,wS,wG]. Its quadratic form is qS+qG. Integrating this pointwise inequality gives the hard IQC for every finite horizon. Zero storage gives dissipativity of Delta with supply qS+qG. The global claim follows from the sector property, not from testing only this trajectory. These are finite-dimensional channels, so supply is summed over channels.

Delta being dissipative does not establish feedback stability. The oscillating network in this example makes the distinction visible.

## Reproduce and check

From the documentation workspace, run:

```powershell
python Presentation/SectorIQC/simulate_stn_gpe.py
```

Requires NumPy, Pillow and ffmpeg for video. The source HTML template is `Presentation/SectorIQC/stn_gpe_interactive.html`.

The delayed network uses RK4 with interpolation, step 10 microseconds. Maximum discrepancy against the saved MATLAB trajectory: 4.89e-12 spikes/s. Halving the time step from 20 to 10 microseconds changes the states by at most 0.00270 spikes/s. The script checks pointwise supply, its quadratic-form expansion, monotonicity of accumulated supply and integration refinement. Final accumulated supplies are 1371.15706 (STN) and 1613.48097 (GPe), with maximum quadrature refinement difference 1.56e-5.

`results.json` records numerical checks; `stn_gpe_sector_data.npz` contains the full trajectory; `supply_history.csv` contains time, channel supplies and their accumulated integrals. Supply here is a mathematical quadratic quantity, not physical energy.


The current PNG, MP4 and browser view are clean, unlabeled artwork at 3840 x 2160. Editable titles, axis labels, tick numbers and legend text are now native text/math overlays on slide 25 of the main PowerPoint. The response uses 0.05 s horizontal ticks and 20 spikes/s vertical ticks, matching slide 13. Rebuild the overlay exports with Presentation/Overlays/render_clean_videos.py and the deck builders in the same directory. The original labeled rendering scripts are retained as source history.


The supply integral is now shown separately for STN (blue) and GPe (red). These curves are accumulated supplies, not storage functions. Sector dissipativity holds with zero storage because each instantaneous supply is nonnegative.
