from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import ast,importlib.util,json,hashlib,math
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);b=v.b
for node in ast.parse((B.parent/'slide41_mirror/build.py').read_text(encoding='utf8')).body:
 if isinstance(node,ast.FunctionDef):exec(compile(ast.Module(body=[node],type_ignores=[]),'<helper>','exec'))
v.M.r=run;RED='C81919'
d=D.parseString(files['ppt/slides/slide43.xml']);tree=first(d,'p:spTree');timing=first(d,'p:timing')
shapes={first(n,'p:cNvPr').getAttribute('name'):n for n in tree.childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr')}
old=shapes['Dual operation evaluation'];oldid=first(old,'p:cNvPr').getAttribute('id');tree.removeChild(old)
for n in list(timing.getElementsByTagName('p:spTgt')):
 if n.getAttribute('spid')==oldid:
  parent=n
  while parent.tagName!='p:par':parent=parent.parentNode
  if parent.parentNode:parent.parentNode.removeChild(parent)
for n in list(timing.getElementsByTagName('p:bldP')):
 if n.getAttribute('spid')==oldid:n.parentNode.removeChild(n)
s=v.Slide();s.i=12000
ids={};stage_ids={i:[] for i in range(4)}
def remember(name,stage=None):
 ids[name]=first(frag(s.parts[-1]),'p:cNvPr').getAttribute('id')
 if stage is not None:stage_ids[stage].append(ids[name])
def eq(name,x,y,fn,size=22,w=100,stage=None):
 s.equation(name,x,y,fn,size,w=w);remember(name,stage)
def entry(m,val):
 if val in ('I','0'):return m.r(val,plain=True)
 return (m.r('−',RED) if val.startswith('-') else '')+(m.sup(m.r('K',RED),m.r('⊤',RED,True)) if 'T' in val else m.r('K',RED))
positions=[(334,305),(386,305),(334,337),(386,337)]
values=[['I','0','-K','I'],['I','-KT','0','I'],['I','0','KT','I'],['I','0','-KT','I']]
captions=['Start with the original filter','1. Transpose: exchange rows and columns','2. Rotate the blocks and reverse the off-diagonal signs','3. Invert: recover the required dual filter']
for stage in range(4):
 for j,((x,y),val) in enumerate(zip(positions,values[stage])):
  eq(f'D stage {stage} cell {j}',x,y,lambda m,val=val:entry(m,val),22,72,stage)
 s.label(f'D stage {stage} caption',360,369,captions[stage],14,w=650);remember(f'D stage {stage} caption',stage)
 if stage in [0,1,3]:
  eq(f'D stage {stage} prefix',269,321,lambda m,t=stage:(m.r('D',plain=True)+m.d(theta(m,False)) if t==3 else m.sup(theta(m,False),m.r('⊤',plain=True)) if t==1 else theta(m,False))+m.r('='),22,112,stage)
 if stage==3:eq('D result suffix',456,321,lambda m:m.r('=')+theta(m,True),22,80,stage)
for name,points in [('D left bracket',[(317,287),(309,287),(309,355),(317,355)]),('D right bracket',[(403,287),(411,287),(411,355),(403,355)])]:
 s.poly(name,points,width=1.2);remember(name)
def definition(m,stage):
 def r(t,color=None):return m.r(t,color,True)
 def perm(rows):
  c=RED if stage==2 else None
  return m.d(m.matrix([[r(t,c) for t in row] for row in rows]),'[',']')
 left=perm([['0','−I'],['I','0']]);right=perm([['0','I'],['−I','0']])
 th=m.sup(m.r('Θ',RED if stage==1 else None),r('⊤',RED if stage==1 else None))
 return theta(m,True)+m.r('=')+m.r('D',plain=True)+m.d(theta(m,False))+m.r('=')+m.sup(m.d(left+th+right),r('−1',RED if stage==3 else None))
for stage in [1,2,3]:eq(f'D active formula {stage}',360,234,lambda m,t=stage:definition(m,t),24,585)
for prefix,uri in b.NS.items():d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:tree.appendChild(d.importNode(frag(xml),True))
nextid=max(int(n.getAttribute('id')) for n in timing.getElementsByTagName('p:cTn'))+1
def fresh():
 global nextid
 r=nextid;nextid+=1;return str(r)
def effect(spid,kind='in',delay=0,duration=400,click=False,path=None):
 typ='path' if path else 'exit' if kind=='out' else 'entr'
 header=f'<p:par><p:cTn id="{fresh()}" presetID="{0 if path else 10}" presetClass="{typ}" presetSubtype="0" fill="hold" nodeType="'+('clickEffect' if click else 'withEffect')+f'"><p:stCondLst><p:cond delay="{delay}"/></p:stCondLst><p:childTnLst>'
 if path:
  body=f'<p:animMotion origin="layout" path="{path}" pathEditMode="relative" rAng="0"><p:cBhvr><p:cTn id="{fresh()}" dur="{duration}" fill="hold" accel="20000" decel="20000"/><p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl><p:attrNameLst><p:attrName>ppt_x</p:attrName><p:attrName>ppt_y</p:attrName></p:attrNameLst></p:cBhvr><p:rCtr x="0" y="0"/></p:animMotion>'
 else:
  body=f'<p:animEffect transition="{kind}" filter="fade"><p:cBhvr><p:cTn id="{fresh()}" dur="{duration}"/><p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl></p:cBhvr></p:animEffect><p:set><p:cBhvr><p:cTn id="{fresh()}" dur="1" fill="hold"><p:stCondLst><p:cond delay="{duration-1 if kind=="out" else 0}"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr><p:to><p:strVal val="'+('hidden' if kind=='out' else 'visible')+'"/></p:to></p:set>'
 return frag(header+body+'</p:childTnLst></p:cTn></p:par>')
main=next(n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='mainSeq')
groups=next(n for n in main.childNodes if getattr(n,'tagName','')=='p:childTnLst')
groupnodes=[n for n in groups.childNodes if n.nodeType==1]
secondinner=first(first(first(first(groupnodes[1],'p:cTn'),'p:childTnLst'),'p:cTn'),'p:childTnLst')
for spid in stage_ids[0]+[ids['D left bracket'],ids['D right bracket']]:secondinner.appendChild(d.importNode(effect(spid,delay=300),True))
def newgroup(effects):
 root=frag(f'<p:par><p:cTn id="{fresh()}" fill="hold"><p:stCondLst><p:cond delay="indefinite"/></p:stCondLst><p:childTnLst><p:par><p:cTn id="{fresh()}" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst/></p:cTn></p:par></p:childTnLst></p:cTn></p:par>')
 inner=first(first(first(first(root,'p:cTn'),'p:childTnLst'),'p:cTn'),'p:childTnLst')
 for i,e in enumerate(effects):
  first(e,'p:cTn').setAttribute('nodeType','clickEffect' if i==0 else 'withEffect');inner.appendChild(e)
 groups.appendChild(d.importNode(root,True))
def orbit(j):
 x,y=positions[j];x-=360;y-=321;x0,y0=x,y;k=0.5522847498307936
 out='M 0 0 '
 def point(a,b):return f'{(a-x0)/720:.9f} {(b-y0)/405:.9f}'
 for _ in range(2):
  xx,yy=-y,x
  out+='C '+point(x-k*y,y+k*x)+' '+point(xx+k*yy,yy-k*xx)+' '+point(xx,yy)+' '
  x,y=xx,yy
 return out+'E'
formula=first(shapes['Dual operation definition'],'p:cNvPr').getAttribute('id')
for stage in [1,2,3]:
 effects=[]
 previous=stage-1
 duration=1000 if stage==1 else 1400 if stage==2 else 650
 for j in range(4):
  old=ids[f'D stage {previous} cell {j}']
  if stage==1 and j in [1,2]:
   effects.append(effect(old,duration=duration,path=orbit(j)))
  elif stage==2:effects.append(effect(old,duration=duration,path=orbit(j)))
  effects.append(effect(old,'out',delay=duration-250,duration=250))
 for spid in stage_ids[previous][4:]:effects.append(effect(spid,'out',duration=250))
 for spid in stage_ids[stage]:effects.append(effect(spid,delay=duration-250,duration=300))
 effects.append(effect(formula,'out',duration=300))
 formula=ids[f'D active formula {stage}'];effects.append(effect(formula,duration=300))
 newgroup(effects)
files['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'staged.pptx',files)
assert len([n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='clickEffect'])==5
assert len(timing.getElementsByTagName('p:animMotion'))==6
assert original['ppt/slides/slide42.xml']==files['ppt/slides/slide42.xml']
assert D.parseString(original['ppt/slides/slide43.xml']).getElementsByTagName('p159:morph')[0].toxml()==d.getElementsByTagName('p159:morph')[0].toxml()
pack=(B.parent/'slide43_dual/package.py').read_text().replace('slide43theta_','slide43animated_').replace("assert len(d.getElementsByTagName('m:m'))==8","assert len(d.getElementsByTagName('m:m'))==12")
(B/'package.py').write_text(pack)
(B/'install.ps1').write_text((B.parent/'slide43_dual/install.ps1').read_text().replace('slide 43 dual operation','slide 43 animated dual operation'))
# Store animation-state membership for uncluttered static previews.
(B/'states.json').write_text(json.dumps({'stages':stage_ids,'ids':ids}))
print('Created three additional clicks: transpose, 180-degree block rotation with sign changes, and inverse.')
