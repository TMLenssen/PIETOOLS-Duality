# Presentation simulations

Slides 13 and 14 replay the original healthy and Parkinsonian STN/GPe trajectories. Slide 15 uses the actual saved sector-IQC controller simulation from the paper, with the matching uncontrolled response as a dashed comparison. These are model simulations, with equilibrium-shifted firing rates; Proto is the diagram's label for the GPe population.

## Dynamics and animation

For fractional position s along a directed interconnection, the animated drive is

`weight * x_source(t - s * delay)`.

STN to GPe: +wSG, delay 6 ms. GPe to STN: -wGS, delay 6 ms. GPe to GPe: -wGG, delay 4 ms. Curve displacement and packet size are bounded display mappings of this drive. No independent periodic animation is used. The same display mapping is used across cases. Motion depicts deviations from the equilibrium, not individual neuronal spikes or cessation of baseline firing. Playback is 40 times slower than physical time.

The controlled example uses the paper's disturbance `[10;-10] sin²(pi(t-.10)/.04)` on 0.10–0.14 s, entering after the nonlinear activations. The same disturbance is used for the uncontrolled comparison. Feedback is active throughout. The controller is the saved synthesized PI state/history feedback, not a substituted proportional controller. Its input/output traces are exported from `stn_gpe_sector_simulation.mat`; the source hash and associated controller file hash are in `verification.json`.

The peak controlled population deviation is 3.319 spikes/s. Both deviations return to numerical zero by the end of the 0.5 s simulation. The saved N=24/32 spatial refinement checks are included in `verification.json`. The control trace is converted to the manuscript units using the existing factor tauS*4600=27.6.

## Slide 4

Six uniform random delta samples from [-0.5,0.5] are generated with seed 20260926 and shown individually, clearing the previous curve. The embedded movie is reproducible; it replays the sampled cases rather than drawing new numbers on each visit.

The Dirichlet heat equation is solved using 200 odd eigenfunctions, with convergence checked against 400. The original heater is 2 on [0,8) seconds, then zero. A curve turns red after the heater switches off exactly when the dominant PDE eigenvalue is positive. The stability boundary is delta=0.194784176. `delta_verification.json` and `delta_trajectories.npz` retain the parameters and trajectories.

## Playback and posters

The four new movies are embedded H.264 MP4s with immediate automatic playback. Slide 4 loops through the six cases. All nine video objects in the completed presentation have posters extracted from actual decoded frame zero. Original video bytes and content outside the requested slides are preserved; later slide numbers are updated for the insertion.

`package_final.py` assembles the deck from the exact original and PowerPoint-generated edited slides. `verify_deck.ps1` checks the final 50-slide deck, all nine embedded videos, and autoplay effects. `poster_manifest.json` records every first-frame replacement. `installed.json` records the installed file and backup.
