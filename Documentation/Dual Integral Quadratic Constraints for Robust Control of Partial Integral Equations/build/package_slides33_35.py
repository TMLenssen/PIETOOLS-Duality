from zipfile import ZipFile
from pathlib import Path
from xml.dom import minidom as D
from copy import copy
import json,hashlib
b=Path('build/slides33_34')
def order(z):
 d=D.parseString(z.read('ppt/presentation.xml'));rr=D.parseString(z.read('ppt/_rels/presentation.xml.rels'))
 rm={e.getAttribute('Id'):'ppt/'+e.getAttribute('Target') for e in rr.getElementsByTagName('Relationship')}
 return [rm[e.getAttribute('r:id')] for e in d.getElementsByTagName('p:sldId')]
with ZipFile(b/'staged.pptx') as base,ZipFile(b/'animated.pptx') as animated,ZipFile(b/'final.pptx','w') as out:
 targets={n:order(animated)[n-1] for n in [33,34,35]};ours={33:'ppt/slides/slide33.xml',34:'ppt/slides/slide34.xml',35:'ppt/slides/slide45.xml'};edits={}
 for n,path in ours.items():
  d=D.parseString(base.read(path));a=D.parseString(animated.read(targets[n]));timing=a.getElementsByTagName('p:timing')[0]
  shapeids={e.getAttribute('id') for e in d.getElementsByTagName('p:cNvPr')}
  targetsids={e.getAttribute('spid') for e in timing.getElementsByTagName('p:spTgt')}
  assert targetsids <= shapeids,(n,targetsids-shapeids)
  root=d.documentElement;ext=next((e for e in root.childNodes if e.nodeType==e.ELEMENT_NODE and e.tagName=='p:extLst'),None)
  t=d.importNode(timing,True)
  if ext:root.insertBefore(t,ext)
  else:root.appendChild(t)
  edits[path]=d.toxml(encoding='UTF-8')
 for info in base.infolist():out.writestr(copy(info),edits.get(info.filename,base.read(info.filename)))
with ZipFile(b/'original.pptx') as original,ZipFile(b/'final.pptx') as final:
 changed=[name for name in original.namelist() if original.read(name)!=final.read(name)]
 print('Changed existing package parts:',changed)
 assert set(changed)=={'ppt/slides/slide33.xml','ppt/slides/slide34.xml','ppt/presentation.xml','ppt/_rels/presentation.xml.rels','[Content_Types].xml'}
 print('All other existing slides and every original media file are byte-for-byte unchanged.')
meta=json.loads((b/'source.json').read_text(encoding='utf-8-sig'));assert hashlib.sha256(Path(meta['source']).read_bytes()).hexdigest().upper()==meta['hash'],'The source deck changed'
print('Source hash unchanged; final presentation ready.')
