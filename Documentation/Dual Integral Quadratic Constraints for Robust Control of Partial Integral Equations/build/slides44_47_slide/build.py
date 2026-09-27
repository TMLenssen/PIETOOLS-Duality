from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import hashlib,json,posixpath
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
def first(n,tag):return n.getElementsByTagName(tag)[0]
docs={i:D.parseString(files[f'ppt/slides/slide{i}.xml']) for i in range(44,48)}
rels={i:D.parseString(files[f'ppt/slides/_rels/slide{i}.xml.rels']) for i in range(44,48)}
def shapes(i):return {int(first(n,'p:cNvPr').getAttribute('id')):n for n in first(docs[i],'p:spTree').childNodes if n.nodeType==1 and n.tagName!='p:nvGrpSpPr' and n.getElementsByTagName('p:cNvPr')}
ss={i:shapes(i) for i in docs}
left={44:[20001,20003,20006,30001,30016,39990,30037,30039,30040,39991],45:[20002,20005,20007,20012,20013,30019,30034],46:[2,3,7,8,30066]}
right={45:[2,3,7,8,30066],46:[6,11,13,15,19],47:[9]}
center={44:[20008,20009,20010,20011],45:[32,34,36,38],46:[32,34,36,38]}
# Keep matched panels as the same objects. Give each central explanation its own
# identity so it travels out with its stage and the next one slides into place.
for i in center:
 for ident in center[i]:
  for nv in ss[i][ident].getElementsByTagName('p:cNvPr'):nv.setAttribute('name',f'!!Sliding center {i} {ident}')
nextids={i:max(int(n.getAttribute('id')) for n in docs[i].getElementsByTagName('p:cNvPr'))+100 for i in docs}
def clone(src,dst,ident,dx):
 node=ss[src][ident]
 name=first(node,'p:cNvPr').getAttribute('name')
 if not name.startswith('!!'):
  name=f'!!Sliding content {src} {ident}'
  for nv in node.getElementsByTagName('p:cNvPr'):
   if nv.getAttribute('id')==str(ident):nv.setAttribute('name',name)
 nn=docs[dst].importNode(node,True);idmap={}
 for nv in nn.getElementsByTagName('p:cNvPr'):
  old=nv.getAttribute('id')
  if old not in idmap:idmap[old]=str(nextids[dst]);nextids[dst]+=1
  nv.setAttribute('id',idmap[old])
 for tag in ['a:stCxn','a:endCxn']:
  for el in nn.getElementsByTagName(tag):
   if el.getAttribute('id') in idmap:el.setAttribute('id',idmap[el.getAttribute('id')])
 # Shift only the outer transform of each alternate-content branch or group.
 for xf in nn.getElementsByTagName('a:xfrm'):
  parent=xf.parentNode;isnested=False
  while parent and parent!=nn:
   if getattr(parent,'tagName','')=='p:grpSp' and parent!=nn:isnested=True;break
   parent=parent.parentNode
  if isnested:continue
  off=first(xf,'a:off');off.setAttribute('x',str(int(off.getAttribute('x'))+round(dx*12700)))
  if nn.tagName=='p:grpSp':break
 rmap={}
 for el in nn.getElementsByTagName('*'):
  for attr in ['r:id','r:embed','r:link']:
   if not el.hasAttribute(attr):continue
   rid=el.getAttribute(attr)
   if rid not in rmap:
    rr=next(r for r in rels[src].getElementsByTagName('Relationship') if r.getAttribute('Id')==rid)
    nr=rels[dst].importNode(rr,True);newid='rIdSlideFlow'+str(len(rels[dst].getElementsByTagName('Relationship'))+100)
    nr.setAttribute('Id',newid);rels[dst].documentElement.appendChild(nr);rmap[rid]=newid
   el.setAttribute(attr,rmap[rid])
 first(docs[dst],'p:spTree').appendChild(nn)
for src in [44,45,46]:
 dst=src+1
 for ident in left[src]+center[src]:clone(src,dst,ident,-436)
 for ident in right[dst]+center.get(dst,[]):clone(dst,src,ident,436)
# Standardize each traveling panel to the same displacement (45 was 0.2pt off).
for ident in left[45]:
 for xf in ss[45][ident].getElementsByTagName('a:xfrm'):
  parent=xf.parentNode
  if ss[45][ident].tagName=='p:grpSp' and parent.tagName!='p:grpSpPr':continue
  off=first(xf,'a:off');off.setAttribute('x',str(int(off.getAttribute('x'))+round(.2*12700)))
  if ss[45][ident].tagName=='p:grpSp':break
# Slide numbers stay in the footer instead of traveling with a panel.
for xf in ss[47][17].getElementsByTagName('a:xfrm'):first(xf,'a:off').setAttribute('x',str(620*12700))
for i,d in docs.items():
 files[f'ppt/slides/slide{i}.xml']=d.toxml(encoding='utf-8')
 files[f'ppt/slides/_rels/slide{i}.xml.rels']=rels[i].toxml(encoding='utf-8')
 assert [n.toxml() for n in d.getElementsByTagName('p:timing')]==[n.toxml() for n in D.parseString(original[f'ppt/slides/slide{i}.xml']).getElementsByTagName('p:timing')]
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'final.pptx',files)
p=D.parseString(files['ppt/presentation.xml'])
for i,n in enumerate(list(p.getElementsByTagName('p:sldId')),1):
 if i not in range(44,48):n.parentNode.removeChild(n)
preview=files.copy();preview['ppt/presentation.xml']=p.toxml(encoding='utf-8');write(B/'preview.pptx',preview)
(B/'verify.ps1').write_text((B.parent/'slides44_47_flow/verify.ps1').read_text())
(B/'install.ps1').write_text((B.parent/'slides44_47_flow/install.ps1').read_text().replace('slides 44-47 continuous panel movement','slides 44-47 sliding motion'))
print('Added matched off-slide positions: old content exits left, continuing panel slides left once, new content enters from right.')
