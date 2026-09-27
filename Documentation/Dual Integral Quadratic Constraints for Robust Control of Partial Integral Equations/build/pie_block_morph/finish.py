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
files=load(B/'staged.pptx');anim=load(B/'animated.pptx');source=load(B/'source.pptx');parts=json.loads((B/'parts.json').read_text())
def rp(p):return posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def target(p,r):return posixpath.normpath(posixpath.dirname(p)+'/'+r.getAttribute('Target'))
for i in [20,21]:
 p=parts[i-1];ap=f'ppt/slides/slide{i}.xml';dd=D.parseString(anim[ap]);namespaces(dd)
 rd=D.parseString(files[rp(p)]);existing=els(rd,'Relationship');ar=els(D.parseString(anim[rp(ap)]),'Relationship');mp={}
 for c in els(dd,'p:cTn'):
  if c.getAttribute('presetID')=='0' and c.hasAttribute('presetClass'):c.setAttribute('presetClass','path')
 for r in ar:
  typ=r.getAttribute('Type').split('/')[-1]
  if typ in ['slideLayout','notesSlide']:
   mp[r.getAttribute('Id')]=next(x.getAttribute('Id') for x in existing if x.getAttribute('Type').endswith('/'+typ));continue
  nr=r.cloneNode(True);rid=f'rIdBlockMorph{i}_{len(mp)}';nr.setAttribute('Id',rid)
  if r.getAttribute('TargetMode')!='External':
   src=target(ap,r);new=f'ppt/media/blockmorph{i}_'+Path(src).name;files[new]=anim[src];nr.setAttribute('Target',posixpath.relpath(new,posixpath.dirname(p)))
  rd.documentElement.appendChild(rd.importNode(nr,True));mp[r.getAttribute('Id')]=rid
 for el in dd.getElementsByTagName('*'):
  for att in ['r:embed','r:link','r:id']:
   val=el.getAttribute(att)
   if val in mp:el.setAttributeNS(b.NS['r'],att,mp[val])
 files[p]=dd.toxml(encoding='utf-8');files[rp(p)]=rd.toxml(encoding='utf-8')
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,v in data.items():z.writestr(n,v)
for i,p in enumerate(parts,1):
 if i not in range(20,26):assert files[p]==source[p],i
for n,v in source.items():
 if n.startswith('ppt/media/'):assert files[n]==v,n
for i in range(20,26):
 dd=D.parseString(files[parts[i-1]])
 for n in list(els(dd,'mc:Fallback')):n.parentNode.removeChild(n)
 ids=[n.getAttribute('id') for n in els(dd,'p:cNvPr')];assert len(ids)==len(set(ids)),(i,'duplicate IDs')
 # Every slide carries the same two Morph identifiers.
 names=[n.getAttribute('name') for n in els(dd,'p:cNvPr')]
 assert names.count('!!PDE block')==names.count('!!PIE block')==1,(i,names)
 for r in els(D.parseString(files[rp(parts[i-1])]),'Relationship'):
  if r.getAttribute('TargetMode')!='External':assert target(parts[i-1],r) in files
write(B/'final.pptx',files)
for name,keep in [('operators',[20,21]),('pillars',[24,25])]:
 ff=files.copy();pp=D.parseString(ff['ppt/presentation.xml']);sl=first(pp,'p:sldIdLst')
 for i,n in enumerate(list(els(pp,'p:sldId')),1):
  if i not in keep:sl.removeChild(n)
 ff['ppt/presentation.xml']=pp.toxml(encoding='utf-8');write(B/(name+'-check.pptx'),ff)
print('Preserved all other slides and original media. Ready for transition playback checks.')
