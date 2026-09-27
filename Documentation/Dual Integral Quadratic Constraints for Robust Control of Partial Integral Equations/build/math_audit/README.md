# Full presentation rendering review

Reviewed PowerPoint renders of all 50 slides against the available source figures.
The source deck is preserved in `source.pptx`; `changes.json` records corrected slides.

Corrections:

- Slide 4: rebuilt both boundary conditions as complete editable equations;
  rebuilt spatial labels; sorted the six uncertainty legends by descending delta,
  matching the final trajectories from top to bottom. Regenerated only the delta
  video's legend swatches, preserving sample sequence, simulation, speed and curves.
- Slides 7–12 and 19: replaced PDF-extracted mathematical fragments with semantic
  equations on the original clean artwork. Restored summation operators, proper
  delay/weight/activation subscripts, stimulation labels and consistently sized signs.
  Source: `Figures/STN_GPe/stn_proto_overlay_set.tex`. PDF extraction had converted
  the summation glyph to the literal letter X.
- Slides 13–15: matched sign sizes and relative anatomical positions to the source
  figures; restored condition descriptions and weights (healthy: 19.0, 1.12, 6.60;
  Parkinsonian: 20.0, 10.7, 12.3). Disturbance labels now use true subscripts.
  All additions are editable text or equations. Videos and dynamics are unchanged.
- Slide 38: restored missing primal filtered-output labels.
- Corrected repeated literal slide numbers and the activation-function typo.

Verification: all 50 slides exported through PowerPoint; affected equations and
figure alignment inspected at full resolution. Internal package relationships and
active shape IDs validated. The original nine videos and immediate autoplay on
4 and 13–15 retained. First-frame posters retained; slide 4's poster regenerated
from its updated first video frame. The plain solid K block is preserved.

Scripts: `render.py delta`, `fix.py`, `export.ps1 final.pptx`, `verify_deck.ps1`.
`install_final.ps1` checks the source hash and archives it before installing.
