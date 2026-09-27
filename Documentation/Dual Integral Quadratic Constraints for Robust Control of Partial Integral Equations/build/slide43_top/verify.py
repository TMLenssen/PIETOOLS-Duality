from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
B=Path(__file__).resolve().parent
with ZipFile(B/'final.pptx') as z:files={n:z.read(n) for n in z.namelist()}
with ZipFile(B/'source.pptx') as z:old=D.parseString(z.read('ppt/slides/slide43.xml'))
d=D.parseString(files['ppt/slides/slide43.xml'])
assert old.getElementsByTagName('p:timing')[0].toxml()==d.getElementsByTagName('p:timing')[0].toxml()
assert old.getElementsByTagName('p159:morph')[0].toxml()==d.getElementsByTagName('p159:morph')[0].toxml()
assert not any(n.firstChild and n.firstChild.data in ['*','∗','⋆'] for n in d.getElementsByTagName('m:t'))
tree=d.getElementsByTagName('p:spTree')[0]
for n in list(tree.childNodes):
 if n.nodeType!=1 or not n.getElementsByTagName('p:cNvPr'):continue
 name=n.getElementsByTagName('p:cNvPr')[0].getAttribute('name')
 if name.startswith('Transpose ') or name.startswith('Full D ') and not name.startswith('Full D 5 '):tree.removeChild(n)
for n in list(d.getElementsByTagName('p:timing')):n.parentNode.removeChild(n)
files['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'preview.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
print('All star symbols replaced; four-second timing and Morph verified identical.')
