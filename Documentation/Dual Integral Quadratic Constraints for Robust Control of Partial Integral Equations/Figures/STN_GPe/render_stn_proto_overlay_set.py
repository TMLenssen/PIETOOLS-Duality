"""Render fixed-canvas TikZ diagrams and transparent annotation-only layers.

Run pdflatex twice on Figures/STN_GPe/stn_proto_overlay_set.tex with output in build,
then run this script. Requires PyMuPDF and numpy.
"""
from pathlib import Path
import zipfile
import numpy as np
import pymupdf

root = Path(__file__).resolve().parents[2]
out = root / 'Figures' / 'STN_GPe' / 'stn_proto_aligned'
out.mkdir(exist_ok=True)
names = ['base', 'weights', 'saturation', 'delays', 'electrode', 'pulses', 'pulses_sum',
         'weights_healthy', 'weights_parkinsonian']
n = len(names)
doc = pymupdf.open(root / 'build' / 'stn_proto_overlay_set.pdf')
assert len(doc) == 2 * n
arrays = []
for i, page in enumerate(doc):
    pix = page.get_pixmap(dpi=300, alpha=True)
    arrays.append(np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, 4).copy())
    if i != n:  # The base's annotation-only page is intentionally empty.
        name = names[i % n] + ('_overlay' if i >= n else '') + '.png'
        pix.save(out / name)
assert len({a.shape for a in arrays}) == 1
assert not arrays[n].any()
for i in range(1, n):
    # Allow the two-pixel antialias fringe of an annotation's PDF rendering.
    annotation = arrays[i+n][:,:,3] > 0
    padded = np.pad(annotation,2)
    nearby = np.zeros_like(annotation)
    for dy in range(5):
        for dx in range(5):
            nearby |= padded[dy:dy+annotation.shape[0],dx:dx+annotation.shape[1]]
    untouched = ~nearby
    assert np.array_equal(arrays[i][untouched], arrays[0][untouched]), names[i]
instructions = '''All PNGs have identical dimensions, scale, and circuit coordinates.
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
'''
(out / 'README.txt').write_text(instructions, encoding='utf-8')
with zipfile.ZipFile(root / 'Figures' / 'STN_GPe' / 'stn_proto_aligned.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(out.iterdir()):
        bundle.write(path, path.name)
print(f'Exported {2*n-1} transparent PNGs at {arrays[0].shape[1]} x {arrays[0].shape[0]} pixels.')
print('Verified: circuit pixels are identical outside every annotation layer.')
