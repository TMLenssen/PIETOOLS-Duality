from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import hashlib,json,importlib.util
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);b=v.b
s=v.Slide();s.i=51000
lines=[('1. Dual operation',112,20,'C81919',True),('Construct D(Θ) so the primal and dual',149,16,'252529',False),('systems satisfy equivalent',173,16,'252529',False),('dissipativity constraints.',197,16,'252529',False),('2. Robust controller synthesis',260,20,'C81919',True),('Apply this equivalence to formulate',297,16,'252529',False),('robust controller synthesis conditions.',321,16,'252529',False)]
for i,(text,y,size,color,bold) in enumerate(lines):
 s.label(f'!!Contribution line {i}',496,y,text,size,color,w=376,bold=bold)
 s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
for slide,dx in [(47,0),(46,436)]:
 part=f'ppt/slides/slide{slide}.xml';d=D.parseString(files[part]);tree=d.getElementsByTagName('p:spTree')[0]
 for xml in s.parts:
  n=D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
  for xf in n.getElementsByTagName('a:xfrm'):
   off=xf.getElementsByTagName('a:off')[0];off.setAttribute('x',str(int(off.getAttribute('x'))+round(dx*12700)))
  tree.appendChild(d.importNode(n,True))
 files[part]=d.toxml(encoding='utf-8')
assert {n for n in original if original[n]!=files[n]}=={'ppt/slides/slide46.xml','ppt/slides/slide47.xml'}
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'final.pptx',files)
p=D.parseString(files['ppt/presentation.xml'])
for i,n in enumerate(list(p.getElementsByTagName('p:sldId')),1):
 if i not in [46,47]:n.parentNode.removeChild(n)
preview=files.copy();preview['ppt/presentation.xml']=p.toxml(encoding='utf-8');write(B/'preview.pptx',preview)
(B/'install.ps1').write_text((B.parent/'slides44_47_slide/install.ps1').read_text().replace('slides 44-47 sliding motion','slide 47 contributions'))
print('Added two contributions with matched off-screen entry positions to preserve the continuous push.')
