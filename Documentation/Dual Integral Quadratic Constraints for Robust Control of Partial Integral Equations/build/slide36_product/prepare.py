from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import hashlib, json

B = Path(__file__).resolve().parent
SOURCE = next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw = SOURCE.read_bytes()
(B/'source.pptx').write_bytes(raw)
(B/'source.json').write_text(json.dumps({'source':str(SOURCE),'hash':hashlib.sha256(raw).hexdigest()}))
with ZipFile(B/'source.pptx') as z:
    files = {n:z.read(n) for n in z.namelist()}
d = D.parseString(files['ppt/slides/slide36.xml'])
tree = d.getElementsByTagName('p:spTree')[0]
for n in list(tree.childNodes):
    if n.nodeType != 1: continue
    nv = n.getElementsByTagName('p:cNvPr')
    name = nv[0].getAttribute('name') if nv else ''
    if name.startswith('Readout ') or name in ['Signed gaps with numerical readouts', 'Smooth sector gaps - click to play']:
        tree.removeChild(n)
for n in list(d.documentElement.childNodes):
    if n.nodeType==1 and (n.tagName in ['p:timing','p:transition'] or (n.tagName=='mc:AlternateContent' and n.getElementsByTagName('p:transition'))):
        d.documentElement.removeChild(n)
files['ppt/slides/slide36.xml'] = d.toxml(encoding='utf-8')
with ZipFile(B/'static.pptx','w',ZIP_DEFLATED) as z:
    for n,v in files.items(): z.writestr(n,v)
print('Prepared static slide, with original definitions and sector plot preserved.')
