# Editable simulation slides

The 50-slide deck retains all slides outside 2, 4, 13–15 and 27–29 unchanged.
All nine embedded videos use text-free frames with native PowerPoint labels above them.
The cart labels retain their original PowerPoint motion keyframes. Chart titles,
axis labels, tick labels and legends are individually editable.

- Slide 4: same six reproducible random uncertainty samples and exact heat-PDE
  solutions; 18 seconds instead of 36. Previous trajectories remain visible.
  Red indicates a positive dominant eigenvalue after the heating pulse.
- Slides 13–15: delayed connections still use the verified simulation signals
  `weight*x_source(t-s*delay)`. Descriptive prose and live numerical readouts removed.
  The controller uses a solid black K block attached to the STN probe.
- Slides 28–29: upper plots now show the sigmoid derivatives rather than sectors.
  For channel maximum M and shifted input z*, the slope is
  `sech(2*(z*+z)/M)^2`, globally between zero and one. The moving dot follows
  the actual input trajectory. The lower response and Zames–Falb supply plots
  retain their original verified data and multiplier with global slope bound 1.
- All video posters are decoded first frames. Existing autoplay settings remain.

Verification: PowerPoint opened the deck, recognized all nine embedded videos,
and verified immediate autoplay on slides 4 and 13–15. Exported all affected
slides for visual inspection. The neuronal simulation's delay endpoint and
controller stability checks passed. The solid K block, native equation labels,
axis placement and slope plots were inspected in PowerPoint exports.

Reproduction: run `render.py neurons`, `render.py delta`, and `render.py slopes`,
then `package.py` and `verify_deck.ps1`. Input provenance and simulation checks
are retained in the adjacent `neuron_simulation_slides` directory.
