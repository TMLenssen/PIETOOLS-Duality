from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import importlib.util, hashlib, json

B=Path(__file__).resolve().parent; ROOT=B.parents[1]
SOURCE=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=SOURCE.read_bytes(); (B/'source.pptx').write_bytes(raw)
(B/'source.json').write_text(json.dumps({'source':str(SOURCE),'hash':hashlib.sha256(raw).hexdigest()}))
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec); spec.loader.exec_module(v)
b=v.b
def tilde(m,x):
    return '<m:acc><m:accPr><m:chr m:val="̃"/>'+m.ctrl()+'</m:accPr><m:e>'+m.r(x)+'</m:e></m:acc>'
def norm2(m,x,timed=False): return m.sup(m.d(tilde(m,x)+(m.d(m.r('t')) if timed else ''),'‖','‖'),m.r('2',plain=True))
def integral(m,x):
    return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('T')+'</m:sup><m:e>'+norm2(m,x,True)+m.r('dt')+'</m:e></m:nary>'
d=D.parseString(files['ppt/slides/slide37.xml']); tree=d.getElementsByTagName('p:spTree')[0]
ids=[int(n.getAttribute('id')) for n in d.getElementsByTagName('p:cNvPr')]
for n in list(tree.childNodes):
    if n.nodeType!=1: continue
    nv=n.getElementsByTagName('p:cNvPr'); name=nv[0].getAttribute('name') if nv else ''
    if name in ['Supply identity','Delta dissipativity','Dissipativity meaning']: tree.removeChild(n)
for n in list(d.documentElement.childNodes):
    if n.nodeType==1 and n.tagName=='p:timing': d.documentElement.removeChild(n)
s=v.Slide(); s.i=max(ids)+10
s.equation('Pointwise inequality',360,239,lambda m:norm2(m,'w')+m.r('≤')+norm2(m,'z'),27,w=650)
s.equation('Energy inequality',360,313,lambda m:integral(m,'w')+m.r('≤')+integral(m,'z')+m.r(',   ∀T≥0'),24,w=650,color=v.GREEN)
s.label('Energy interpretation',360,369,'The transformed output energy cannot exceed the input energy.',14,v.GREEN,w=670)
for prefix,uri in b.NS.items(): d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:
    n=D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
    tree.appendChild(d.importNode(n,True))
files['ppt/slides/slide37.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
    for n,val in files.items(): z.writestr(n,val)
print('Replaced the supply function with pointwise and integrated squared-norm inequalities.')
