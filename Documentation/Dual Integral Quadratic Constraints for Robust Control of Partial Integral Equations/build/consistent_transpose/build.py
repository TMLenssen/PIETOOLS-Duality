from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import json,hashlib,re
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
def first(n,tag):return n.getElementsByTagName(tag)[0]
docs={};changes={}
for part in files:
 if not re.fullmatch(r'ppt/slides/slide\d+.xml',part):continue
 d=D.parseString(files[part]);count=0
 for n in d.getElementsByTagName('m:t'):
  if not n.firstChild:continue
  val=n.firstChild.data
  is_transpose_T=False
  if val=='T':
   par=n.parentNode
   while par and getattr(par,'tagName','') not in ['m:sup','m:oMath']:par=par.parentNode
   is_transpose_T=bool(par and getattr(par,'tagName','')=='m:sup' and getattr(par.parentNode,'tagName','')=='m:sSup')
  if val in ['*','∗','⋆'] or is_transpose_T:n.firstChild.data='⊤';count+=1
 if count:docs[part]=d;changes[part]=count
for i in [42,43]:
 part=f'ppt/slides/slide{i}.xml'
 if part not in docs:docs[part]=D.parseString(files[part])
def shapes(d):return {first(n,'p:cNvPr').getAttribute('name'):n for n in first(d,'p:spTree').childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr')}
d42=docs['ppt/slides/slide42.xml'];d43=docs['ppt/slides/slide43.xml'];s42=shapes(d42);s43=shapes(d43)
for name in ['!!Primal filter matrix','!!Dual filter matrix']:
 a=s42[name];b=s43[name]
 old=first(b,'p:txBody');old.parentNode.replaceChild(d43.importNode(first(a,'p:txBody'),True),old)
 # Exact shape size and column alignment; only the vertical position changes during Morph.
 src=first(a,'a:xfrm');ext=first(src,'a:ext');x=first(src,'a:off').getAttribute('x');h=int(ext.getAttribute('cy'))
 for xf in b.getElementsByTagName('a:xfrm'):
  first(xf,'a:off').setAttribute('x',x);first(xf,'a:off').setAttribute('y',str(round(125*12700-h/2)))
  for dim in ['cx','cy']:first(xf,'a:ext').setAttribute(dim,ext.getAttribute(dim))
 for nv in b.getElementsByTagName('p:cNvPr'):
  for oldext in list(nv.getElementsByTagName('a:extLst')):nv.removeChild(oldext)
  nv.appendChild(d43.importNode(first(first(a,'p:cNvPr'),'a:extLst'),True))
for name,cx in [('Original filter heading',190),('Dual filter heading',530)]:
 if name in s43:
  xf=first(s43[name],'a:xfrm');w=int(first(xf,'a:ext').getAttribute('cx'))
  first(xf,'a:off').setAttribute('x',str(round(cx*12700-w/2)))
# Match the previous slide's upright Theta and italic identity in the derivation too.
for n in d43.getElementsByTagName('m:t'):
 if not n.firstChild:continue
 if n.firstChild.data=='I':n.firstChild.data='𝐼'
 if n.firstChild.data in ['Θ','𝛩']:
  n.firstChild.data='Θ';run=n.parentNode
  rpr=next((x for x in run.childNodes if getattr(x,'tagName','')=='m:rPr'),None)
  if rpr is None:rpr=d43.createElement('m:rPr');run.insertBefore(rpr,run.firstChild)
  sty=next((x for x in rpr.childNodes if getattr(x,'tagName','')=='m:sty'),None)
  if sty is None:sty=d43.createElement('m:sty');rpr.appendChild(sty)
  sty.setAttribute('m:val','p')
for part,d in docs.items():files[part]=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
meta={'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId')),'parts':sorted(docs),'changes':changes}
(B/'source.json').write_text(json.dumps(meta))
(B/'render.ps1').write_text((B.parent/'slide43_top/render.ps1').read_text())
(B/'install.ps1').write_text((B.parent/'slide43_continuous/install.ps1').read_text().replace('slide 43 continuous mirrored derivation','consistent transpose notation and Morph'))
print('Transpose symbols updated:',changes)
print('Filter equations on 42 and 43 now share the same font, notation, dimensions, column positions, and Morph identity.')
