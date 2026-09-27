from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
B=Path(__file__).resolve().parent
with ZipFile(B/'final.pptx') as z:files={n:z.read(n) for n in z.namelist()}
comparison={'Transpose comparison','Transpose explanation'}
result={'Dual operation arrow','Dual operation arrow label','Dual operation steps','Dual operation result box','Dual operation definition','Dual operation evaluation'}
for stage,remove in [('initial',comparison|result),('comparison',result),('result',comparison)]:
 d=D.parseString(files['ppt/slides/slide43.xml']);tree=d.getElementsByTagName('p:spTree')[0]
 for n in list(tree.childNodes):
  if n.nodeType==1 and n.getElementsByTagName('p:cNvPr') and n.getElementsByTagName('p:cNvPr')[0].getAttribute('name') in remove:tree.removeChild(n)
 for n in list(d.getElementsByTagName('p:timing')):n.parentNode.removeChild(n)
 ff=files.copy();ff['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
 with ZipFile(B/(stage+'.pptx'),'w',ZIP_DEFLATED) as z:
  for n,val in ff.items():z.writestr(n,val)
