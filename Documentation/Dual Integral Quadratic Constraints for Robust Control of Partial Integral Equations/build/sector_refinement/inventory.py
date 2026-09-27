from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
import json,posixpath
B=Path(__file__).resolve().parent
def read(path):
 with ZipFile(path) as z:return {n:z.read(n) for n in z.namelist()}
def elements(n,t):return list(n.getElementsByTagName(t))
f=read(B/'source.pptx');r=D.parseString(f['ppt/_rels/presentation.xml.rels']);rm={n.getAttribute('Id'):posixpath.normpath('ppt/'+n.getAttribute('Target')) for n in elements(r,'Relationship')}
parts=[rm[n.getAttribute('r:id')] for n in elements(D.parseString(f['ppt/presentation.xml']),'p:sldId')];(B/'parts.json').write_text(json.dumps(parts))
for label,payload in [('current37',f[parts[36]]),('original37',read(B.parent/'sector_dissipativity_story/source.pptx')['ppt/slides/slide37.xml'])]:
 d=D.parseString(payload)
 def walk(n,depth=0):
  for c in n.childNodes:
   if c.nodeType!=1:continue
   if c.tagName in ['p:sp','p:grpSp','p:pic','p:cxnSp']:
    nv=elements(c,'p:cNvPr')[0];xf=elements(c,'a:xfrm');xx=xf[0].toxml() if xf else ''
    ts=''.join(t.firstChild.data for t in elements(c,'a:t') if t.firstChild)
    print(' '*depth,nv.getAttribute('id'),nv.getAttribute('name'),ts[:90],xx[:220])
   if c.tagName=='p:grpSp':walk(c,depth+1)
 print(label);walk(elements(d,'p:spTree')[0])
print('Current slides',len(parts),parts[32:41])
