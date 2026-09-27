All PNGs have identical dimensions, scale, and circuit coordinates.
In PowerPoint, give every image the SAME size and position; do not crop.

For swapping complete diagrams, use base.png, weights.png, saturation.png,
delays.png, electrode.png, pulses.png, pulses_sum.png,
weights_healthy.png, and weights_parkinsonian.png.

Healthy and Parkinsonian weights are from Nevado Holgado et al. (2010),
Table 3, DOI: 10.1523/JNEUROSCI.0817-10.2010. These are fitted animal-model
parameters. The source models GPe as one population; Proto is the existing
diagram's label and is used here as a schematic stand-in for GPe.
Connection        Healthy   Parkinsonian
STN -> GPe         19.0       20.0
GPe -> STN          1.12      10.7
GPe -> GPe          6.60      12.3

For incremental overlays, place base.png once and stack *_overlay.png over it.
The overlay files contain ONLY annotations. Use pulses OR pulses_sum, not both.
Each annotation layer is intended to be displayed individually over the base.
Weight and delay labels occupy the same connection-centered positions.
All backgrounds are transparent. These diagrams are rebuilt from a shared
TikZ template; do not mix them with the earlier independently generated PNGs.

Source: ../stn_proto_overlay_set.tex
Renderer: ../render_stn_proto_overlay_set.py
