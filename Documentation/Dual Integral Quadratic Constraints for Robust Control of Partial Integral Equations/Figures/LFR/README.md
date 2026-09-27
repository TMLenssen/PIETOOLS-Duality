# LFR diagram library

The editable PowerPoint is `Graduation_Project_TML/Presentation/LFR - Editable.pptx`.
It contains 19 slides: 15 distinct presentation diagrams, the paired PDE-to-PIE conversion, and paper Figures 2, 3, and 5.
Repeated identical diagrams across PDF overlays are consolidated; the table below maps every occurrence.
All uncertainty block labels `Delta_mu` were changed to `Delta`.

In PowerPoint, select a diagram group and click its label again to edit the text.
You can also right-click > Group > Ungroup to edit blocks, connections, and labels individually.
All 147 block and channel labels across the 19 slides are native PowerPoint equations, including subscripts, transposes, hats, tildes, and dual underlines. Click into a label to edit it with PowerPoint's Equation tools. The diagrams are native PowerPoint shapes, not screenshots.
Arrows are editable paths; they do not automatically reroute when blocks are moved.
Copy a complete group to your current deck to retain its layout.

SVG, transparent PNG, and PDF versions are exported from the same PowerPoint groups.
`Source` contains the modified TikZ and the source mapping. The PPTX is the editable master.
The source PDF is in `Presentation/Archive/A mu Analysis and Synthesis Framework for Infinite Dimensional Systems - Version 3/build/presentation.pdf`.

| Slide | Diagram | Source PDF pages |
|---|---|---|
| 1 | RC circuit - structured uncertainty | 4 |
| 2 | Closed-loop stability interconnection | 5 |
| 3 | Extended plant - performance channels | 6 |
| 4 | Performance objective - compact loop | 7, 8, 9, 10 |
| 5 | ODE - stability | 13 |
| 6 | ODE - performance | 14, 15 |
| 7 | PDE - stability | 41 |
| 8 | PDE - performance | 43, 44 |
| 9 | PIE - conversion output | 44 |
| 10 | Admissible uncertainty - performance | 45, 46, 47, 48, 49 |
| 11 | Uncertainty input-output map | 50, 51, 52 |
| 12 | Dissipativity - stability loop | 53 |
| 13 | Dissipativity - performance loop | 54, 55, 56, 57, 58 |
| 14 | Plant with measured output | 61 |
| 15 | Luenberger observer interconnection | 62 |
| 16 | PDE-to-PIE conversion | 44 |

The following additions refer to figures in the current paper, rather than pages in the archived presentation:

| Slide | Diagram | Paper figure |
|---|---|---|
| 17 | Primal controller interconnection | 2 |
| 18 | Primal and dual dynamic filtering | 3 |
| 19 | Dual controller interconnection | 5 |

Figure 3 uses two rows to keep its equations readable: the primal pair is above the dual pair, with Theorem 2 connecting the two gain blocks. The shared bound is `rho < 1`. Labels, subscripts, transposes, and dual underlines are editable equations. Dashed red uncertainty blocks preserve the paper's dashed outlines.

The additions are drawn from `../Diagrams/primal_dual_controller_interconnections.tex` and `../Diagrams/potapov_ginzburg_commutative_diagram.tex`. `Source/add_paper_figures.py` stages them from the original 16-slide library; `Source/paper_figures.json` maps the new exports.

`Source/math_labels.py` converts the styled-text version of the 19-slide library to native Office Math, preserving every block, connection, and label position. The current PPTX already includes this conversion.
