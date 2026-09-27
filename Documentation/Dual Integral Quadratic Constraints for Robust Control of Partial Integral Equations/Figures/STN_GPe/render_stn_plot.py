"""Render a MATLAB vector PDF to a genuinely transparent PNG at 300 dpi.

Usage: python Figures/STN_GPe/render_stn_plot.py path/to/plot.pdf
Requires PyMuPDF. The PNG is written beside the supplied PDF.
"""
from pathlib import Path
import sys
import pymupdf

source = Path(sys.argv[1])
with pymupdf.open(source) as document:
    assert len(document) == 1, 'Expected a single-page plot.'
    pixmap = document[0].get_pixmap(dpi=300, alpha=True)
    assert min(pixmap.samples[3::4]) == 0, 'PDF background is not transparent.'
    pixmap.save(source.with_suffix('.png'))
print(f'Saved transparent PNG: {source.with_suffix(".png")}')
