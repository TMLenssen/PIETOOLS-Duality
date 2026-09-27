from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import hashlib,json
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
def first(n,tag):return n.getElementsByTagName(tag)[0]
docs={i:D.parseString(files[f'ppt/slides/slide{i}.xml']) for i in range(44,48)}
maps={44:{},45:{},46:{},47:{}}
for a,bb,tag,ids in [(44,45,'PIE',[20002,20005,20007,20012,20013,30019,30034]),(45,46,'Analysis',[2,3,7,8,30066]),(46,47,'Synthesis',[6,11,13,15,19])]:
 for ident in ids:
  maps[a][str(ident)]=maps[bb][str(ident)]=f'!!Flow {tag} {ident}'
for i,d in docs.items():
 for nv in d.getElementsByTagName('p:cNvPr'):
  ident=nv.getAttribute('id')
  if ident in maps[i]:nv.setAttribute('name',maps[i][ident])
 # Match common connection arrows independently of panel movement.
 for oldid,newname in ([(20008,'!!Flow forward arrow'),(20010,'!!Flow return arrow'),(20011,'!!Flow solutions')] if i==44 else [(32,'!!Flow forward arrow'),(36,'!!Flow return arrow'),(38,'!!Flow solutions')]):
  for nv in d.getElementsByTagName('p:cNvPr'):
   if nv.getAttribute('id')==str(oldid):nv.setAttribute('name',newname)
 if i>=45:
  for n in list(d.getElementsByTagName('p:transition')):
   if n.parentNode==d.documentElement:d.documentElement.removeChild(n)
  # Native Morph with fade fallback for older PowerPoint versions.
  xml='<root xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><mc:AlternateContent><mc:Choice xmlns:p159="http://schemas.microsoft.com/office/powerpoint/2015/09/main" Requires="p159"><p:transition xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" p14:dur="1200"><p159:morph option="byObject"/></p:transition></mc:Choice><mc:Fallback><p:transition spd="med"><p:fade/></p:transition></mc:Fallback></mc:AlternateContent></root>'
  node=d.importNode(D.parseString(xml).documentElement.firstChild,True)
  node.setAttribute('xmlns:mc','http://schemas.openxmlformats.org/markup-compatibility/2006')
  before=next((n for n in d.documentElement.childNodes if getattr(n,'tagName','') in ['p:timing','p:extLst']),None)
  if before:d.documentElement.insertBefore(node,before)
  else:d.documentElement.appendChild(node)
 files[f'ppt/slides/slide{i}.xml']=d.toxml(encoding='utf-8')
 for tag in ['p:timing']:
  assert [n.toxml() for n in d.getElementsByTagName(tag)]==[n.toxml() for n in D.parseString(original[f'ppt/slides/slide{i}.xml']).getElementsByTagName(tag)]
assert {n for n in original if files[n]!=original[n]}=={f'ppt/slides/slide{i}.xml' for i in range(44,48)}
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'final.pptx',files)
p=D.parseString(files['ppt/presentation.xml'])
for i,n in enumerate(list(p.getElementsByTagName('p:sldId')),1):
 if i not in range(44,48):n.parentNode.removeChild(n)
preview=files.copy();preview['ppt/presentation.xml']=p.toxml(encoding='utf-8');write(B/'preview.pptx',preview)
(B/'install.ps1').write_text((B.parent/'consistent_transpose/install.ps1').read_text().replace('consistent transpose notation and Morph','slides 44-47 continuous panel movement'))
print('Matched each continuing right panel to the next left panel and replaced three Push transitions with 1.2-second Morph.')
