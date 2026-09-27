from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
B=Path(__file__).resolve().parent
with ZipFile(B/'final.pptx') as z:files={n:z.read(n) for n in z.namelist()}
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
for stage in range(6):
 d=D.parseString(files['ppt/slides/slide43.xml']);tree=d.getElementsByTagName('p:spTree')[0]
 for n in list(tree.childNodes):
  if n.nodeType!=1 or not n.getElementsByTagName('p:cNvPr'):continue
  name=n.getElementsByTagName('p:cNvPr')[0].getAttribute('name')
  if name.startswith('Transpose ') or name.startswith('Full D ') and not name.startswith(f'Full D {stage} '):tree.removeChild(n)
 for n in list(d.getElementsByTagName('p:timing')):n.parentNode.removeChild(n)
 ff=files.copy();ff['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8');write(B/f'stage{stage}.pptx',ff)
ff=files.copy();p=D.parseString(files['ppt/presentation.xml'])
for i,n in enumerate(list(p.getElementsByTagName('p:sldId')),1):
 if i!=43:n.parentNode.removeChild(n)
ff['ppt/presentation.xml']=p.toxml(encoding='utf-8');write(B/'movie.pptx',ff)
script=(B.parent/'slide43_matrix_animation/verify.ps1').read_text().replace('@(0,1,2,3)','@(0,1,2,3,4,5)').replace('AdvanceTime=17','AdvanceTime=20').replace('$true,17,720','$true,20,720')
(B/'verify.ps1').write_text(script)
