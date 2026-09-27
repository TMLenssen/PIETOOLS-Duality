from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import json,hashlib,ast,importlib.util
from xml.sax.saxutils import escape
B=Path(__file__).resolve().parent; ROOT=B.parents[1]
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec); spec.loader.exec_module(v); b=v.b
for node in ast.parse((B.parent/'slide41_mirror/build.py').read_text(encoding='utf8')).body:
 if isinstance(node,ast.FunctionDef):exec(compile(ast.Module(body=[node],type_ignores=[]),'<helper>','exec'))
v.M.r=run
d=D.parseString(files['ppt/slides/slide41.xml']); tree=first(d,'p:spTree')
shapes={first(n,'p:cNvPr').getAttribute('name'):n for n in tree.childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr')}
ident=max(int(n.getAttribute('id')) for n in d.getElementsByTagName('p:cNvPr'))+10
mapping={}; added=[]; relations=[]
for dual,prefix in [(False,'Primal '),(True,'Dual ')]:
 old=shapes[prefix+'energy inequality']; xf=first(old,'a:xfrm'); off=first(xf,'a:off'); ext=first(xf,'a:ext')
 x,y=[int(off.getAttribute(a))/12700 for a in ['x','y']]; w,h=[int(ext.getAttribute(a))/12700 for a in ['cx','cy']]
 s=v.Slide(); s.i=ident
 s.equation(prefix+'filtered inequality',x+w/2,y+h/2,lambda m,q=dual:norm2(m,sig(m,'u',q,True))+m.r('≤')+norm2(m,sig(m,'y',q,True)),16,w=w)
 n=frag(s.parts[0]); tree.appendChild(d.importNode(n,True)); newid=first(n,'p:cNvPr').getAttribute('id'); ident=s.i+10
 mapping[first(old,'p:cNvPr').getAttribute('id')]=newid; added.append(newid)
 relations.append(first(shapes[prefix+'controller relation'],'p:cNvPr').getAttribute('id'))
timing=first(d,'p:timing'); main=next(n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='mainSeq')
groups=next(n for n in main.childNodes if getattr(n,'tagName','')=='p:childTnLst')
original=next(g for g in groups.childNodes if g.nodeType==1 and any(t.getAttribute('spid') in mapping for t in g.getElementsByTagName('p:spTgt')))
expanded=original.cloneNode(True)
effectlist=first(first(original,'p:cTn'),'p:childTnLst')
inner=first(first(effectlist,'p:cTn'),'p:childTnLst')
for e in list(inner.childNodes):
 if e.nodeType!=1:continue
 targets=e.getElementsByTagName('p:spTgt')
 if any(t.getAttribute('spid') in relations for t in targets):inner.removeChild(e);continue
 for t in targets:
  if t.getAttribute('spid') in mapping:t.setAttribute('spid',mapping[t.getAttribute('spid')])
nextid=max(int(n.getAttribute('id')) for n in timing.getElementsByTagName('p:cTn'))+1
def fresh():
 global nextid
 result=str(nextid);nextid+=1;return result
for n in expanded.getElementsByTagName('p:cTn'):n.setAttribute('id',fresh())
expandedinner=first(first(first(first(expanded,'p:cTn'),'p:childTnLst'),'p:cTn'),'p:childTnLst')
def fade(spid,exit=False,click=False):
 typ='exit' if exit else 'entr';transition='out' if exit else 'in';vis='hidden' if exit else 'visible';delay='599' if exit else '0'
 return frag(f'<p:par><p:cTn id="{fresh()}" presetID="10" presetClass="{typ}" presetSubtype="0" fill="hold" nodeType="'+('clickEffect' if click else 'withEffect')+f'"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst><p:animEffect transition="{transition}" filter="fade"><p:cBhvr><p:cTn id="{fresh()}" dur="600"/><p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl></p:cBhvr></p:animEffect><p:set><p:cBhvr><p:cTn id="{fresh()}" dur="1" fill="hold"><p:stCondLst><p:cond delay="{delay}"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr><p:to><p:strVal val="{vis}"/></p:to></p:set></p:childTnLst></p:cTn></p:par>')
for e in list(expandedinner.childNodes):
 if e.nodeType!=1:continue
 target=first(e,'p:spTgt').getAttribute('spid')
 if target in mapping:expandedinner.removeChild(e)
# Exit filtered expressions and fade in expanded expressions on the new click.
for i,(oldid,newid) in enumerate(mapping.items()):
 for n in [fade(newid,True,i==0),fade(oldid)]:expandedinner.insertBefore(d.importNode(n,True),expandedinner.firstChild)
# Ensure the first effect is the click trigger; all following effects run with it.
for i,n in enumerate([n for n in expandedinner.childNodes if n.nodeType==1]):first(n,'p:cTn').setAttribute('nodeType','clickEffect' if i==0 else 'withEffect')
groups.insertBefore(expanded,original.nextSibling)
for prefix,uri in b.NS.items():d.documentElement.setAttribute('xmlns:'+prefix,uri)
files['ppt/slides/slide41.xml']=d.toxml(encoding='utf-8')
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'final.pptx',files)
# Static previews of the two expressions, without overlapping animation states.
for mode,remove in [('before',set(mapping)|set(relations)),('after',set(added))]:
 dd=D.parseString(files['ppt/slides/slide41.xml']); st=first(dd,'p:spTree')
 for n in list(st.childNodes):
  if n.nodeType==1 and n.getElementsByTagName('p:cNvPr') and first(n,'p:cNvPr').getAttribute('id') in remove:st.removeChild(n)
 for t in list(dd.getElementsByTagName('p:timing')):t.parentNode.removeChild(t)
 ff=files.copy();ff['ppt/slides/slide41.xml']=dd.toxml(encoding='utf-8');write(B/(mode+'.pptx'),ff)
assert len([n for n in main.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='clickEffect'])==7
assert len({n.getAttribute('id') for n in timing.getElementsByTagName('p:cTn')})==len(timing.getElementsByTagName('p:cTn'))
print('Inserted a 0.6-second crossfade on one extra click; existing slide objects and other animation groups preserved.')
