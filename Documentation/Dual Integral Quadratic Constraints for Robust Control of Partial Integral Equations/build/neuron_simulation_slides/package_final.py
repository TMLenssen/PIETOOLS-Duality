"""Transplant only edited slides/media; preserve all original video bytes.
Also replace every video poster by frame zero and update slide-number fields.
"""
from pathlib import Path,PurePosixPath
from zipfile import ZipFile
from xml.dom import minidom as D
from copy import copy
import json,posixpath,hashlib,subprocess
B=Path(__file__).resolve().parent
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
def order(z):
 p=D.parseString(z.read('ppt/presentation.xml'));r=D.parseString(z.read('ppt/_rels/presentation.xml.rels'))
 rm={e.getAttribute('Id'):posixpath.normpath('ppt/'+e.getAttribute('Target')) for e in r.getElementsByTagName('Relationship')}
 return [rm[e.getAttribute('r:id')] for e in p.getElementsByTagName('p:sldId')]
def rp(p):return str(PurePosixPath(p).parent/'_rels'/(PurePosixPath(p).name+'.rels'))
def rels(z,p):return D.parseString(z.read(rp(p)))
def freshid(d):return 'rId'+str(max([int(e.getAttribute('Id')[3:]) for e in d.getElementsByTagName('Relationship')]+[0])+1)
def addrel(doc,rid,kind,target):
 e=doc.createElement('Relationship');e.setAttribute('Id',rid);e.setAttribute('Type',R+'/'+kind);e.setAttribute('Target',target);doc.documentElement.appendChild(e)
def updatenumber(d,num):
 for fld in d.getElementsByTagName('a:fld'):
  if fld.getAttribute('type')=='slidenum':
   for t in fld.getElementsByTagName('a:t'):
    if t.firstChild:t.firstChild.data=str(num)
 for shape in d.getElementsByTagName('p:sp'):
  names=shape.getElementsByTagName('p:cNvPr')
  if names and names[0].getAttribute('name').startswith('Slide Number Placeholder'):
   for t in shape.getElementsByTagName('a:t'):
    if t.firstChild:t.firstChild.data=str(num)

