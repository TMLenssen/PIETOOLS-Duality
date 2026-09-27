from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
B=Path(__file__).resolve().parent
with ZipFile(B/'final.pptx') as z:files={n:z.read(n) for n in z.namelist()}
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
for mode in ['morph','result']:
 d=D.parseString(files['ppt/slides/slide43.xml']);tree=d.getElementsByTagName('p:spTree')[0]
 base={'Title 1','Footer Placeholder 2','Slide Number Placeholder 3','Original filter heading','Dual filter heading','!!Primal filter matrix','!!Dual filter matrix'}
 for n in list(tree.childNodes):
  if n.nodeType!=1 or not n.getElementsByTagName('p:cNvPr') or n.tagName=='p:nvGrpSpPr':continue
  name=n.getElementsByTagName('p:cNvPr')[0].getAttribute('name')
  if name not in base and not (mode=='result' and (name.startswith('Full D 5 ') or name in ['Full dual operation box','Dual operation steps'])):tree.removeChild(n)
 for n in list(d.getElementsByTagName('p:timing')):n.parentNode.removeChild(n)
 ff=files.copy();ff['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
 if mode=='morph':
  p=D.parseString(ff['ppt/presentation.xml'])
  for i,n in enumerate(list(p.getElementsByTagName('p:sldId')),1):
   if i not in [42,43]:n.parentNode.removeChild(n)
  ff['ppt/presentation.xml']=p.toxml(encoding='utf-8')
 write(B/(mode+'.pptx'),ff)
