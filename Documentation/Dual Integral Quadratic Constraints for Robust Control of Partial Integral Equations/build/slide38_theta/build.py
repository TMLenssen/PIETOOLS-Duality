from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import importlib.util

B=Path(__file__).resolve().parent; ROOT=B.parents[1]
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec); spec.loader.exec_module(v); b=v.b
d=D.parseString(files['ppt/slides/slide38.xml']); tree=d.getElementsByTagName('p:spTree')[0]
s=v.Slide(); s.i=max(int(n.getAttribute('id')) for n in d.getElementsByTagName('p:cNvPr'))+100
def label(name,x,y,text,size=18,w=365,color=v.INK,bold=False):
    s.label(name,x,y,text,size,color,w,bold)
    s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
def matrix(m,rows): return m.d(m.matrix([[m.r(x) for x in row] for row in rows]),'[',']')
label('Theta summary title',496,46,'A suitable Θ depends on Δ',22,w=376,bold=True)
label('Theta example caption',496,88,'For the sector we just analysed:',16,w=376,color=v.GRAY)
s.equation('Derived static Theta',496,130,lambda m:m.r('Θ')+m.d(m.r('v'))+m.r('=')+matrix(m,[['v','1'],['v','−1']])+matrix(m,[['0.735','−1'],['0','1']]),21,w=380)
s.equation('Positive Theta parameter',496,177,lambda m:m.r('v>0'),18,w=365)
items=[
 ('Specific uncertainty',220,'This static Θ describes Δ',244,'in the sector [0, 0.735].'),
 ('Analyse uncertainty',281,'Analyse each Δ to find',305,'a suitable Θ.'),
 ('Dynamic Theta',342,'Θ can also be dynamic,',366,'with its own internal states.'),
]
for name,y,line,y2,line2 in items:
    s.label(name+' bullet',316,y,'•',18,'C81919',w=12)
    label(name,509,y,line,17,w=360)
    label(name+' continuation',509,y2,line2,17,w=360)
for prefix,uri in b.NS.items(): d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:
    n=D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
    tree.appendChild(d.importNode(n,True))
files['ppt/slides/slide38.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
    for n,val in files.items(): z.writestr(n,val)
print('Added the derived static Theta and three bullets; existing diagram and footer preserved.')
