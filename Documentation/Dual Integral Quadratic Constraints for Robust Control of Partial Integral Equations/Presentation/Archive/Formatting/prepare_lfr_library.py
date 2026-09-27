from pathlib import Path
import json,re
B=Path(__file__).parent/'lfr_library'
SOURCE=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\A mu Analysis and Synthesis Framework for Infinite Dimensional Systems - Version 3\Presentation')
rows=json.loads((B/'source_calls.json').read_text())
macros=(SOURCE/'tikz_figures.tex').read_text(encoding='utf-8')
macros=macros[macros.index(r'\newif\iftmllfrinput'):macros.index(r'\newcommand{\piecakefigure}')]
macros=macros.replace('draw=black','draw=ink').replace('uncertainty draw=black','uncertainty draw=scarlet').replace('uncertainty text=black','uncertainty text=scarlet').replace('uncertainty fill=inkGhost','uncertainty fill=paperSoft')
macros=macros.replace('rounded corners=3pt','rounded corners=1.5pt').replace('rounded corners=7pt','rounded corners=2pt').replace('rounded corners=5pt','rounded corners=1.5pt')
macros=macros.replace('obsuncertainty/.style={\n      draw=ink,','obsuncertainty/.style={\n      draw=scarlet,\n      text=scarlet,')
macros=macros.replace('fill=paperSoft,\n      align=center,','fill=paper,\n      align=center,')
(B/'lfr_macros.tex').write_text(macros,encoding='utf-8')
preamble=r'''\documentclass[tikz,border=6pt,multi=diagram]{standalone}
\usepackage{fontspec}
\usepackage{amsmath,amssymb,bm}
\IfFontExistsTF{Aptos}{\setmainfont{Aptos}\setsansfont{Aptos}}{\setmainfont{Arial}\setsansfont{Arial}}
\newcommand{\sansface}{\sffamily}
\newcommand{\monoface}{\sffamily}
\newcommand{\bmat}[1]{\begin{bmatrix}#1\end{bmatrix}}
\newcommand{\mbf}[1]{\bm{#1}}
\definecolor{paper}{HTML}{FFFFFF}
\definecolor{paperSoft}{HTML}{F3F4F5}
\definecolor{ink}{HTML}{252529}
\definecolor{inkMute}{HTML}{747B82}
\definecolor{scarlet}{HTML}{C81919}
\colorlet{scarletDeep}{scarlet}
\colorlet{inkGhost}{ink!12!paper}
\usetikzlibrary{calc,positioning,backgrounds,shapes.geometric,arrows.meta,shapes,arrows,fit,decorations.pathreplacing}
\newenvironment{diagram}{\color{ink}\sffamily}{}
\input{lfr_macros.tex}
\begin{document}
'''
names=['RC circuit - structured uncertainty','Closed-loop stability interconnection','Extended plant - performance channels','Performance objective - compact loop','ODE - stability','ODE - performance','PDE - stability','PDE - performance','PDE - conversion input','PIE - conversion output','Admissible uncertainty - performance','Structured singular value - performance','Uncertainty input-output map','Dissipativity - stability loop','Dissipativity - performance loop','Dissipativity - performance certificate','Plant with measured output','Luenberger observer interconnection']
pages=[[4],[5],[6],[7,8,9,10],[13],[14,15],[41],[43],[44],[44],[45,46,47],[48,49],[50,51,52],[53],[54,55],[56,57,58],[61],[62]]
chunks=[]
for row,name,pp in zip(rows,names,pages):
    opts=row['options'].strip().replace(r'{\Delta}_\mu',r'\Delta').replace(r'\Delta_{\mu}',r'\Delta').replace(r'\Delta_\mu',r'\Delta')
    row.update(name=name,pdf_pages=pp,options=opts)
    assert r'\mu' not in opts
    chunks.append('\\begin{diagram}\n\\'+row['macro']+'['+opts+']\n\\end{diagram}\n')
(B/'diagrams.tex').write_text(preamble+'\n'.join(chunks)+'\\end{document}\n',encoding='utf-8')
(B/'diagrams.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('Prepared',len(rows),'source diagram occurrences.')
