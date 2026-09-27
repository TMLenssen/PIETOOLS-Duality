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
def norm(m,x): return m.d(tilde(m,x),'‖','‖')
def sq(m,x): return m.sup(x,m.r('2',plain=True))
def norm2(m,x): return sq(m,norm(m,x))
def expansion(m,sign):
    return sq(m,m.r('v'))+sq(m,m.r('a'))+m.r(sign+'2vab')+m.r('+')+sq(m,m.r('b'))
d=D.parseString(files['ppt/slides/slide37.xml']); tree=d.getElementsByTagName('p:spTree')[0]
ids=[int(n.getAttribute('id')) for n in d.getElementsByTagName('p:cNvPr')]
for n in list(tree.childNodes):
    if n.nodeType!=1: continue
    nv=n.getElementsByTagName('p:cNvPr'); name=nv[0].getAttribute('name') if nv else ''
    if name=='Pointwise inequality': tree.removeChild(n)
    if name=='Energy inequality':
        # Preserve the user's actual integral equation, changing only size/position.
        for pr in n.getElementsByTagName('a:rPr'):
            if pr.hasAttribute('sz'): pr.setAttribute('sz','1900')
        for pr in n.getElementsByTagName('a:endParaRPr'):
            if pr.hasAttribute('sz'): pr.setAttribute('sz','1900')
        for xf in n.getElementsByTagName('a:xfrm'):
            off=xf.getElementsByTagName('a:off')[0]; ext=xf.getElementsByTagName('a:ext')[0]
            off.setAttribute('y',str(round((333-19*1.4)*12700)))
            ext.setAttribute('cy',str(round(19*2.8*12700)))
for n in list(d.documentElement.childNodes):
    if n.nodeType==1 and n.tagName=='p:timing': d.documentElement.removeChild(n)
s=v.Slide(); s.i=max(ids)+10
s.equation('Substitute signals',360,204,lambda m:norm2(m,'z')+m.r('−')+norm2(m,'w')+m.r('=')+sq(m,m.d(m.r('va+b')))+m.r('−')+sq(m,m.d(m.r('va−b'))),19,w=670)
s.equation('Expand squares',360,233,lambda m:m.r('=')+m.d(expansion(m,'+'))+m.r('−')+m.d(expansion(m,'−')),19,w=670)
s.equation('Cancel matching terms',360,260,lambda m:m.r('=4vab≥0'),22,w=650,color=v.GREEN)
s.equation('Pointwise inequality',360,289,lambda m:norm2(m,'w')+m.r('≤')+norm2(m,'z')+m.r('  ⇒  ')+norm(m,'w')+m.r('≤')+norm(m,'z'),21,w=650)
for prefix,uri in b.NS.items(): d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:
    n=D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
    tree.appendChild(d.importNode(n,True))
files['ppt/slides/slide37.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
    for n,val in files.items(): z.writestr(n,val)
print('Preserved current slide wording and integral, and added substitution, expansion, cancellation, and norm comparison.')
