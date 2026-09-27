from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import hashlib,json,re
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest()}))
d=D.parseString(files['ppt/slides/slide41.xml'])
def first(n,t):return n.getElementsByTagName(t)[0]
def frag(xml):return D.parseString('<root xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'+xml+'</root>').documentElement.firstChild
tree=first(d,'p:spTree'); timing=first(d,'p:timing')
size=first(D.parseString(files['ppt/presentation.xml']),'p:sldSz'); sw=int(size.getAttribute('cx')); sh=int(size.getAttribute('cy'))
ident=max(int(n.getAttribute('id')) for n in d.getElementsByTagName('p:cNvPr'))+1
tid=max(int(n.getAttribute('id')) for n in timing.getElementsByTagName('p:cTn'))+1
main=next(n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='mainSeq')
groups=next(n for n in main.childNodes if getattr(n,'tagName','')=='p:childTnLst')
last=[n for n in groups.childNodes if n.nodeType==1][-1]
inner=first(first(first(first(last,'p:cTn'),'p:childTnLst'),'p:cTn'),'p:childTnLst')
positions={}; boxes=[]
for label in ['Primal','Dual']:
 n=next(n for n in tree.childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr') and first(n,'p:cNvPr').getAttribute('name')==label+' final inequality')
 sid=first(n,'p:cNvPr').getAttribute('id'); xf=first(n,'a:xfrm'); off=first(xf,'a:off'); ext=first(xf,'a:ext')
 motion=next(m for m in timing.getElementsByTagName('p:animMotion') if first(m,'p:spTgt').getAttribute('spid')==sid)
 coords=re.search(r'L\s+([-\d.Ee+]+)\s+([-\d.Ee+]+)',motion.getAttribute('path'))
 dx=float(coords[1])*sw; dy=float(coords[2])*sh
 x=int(off.getAttribute('x'))+dx; y=int(off.getAttribute('y'))+dy
 positions[sid]=(round(x),round(y))
 w=int(ext.getAttribute('cx')); h=int(ext.getAttribute('cy'))
 bx=round(x+w/2-80*12700); by=round(y+1*12700); bw=160*12700; bh=round(h+5*12700)
 box=frag(f'<p:sp><p:nvSpPr><p:cNvPr id="{ident}" name="{label} final inequality red box"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="{bx}" y="{by}"/><a:ext cx="{bw}" cy="{bh}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln w="25400"><a:solidFill><a:srgbClr val="C81919"/></a:solidFill></a:ln></p:spPr></p:sp>')
 tree.appendChild(d.importNode(box,True))
 effect=frag(f'<p:par><p:cTn id="{tid}" presetID="10" presetClass="entr" presetSubtype="0" fill="hold" nodeType="withEffect"><p:stCondLst><p:cond delay="550"/></p:stCondLst><p:childTnLst><p:set><p:cBhvr><p:cTn id="{tid+1}" dur="1" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="{ident}"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr><p:to><p:strVal val="visible"/></p:to></p:set><p:animEffect transition="in" filter="fade"><p:cBhvr><p:cTn id="{tid+2}" dur="350"/><p:tgtEl><p:spTgt spid="{ident}"/></p:tgtEl></p:cBhvr></p:animEffect></p:childTnLst></p:cTn></p:par>')
 inner.appendChild(d.importNode(effect,True));boxes.append(ident);ident+=1;tid+=3
files['ppt/slides/slide41.xml']=d.toxml(encoding='utf-8')
assert [n for n in files if files[n]!=original[n]]==['ppt/slides/slide41.xml']
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'final.pptx',files)
# Preview the final animation state at the actual motion endpoints.
dd=D.parseString(files['ppt/slides/slide41.xml']); st=first(dd,'p:spTree')
hidden={t.getAttribute('spid') for n in dd.getElementsByTagName('p:cTn') if n.getAttribute('presetClass')=='exit' for t in n.getElementsByTagName('p:spTgt')}
for n in list(st.childNodes):
 if n.nodeType!=1 or not n.getElementsByTagName('p:cNvPr'):continue
 sid=first(n,'p:cNvPr').getAttribute('id')
 if sid in hidden:st.removeChild(n);continue
 if sid in positions:
  for xf in n.getElementsByTagName('a:xfrm'):
   o=first(xf,'a:off');o.setAttribute('x',str(positions[sid][0]));o.setAttribute('y',str(positions[sid][1]))
for n in list(dd.getElementsByTagName('p:timing')):n.parentNode.removeChild(n)
ff=files.copy();ff['ppt/slides/slide41.xml']=dd.toxml(encoding='utf-8');write(B/'preview.pptx',ff)
print('Added theme-red boxes at both motion endpoints; 350 ms fade starts 50 ms after the 500 ms movement.')
