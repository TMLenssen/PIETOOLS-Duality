from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
import posixpath,json
B=Path(__file__).resolve().parent
def els(n,t):return list(n.getElementsByTagName(t))
def first(n,t):return els(n,t)[0]
def text(n):return ''.join(t.firstChild.data for tag in ['a:t','m:t'] for t in els(n,tag) if t.firstChild)
def rels(f,p):
 key=posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
 return {r.getAttribute('Id'):posixpath.normpath(posixpath.dirname(p)+'/'+r.getAttribute('Target')) for r in els(D.parseString(f[key]),'Relationship')}
with ZipFile(B/'source.pptx') as z:f={n:z.read(n) for n in z.namelist()}
rm=rels(f,'ppt/presentation.xml');parts=[rm[s.getAttribute('r:id')] for s in els(D.parseString(f['ppt/presentation.xml']),'p:sldId')]
report=[]
for i,p in enumerate(parts,1):
 d=D.parseString(f[p]);shapes=[];rr=rels(f,p)
 for s in first(d,'p:spTree').childNodes:
  if s.nodeType!=1 or not els(s,'p:cNvPr'):continue
  nv=first(s,'p:cNvPr');bl=els(s,'a:blip');xf=els(s,'a:xfrm');box=[]
  if xf:
   box=[int(first(xf[0],'a:off').getAttribute(k))/12700 for k in ['x','y']]+[int(first(xf[0],'a:ext').getAttribute(k))/12700 for k in ['cx','cy']]
  shapes.append(dict(id=nv.getAttribute('id'),name=nv.getAttribute('name'),text=text(s),box=box,media=rr.get(bl[0].getAttribute('r:embed')) if bl else None))
 report.append(dict(slide=i,part=p,shapes=shapes))
(B/'inventory.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
for s in report:
 print(s['slide'],s['part'],str([(x['id'],x['name'],x['text'][:95],x['media']) for x in s['shapes'] if x['id']!='1']).encode('ascii','backslashreplace').decode())
