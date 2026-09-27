from pathlib import Path,PurePosixPath
from zipfile import ZipFile
from xml.dom import minidom as D
import subprocess,json,posixpath
B=Path(__file__).resolve().parent
with ZipFile(B/'source_exact.pptx') as z:
 rel=D.parseString(z.read('ppt/_rels/presentation.xml.rels'))
 targets={e.getAttribute('Id'):posixpath.normpath('ppt/'+e.getAttribute('Target')) for e in rel.getElementsByTagName('Relationship')}
 pres=D.parseString(z.read('ppt/presentation.xml'))
 order=[targets[e.getAttribute('r:id')] for e in pres.getElementsByTagName('p:sldId')]
 posters=[]
 for ordinal,part in enumerate(order,1):
  doc=D.parseString(z.read(part))
  if not doc.getElementsByTagName('a:videoFile'):continue
  rp=str(PurePosixPath(part).parent/'_rels'/(PurePosixPath(part).name+'.rels'))
  rr=D.parseString(z.read(rp));rels={e.getAttribute('Id'):e for e in rr.getElementsByTagName('Relationship')}
  for pic in doc.getElementsByTagName('p:pic'):
   vids=pic.getElementsByTagName('a:videoFile')
   if not vids:continue
   c=pic.getElementsByTagName('p:cNvPr')[0];r=rels[vids[0].getAttribute('r:link')]
   assert r.getAttribute('TargetMode')!='External','Linked video requires resolving its external file'
   media=posixpath.normpath(str(PurePosixPath(part).parent)+'/'+r.getAttribute('Target'))
   basename=f'existing-slide{ordinal}-shape{c.getAttribute("id")}'
   video=B/(basename+PurePosixPath(media).suffix);video.write_bytes(z.read(media))
   png=B/(basename+'-first.png')
   subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(video),'-vf','select=eq(n\\,0)','-frames:v','1',str(png)],check=True)
   posters.append(dict(slide=ordinal,part=part,shape_id=c.getAttribute('id'),name=c.getAttribute('name'),media=media,poster=png.name))
 (B/'existing_posters.json').write_text(json.dumps(posters,indent=2))
 print(json.dumps(posters,indent=2))
