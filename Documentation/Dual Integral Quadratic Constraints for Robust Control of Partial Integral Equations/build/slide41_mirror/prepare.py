from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
import hashlib,json
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:
 count=len(D.parseString(z.read('ppt/presentation.xml')).getElementsByTagName('p:sldId'))
 d=D.parseString(z.read('ppt/slides/slide41.xml'))
 (B/'slide41.xml').write_text(d.toprettyxml(),encoding='utf8')
 for n in d.getElementsByTagName('p:spTree')[0].childNodes:
  if n.nodeType!=1 or not n.getElementsByTagName('p:cNvPr'): continue
  print('SHAPE',n.getElementsByTagName('p:cNvPr')[0].getAttribute('id'),n.getElementsByTagName('p:cNvPr')[0].getAttribute('name'))
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':count}))
