from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import hashlib,json,importlib.util
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
def first(n,tag):return n.getElementsByTagName(tag)[0]
def shapes(d):return {first(n,'p:cNvPr').getAttribute('name'):n for n in first(d,'p:spTree').childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr')}
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);b=v.b
d49=D.parseString(files['ppt/slides/slide49.xml']);s49=shapes(d49)
video=s49['Simulation - controlled'];xf=first(video,'a:xfrm');off=first(xf,'a:off');ext=first(xf,'a:ext')
x0=int(off.getAttribute('x'))/12700;y0=int(off.getAttribute('y'))/12700;scale=int(ext.getAttribute('cx'))/12700/1920
def point(x,y):return x0+scale*x,y0+scale*y
for i in [14,48]:
 part=f'ppt/slides/slide{i}.xml';d=D.parseString(files[part]);ss=shapes(d);tree=first(d,'p:spTree')
 old=ss['Picture 6'];oldid=first(old,'p:cNvPr').getAttribute('id')
 s=v.Slide();s.i=63000
 s.poly('Aligned electrode lead',[point(x,y) for x,y in [(900,110),(823,110),(799,150),(780,225)]],color='737D85',width=3*scale)
 s.poly('Aligned electrode shaft',[point(790,183),point(780,219)],color='B8B8B8',width=12*scale)
 s.poly('Aligned electrode contact',[point(783,207),point(780,219)],color='E3BF24',width=12*scale)
 for xml in s.parts:
  n=D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
  tree.insertBefore(d.importNode(n,True),old)
 tree.removeChild(old)
 # The question-mark controller occupies the same box as K on the controlled slide.
 box=ss['Controller K block'];sourcexf=first(s49['Controller K block'],'a:xfrm')
 oldxf=first(box,'a:xfrm');oldxf.parentNode.replaceChild(d.importNode(sourcexf,True),oldxf)
 for target in list(d.getElementsByTagName('p:spTgt')):
  if target.getAttribute('spid')==oldid:target.setAttribute('spid','63001')
 for el in d.getElementsByTagName('p:bldP'):
  if el.getAttribute('spid')==oldid:el.setAttribute('spid','63001')
 files[part]=d.toxml(encoding='utf-8')
tree=first(d49,'p:spTree');removed=set()
for name in ['Editable video label: u: control','External pulse legend']:
 n=s49[name];removed.add(first(n,'p:cNvPr').getAttribute('id'));tree.removeChild(n)
for target in list(d49.getElementsByTagName('p:spTgt')):
 if target.getAttribute('spid') in removed:
  n=target
  while n and getattr(n,'tagName','')!='p:par':n=n.parentNode
  if n and n.parentNode:n.parentNode.removeChild(n)
for el in list(d49.getElementsByTagName('p:bldP')):
 if el.getAttribute('spid') in removed:el.parentNode.removeChild(el)
# White slide-native covers remove the old swatches without disturbing the
# existing media poster, playback settings, or the editable labels above it.
for j,yy in enumerate([545,590]):
 xx,yy=point(220,yy-5)
 xml=f'<p:sp>{b.nv(64000+j,"Remove duplicate legend swatch "+str(j))}<p:spPr>{b.xf(xx,yy,70*scale,32*scale)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{b.fill("FFFFFF")}<a:ln><a:noFill/></a:ln></p:spPr></p:sp>'
 n=D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
 tree.appendChild(d49.importNode(n,True))
files['ppt/slides/slide49.xml']=d49.toxml(encoding='utf-8')
assert {n for n in original if files[n]!=original[n]}=={'ppt/slides/slide14.xml','ppt/slides/slide48.xml','ppt/slides/slide49.xml'}
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
(B/'install.ps1').write_text((B.parent/'slide48_legends/install.ps1').read_text().replace('slide 48 input legend and hand still','electrode alignment and duplicate legend removal'))
print('Removed the duplicate diagram legend and aligned the electrode lead, shaft, contact, and controller box on slides 14, 48, and 49.')
