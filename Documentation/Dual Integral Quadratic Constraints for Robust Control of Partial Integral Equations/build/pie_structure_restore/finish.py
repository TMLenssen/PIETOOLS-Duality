from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import sys,json,posixpath,re,copy
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,els,first
from build_video_overlays import namespaces
def load(p):
 with ZipFile(p) as z:return {n:z.read(n) for n in z.namelist()}
files=load(B/'staged.pptx');animated=load(B/'animated.pptx');staged=load(B/'staged.pptx')
rp=lambda p:posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def rels(data,part):return {r.getAttribute('Id'):r for r in els(D.parseString(data[rp(part)]),'Relationship')}
def target(part,r):return posixpath.normpath(posixpath.dirname(part)+'/'+r.getAttribute('Target'))
pr=D.parseString(files['ppt/_rels/presentation.xml.rels']);pres=D.parseString(files['ppt/presentation.xml']);lst=first(pres,'p:sldIdLst')
rm={r.getAttribute('Id'):target('ppt/presentation.xml',r) for r in els(pr,'Relationship')};parts=[rm[s.getAttribute('r:id')] for s in els(pres,'p:sldId')]
def sid(n):return first(n,'p:cNvPr').getAttribute('id')
part=parts[19];ar=rels(animated,'ppt/slides/slide20.xml');fr=D.parseString(files[rp(part)]);existing=rels(files,part)
doc=D.parseString(animated['ppt/slides/slide20.xml']);namespaces(doc)
# Custom motion effects are emphasis/path operations on already visible objects.
# The COM default labels them as entrances, which would hide the source terms.
for c in els(doc,'p:cTn'):
 if c.getAttribute('presetID')=='0' and c.hasAttribute('presetClass'):c.setAttribute('presetClass','path')
mapping={}
for r in ar.values():
 typ=r.getAttribute('Type').split('/')[-1]
 if typ in ['slideLayout','notesSlide']:
  mapping[r.getAttribute('Id')]=next(x.getAttribute('Id') for x in existing.values() if x.getAttribute('Type').endswith('/'+typ));continue
 oldtarget=target('ppt/slides/slide20.xml',r);newtarget='ppt/media/extraction20_'+Path(oldtarget).name
 if r.getAttribute('TargetMode')!='External':files[newtarget]=animated[oldtarget]
 nr=r.cloneNode(True);rid='rIdExtractFinal'+str(len(mapping)+100);nr.setAttribute('Id',rid)
 if r.getAttribute('TargetMode')!='External':nr.setAttribute('Target',posixpath.relpath(newtarget,posixpath.dirname(part)))
 fr.documentElement.appendChild(fr.importNode(nr,True));mapping[r.getAttribute('Id')]=rid
for el in doc.getElementsByTagName('*'):
 for attr in ['r:embed','r:link','r:id']:
  val=el.getAttribute(attr)
  if val in mapping:el.setAttributeNS(b.NS['r'],attr,mapping[val])
files[part]=doc.toxml(encoding='utf8').replace(b'encoding="utf8"',b'encoding="utf-8"');files[rp(part)]=fr.toxml(encoding='utf-8')
note=next(target(part,r) for r in existing.values() if r.getAttribute('Type').endswith('/notesSlide'));files[note]=staged[note]


# Copy just the verified transition from COM, retaining the native pillar artwork.
d26=D.parseString(files['ppt/slides/slide26.xml']);a26=D.parseString(animated['ppt/slides/slide26.xml'])
for n in list(d26.documentElement.childNodes):
 if n.nodeType==1 and (n.tagName=='p:transition' or (n.tagName=='mc:AlternateContent' and els(n,'p:transition'))):d26.documentElement.removeChild(n)
for n in a26.documentElement.childNodes:
 if n.nodeType==1 and (n.tagName=='p:transition' or (n.tagName=='mc:AlternateContent' and els(n,'p:transition'))):d26.documentElement.appendChild(d26.importNode(n,True))
for j in range(a26.documentElement.attributes.length):
 at=a26.documentElement.attributes.item(j)
 if at.name.startswith('xmlns:'):d26.documentElement.setAttribute(at.name,at.value)
files['ppt/slides/slide26.xml']=d26.toxml(encoding='utf-8')
source=load(B/'source.pptx')
for n,v in source.items():
 if n.startswith('ppt/media/'):assert files[n]==v,n
for i,p in enumerate(parts,1):
 if i not in range(20,27):assert files[p]==source[p],p
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
 for n,v in files.items():z.writestr(n,v)
vd=files.copy();pp=D.parseString(vd['ppt/presentation.xml']);sl=first(pp,'p:sldIdLst')
for i,node in enumerate(list(els(pp,'p:sldId'))):
 if i!=19:sl.removeChild(node)
vd['ppt/presentation.xml']=pp.toxml(encoding='utf-8')
with ZipFile(B/'playback-check.pptx','w',ZIP_DEFLATED) as z:
 for n,v in vd.items():z.writestr(n,v)
print('Packaged restored slides and PDE extraction; other slides and all original media unchanged.')
