from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import importlib.util, hashlib, json

B=Path(__file__).resolve().parent
ROOT=B.parents[1]
SOURCE=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=SOURCE.read_bytes(); (B/'source.pptx').write_bytes(raw)
(B/'source.json').write_text(json.dumps({'source':str(SOURCE),'hash':hashlib.sha256(raw).hexdigest()}))
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec); spec.loader.exec_module(v)
b=v.b
def run(self,t,c=None,plain=False):
    return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in t)
v.M.r=run
def tilde(m,x):
    return '<m:acc><m:accPr><m:chr m:val="̃"/>'+m.ctrl()+'</m:accPr><m:e>'+m.r(x)+'</m:e></m:acc>'
def square(m,x): return m.sup(x,m.r('2',plain=True))
def matrix(m,rows): return m.d(m.matrix([[m.r(x) for x in row] for row in rows]),'[',']')
def integral(m):
    return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('T')+'</m:sup><m:e>'+m.r('σ')+m.d(m.r('t'))+m.r('dt')+'</m:e></m:nary>'
s=v.Slide(); s.i=8000
def label(name,x,y,text,size=17,w=225,color=v.INK,bold=False):
    s.label(name,x,y,text,size,color,w,bold)
    s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
label('Title',360,45,'Turn the gap product into an energy inequality',25,648,bold=True)
s.equation('Known product',360,82,lambda m:m.r('ab≥0',v.GREEN),18,w=400)
label('Scale explanation',153,119,'1  Scale a',17,234)
s.equation('Positive scaling',483,119,lambda m:m.r('a',v.BLUE)+m.r(' ↦ ')+m.r('va',v.BLUE)+m.r(',   v>0'),22,w=405)
label('Sum difference explanation',153,162,'2  Add and subtract b',17,234)
s.equation('Transformed gaps',483,162,lambda m:tilde(m,'z')+m.r('=va+b,   ')+tilde(m,'w')+m.r('=va−b'),22,w=405)
label('Matrix explanation',153,222,'In matrix form',16,234,color=v.GRAY)
s.equation('Parameterize Theta',483,222,lambda m:m.r('Θ')+m.d(m.r('v'))+m.r('=')+matrix(m,[['v','1'],['v','−1']])+matrix(m,[['β','−1'],['−α','1']]),21,w=405)
s.equation('Supply identity',360,289,lambda m:m.r('σ=')+square(m,tilde(m,'z'))+m.r('−')+square(m,tilde(m,'w'))+m.r('=')+square(m,m.d(m.r('va+b')))+m.r('−')+square(m,m.d(m.r('va−b')))+m.r('=4vab≥0',v.GREEN),20,w=680)
s.equation('Delta dissipativity',360,337,lambda m:integral(m)+m.r('≥0,   ∀T≥0'),20,w=640)
s.label('Dissipativity meaning',360,370,'The transformed output energy cannot exceed the input energy.',14,v.GREEN,w=670)
d=D.parseString(files['ppt/slides/slide37.xml'])
tree=d.getElementsByTagName('p:spTree')[0]
footer=[]
for n in list(tree.childNodes):
    if n.nodeType!=1: continue
    nv=n.getElementsByTagName('p:cNvPr')
    name=nv[0].getAttribute('name') if nv else ''
    if name in ['Footer','Slide number']: footer.append(n.cloneNode(True))
    if n.tagName not in ['p:nvGrpSpPr','p:grpSpPr']: tree.removeChild(n)
for prefix,uri in b.NS.items(): d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:
    node=D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
    tree.appendChild(d.importNode(node,True))
for n in footer: tree.appendChild(n)
for n in list(d.documentElement.childNodes):
    if n.nodeType==1 and n.tagName=='p:timing': d.documentElement.removeChild(n)
files['ppt/slides/slide37.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
    for n,val in files.items(): z.writestr(n,val)
print('Rebuilt slide 37 with editable equations and narrative order.')
