from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import sys,posixpath,json
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,els,first
from build_video_overlays import namespaces
def load(p):
 with ZipFile(p) as z:return {n:z.read(n) for n in z.namelist()}
files=load(B/'staged.pptx');anim=load(B/'animated.pptx');source=load(B/'source.pptx');parts=json.loads((B/'output_parts.json').read_text())
def rp(p):return posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def target(p,r):return posixpath.normpath(posixpath.dirname(p)+'/'+r.getAttribute('Target'))
ct=D.parseString(files['[Content_Types].xml']);act=D.parseString(anim['[Content_Types].xml'])
known={r.getAttribute('Extension') for r in els(ct,'Default')}
for r in els(act,'Default'):
 if r.getAttribute('Extension') not in known:ct.documentElement.appendChild(ct.importNode(r,True));known.add(r.getAttribute('Extension'))
for i in [34,35,36,39]:
 p=parts[i-1];ap=f'ppt/slides/slide{i}.xml';dd=D.parseString(anim[ap]);namespaces(dd)
 rd=D.parseString(files[rp(p)]);existing=els(rd,'Relationship');ar=els(D.parseString(anim[rp(ap)]),'Relationship');mp={}
 for c in els(dd,'p:cTn'):
  if c.getAttribute('presetID')=='0' and c.hasAttribute('presetClass'):c.setAttribute('presetClass','path')
 for r in ar:
  typ=r.getAttribute('Type').split('/')[-1]
  if typ in ['slideLayout','notesSlide']:
   mp[r.getAttribute('Id')]=next(x.getAttribute('Id') for x in existing if x.getAttribute('Type').endswith('/'+typ));continue
  nr=r.cloneNode(True);rid=f'rIdSectorRefinement{i}_{len(mp)}';nr.setAttribute('Id',rid)
  if r.getAttribute('TargetMode')!='External':
   src=target(ap,r);new=f'ppt/media/sectorrefinement{i}_'+Path(src).name;files[new]=anim[src];nr.setAttribute('Target',posixpath.relpath(new,posixpath.dirname(p)))
   for override in els(act,'Override'):
    if override.getAttribute('PartName')=='/'+src:
     ov=override.cloneNode(True);ov.setAttribute('PartName','/'+new);ct.documentElement.appendChild(ct.importNode(ov,True))
  rd.documentElement.appendChild(rd.importNode(nr,True));mp[r.getAttribute('Id')]=rid
 for el in dd.getElementsByTagName('*'):
  for att in ['r:embed','r:link','r:id']:
   val=el.getAttribute(att)
   if val in mp:el.setAttributeNS(b.NS['r'],att,mp[val])
 files[p]=dd.toxml(encoding='utf-8');files[rp(p)]=rd.toxml(encoding='utf-8')
files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
for n,v in source.items():
 if n.startswith('ppt/media/'):assert files[n]==v,n
for i,p in enumerate(parts,1):
 dd=D.parseString(files[p])
 for n in list(els(dd,'mc:Fallback')):n.parentNode.removeChild(n)
 ids=[n.getAttribute('id') for n in els(dd,'p:cNvPr')]
 if i in [33,34,35,36,39]:assert len(ids)==len(set(ids)),(i,'duplicate IDs',ids)
 for r in els(D.parseString(files[rp(p)]),'Relationship'):
  if r.getAttribute('TargetMode')!='External':assert target(p,r) in files,(p,r.toxml())
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,v in data.items():z.writestr(n,v)
write(B/'final.pptx',files)
for name,keep in [('zoom',[33,34,35]),('gaps',[35]),('filter',[36]),('stability',[38,39])]:
 ff=files.copy();pp=D.parseString(ff['ppt/presentation.xml']);sl=first(pp,'p:sldIdLst')
 for i,n in enumerate(list(els(pp,'p:sldId')),1):
  if i not in keep:sl.removeChild(n)
 ff['ppt/presentation.xml']=pp.toxml(encoding='utf-8');write(B/(name+'-check.pptx'),ff)
print('Packaged 55 slides with original media preserved and validated slide relationships.')