meta=json.loads((B/'source.json').read_text(encoding='utf-8-sig'))
assert hashlib.sha256(Path(meta['source']).read_bytes()).hexdigest().upper()==meta['hash'],'Source deck changed during editing'
with ZipFile(B/'source_exact.pptx') as src,ZipFile(B/'com-edited.pptx') as stage:
 original={n:src.read(n) for n in src.namelist()};files=dict(original);before=order(src);after=order(stage)
 assert len(after)==len(before)+1==50
 newpart='ppt/slides/slide'+str(max(int(PurePosixPath(p).stem[5:]) for p in before)+1)+'.xml'
 dest={4:before[3],13:before[12],14:before[13],15:newpart}
 for num,target in dest.items():
  p=after[num-1];d=D.parseString(stage.read(p));rr=rels(stage,p)
  old=rels(src,before[(14 if num==15 else num)-1])
  layout=next(e.getAttribute('Target') for e in old.getElementsByTagName('Relationship') if e.getAttribute('Type').endswith('/slideLayout'))
  media_map={}
  for e in list(rr.getElementsByTagName('Relationship')):
   kind=e.getAttribute('Type').rsplit('/',1)[-1]
   if kind=='slideLayout':e.setAttribute('Target',layout)
   elif kind in ['image','video','media','audio']:
    assert e.getAttribute('TargetMode')!='External'
    path=posixpath.normpath(str(PurePosixPath(p).parent)+'/'+e.getAttribute('Target'))
    if path not in media_map:
     new=f'ppt/media/neurosim_s{num}_{len(media_map)+1}'+PurePosixPath(path).suffix
     assert new not in original;files[new]=stage.read(path);media_map[path]=new
    e.setAttribute('Target','../media/'+PurePosixPath(media_map[path]).name)
   elif kind=='notesSlide':rr.documentElement.removeChild(e)
   elif e.getAttribute('TargetMode')=='External':pass
   else:raise RuntimeError('Unexpected edited-slide relationship: '+kind)
  if num!=15:
   for e in old.getElementsByTagName('Relationship'):
    if e.getAttribute('Type').endswith('/notesSlide'):
     clone=rr.importNode(e,True);clone.setAttribute('Id',freshid(rr));rr.documentElement.appendChild(clone)
  updatenumber(d,num)
  files[target]=d.toxml(encoding='UTF-8');files[rp(target)]=rr.toxml(encoding='UTF-8')

 # Insert the additional controlled example immediately after original slide 14.
 pd=D.parseString(files['ppt/presentation.xml']);pr=D.parseString(files['ppt/_rels/presentation.xml.rels'])
 rid=freshid(pr);addrel(pr,rid,'slide',newpart.removeprefix('ppt/'))
 entries=list(pd.getElementsByTagName('p:sldId'));node=pd.createElement('p:sldId')
 node.setAttribute('id',str(max(int(e.getAttribute('id')) for e in entries)+1));node.setAttributeNS(R,'r:id',rid)
 entries[14].parentNode.insertBefore(node,entries[14])
 files['ppt/presentation.xml']=pd.toxml(encoding='UTF-8');files['ppt/_rels/presentation.xml.rels']=pr.toxml(encoding='UTF-8')
 types=D.parseString(files['[Content_Types].xml']);e=types.createElement('Override');e.setAttribute('PartName','/'+newpart);e.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');types.documentElement.appendChild(e)
 defaults={e.getAttribute('Extension') for e in types.getElementsByTagName('Default')}
 for ext,ct in [('png','image/png'),('mp4','video/mp4')]:
  if ext not in defaults:
   e=types.createElement('Default');e.setAttribute('Extension',ext);e.setAttribute('ContentType',ct);types.documentElement.appendChild(e)
 files['[Content_Types].xml']=types.toxml(encoding='UTF-8')
 finalorder=before[:14]+[newpart]+before[14:]
 for ordinal,p in enumerate(finalorder,1):
  d=D.parseString(files[p]);before_xml=d.toxml();updatenumber(d,ordinal)
  if d.toxml()!=before_xml:files[p]=d.toxml(encoding='UTF-8')

 # Every poster uses the actual decoded first frame, including the four new films.
 entries=json.loads((B/'existing_posters.json').read_text())
 for num,name in [(4,'delta'),(13,'healthy'),(14,'parkinsonian'),(15,'controlled')]:
  poster=B/(name+'-decoded-first.png')
  subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(B/(name+'.mp4')),'-vf','select=eq(n\\,0)','-frames:v','1',str(poster)],check=True)
  d=D.parseString(files[dest[num]])
  pic=next(pic for pic in d.getElementsByTagName('p:pic') if pic.getElementsByTagName('a:videoFile'))
  sid=pic.getElementsByTagName('p:cNvPr')[0].getAttribute('id')
  entries.append(dict(slide=num,part=dest[num],shape_id=sid,name=name,poster=poster.name))
 for i,item in enumerate(entries):
  p=item['part'];d=D.parseString(files[p]);rr=D.parseString(files[rp(p)])
  pic=next(e for e in d.getElementsByTagName('p:pic') if e.getElementsByTagName('p:cNvPr')[0].getAttribute('id')==item['shape_id'])
  assert pic.getElementsByTagName('a:videoFile')
  rid=freshid(rr);new=f'ppt/media/neurosim_firstframe_{i+1}.png';files[new]=(B/item['poster']).read_bytes()
  addrel(rr,rid,'image','../media/'+PurePosixPath(new).name)
  for blip in pic.getElementsByTagName('a:blip'):blip.setAttributeNS(R,'r:embed',rid)
  files[p]=d.toxml(encoding='UTF-8');files[rp(p)]=rr.toxml(encoding='UTF-8')
  item['final_slide']=finalorder.index(p)+1;item['embedded_poster']=new
 (B/'poster_manifest.json').write_text(json.dumps(entries,indent=2))

 # All original embedded footage remains intact. Edits to other slides are only
 # slide-number fields and the five requested video posters.
 for p in original:
  if p.startswith('ppt/media/'):assert files[p]==original[p],p
  if p.startswith('ppt/slides/') and p.endswith('.xml') and p not in dest.values():
   a=D.parseString(original[p]);b=D.parseString(files[p])
   updatenumber(a,finalorder.index(p)+1)
   for item in entries:
    if item['part']==p:
     for adoc in [a,b]:
      pic=next(e for e in adoc.getElementsByTagName('p:pic') if e.getElementsByTagName('p:cNvPr')[0].getAttribute('id')==item['shape_id'])
      for blip in pic.getElementsByTagName('a:blip'):blip.setAttributeNS(R,'r:embed','POSTER')
   assert a.toxml()==b.toxml(),'Unexpected change outside requested slides: '+p
 with ZipFile(B/'final.pptx','w') as out:
  for info in src.infolist():out.writestr(copy(info),files.pop(info.filename))
  for name,data in files.items():out.writestr(name,data)
 print('Packaged 50 slides; 4 new videos; all 9 video posters use frame zero.')
 print('Original media preserved; other slide changes restricted to numbering and requested posters.')
