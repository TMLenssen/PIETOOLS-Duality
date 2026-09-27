from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import json,hashlib
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
for index,names in [(42,{'Primal filter matrix':'!!Primal filter matrix','Dual filter matrix':'!!Dual filter matrix'}),(43,{'Original filter':'!!Primal filter matrix','Required dual filter':'!!Dual filter matrix'})]:
 part=f'ppt/slides/slide{index}.xml';d=D.parseString(files[part]);changed=set()
 for nv in d.getElementsByTagName('p:cNvPr'):
  name=nv.getAttribute('name')
  if name in names:nv.setAttribute('name',names[name]);changed.add(name)
 assert changed==set(names)
 files[part]=d.toxml(encoding='utf-8')
assert {n for n in original if original[n]!=files[n]}=={'ppt/slides/slide42.xml','ppt/slides/slide43.xml'}
old=D.parseString(original['ppt/slides/slide43.xml']);new=D.parseString(files['ppt/slides/slide43.xml'])
assert old.getElementsByTagName('p:timing')[0].toxml()==new.getElementsByTagName('p:timing')[0].toxml()
assert old.getElementsByTagName('p159:morph')[0].toxml()==new.getElementsByTagName('p159:morph')[0].toxml()
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'final.pptx',files)
# Two-slide movie to check the actual Morph, without the on-click content.
preview=files.copy();p=D.parseString(files['ppt/presentation.xml']);ids=p.getElementsByTagName('p:sldId')
for i,n in enumerate(list(ids),1):
 if i not in (42,43):n.parentNode.removeChild(n)
preview['ppt/presentation.xml']=p.toxml(encoding='utf-8')
d=D.parseString(preview['ppt/slides/slide43.xml']);tree=d.getElementsByTagName('p:spTree')[0]
for n in list(tree.childNodes):
 if n.nodeType!=1 or not n.getElementsByTagName('p:cNvPr'):continue
 name=n.getElementsByTagName('p:cNvPr')[0].getAttribute('name')
 if name.startswith('Transpose ') or name.startswith('Dual operation '):tree.removeChild(n)
for n in list(d.getElementsByTagName('p:timing')):n.parentNode.removeChild(n)
preview['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8');write(B/'preview.pptx',preview)
(B/'install.ps1').write_text((B.parent/'slide43_dual/install.ps1').read_text().replace('slide 43 dual operation','slide 43 Morph matching'))
print('Restored explicit Morph pairing; transition duration, layout, and click animations preserved.')
