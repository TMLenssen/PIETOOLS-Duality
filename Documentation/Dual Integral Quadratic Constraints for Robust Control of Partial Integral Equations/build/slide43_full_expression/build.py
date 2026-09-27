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
for n in d.getElementsByTagName('m:t'):
 if n.firstChild and '⊤' in n.firstChild.data:n.firstChild.data=n.firstChild.data.replace('⊤','*')
keep={'Title 1','Footer Placeholder 2','Slide Number Placeholder 3','Original filter heading','Dual filter heading','!!Primal filter matrix','!!Dual filter matrix','Transpose comparison','Transpose explanation','Dual operation arrow','Dual operation arrow label','Dual operation steps'}
removed=set()
for n in list(tree.childNodes):
 if n.nodeType!=1 or not n.getElementsByTagName('p:cNvPr'):continue
 nv=first(n,'p:cNvPr')
 if n.tagName!='p:nvGrpSpPr' and nv.getAttribute('name') not in keep:removed.add(nv.getAttribute('id'));tree.removeChild(n)
main=next(n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='mainSeq')
groups=next(n for n in main.childNodes if getattr(n,'tagName','')=='p:childTnLst')
for n in [n for n in groups.childNodes if n.nodeType==1][2:]:groups.removeChild(n)
for n in list(timing.getElementsByTagName('p:spTgt')):
 if n.getAttribute('spid') in removed:
  parent=n
  while parent.tagName!='p:par':parent=parent.parentNode
  if parent.parentNode:parent.parentNode.removeChild(parent)
for n in list(timing.getElementsByTagName('p:bldP')):
 if n.getAttribute('spid') in removed:n.parentNode.removeChild(n)
s=v.Slide();s.i=14000;states={};positions=[(352,239),(404,239),(352,265),(404,265)]
def entry(m,val):
 if val in ['I','0','-I']:return m.r(val.replace('-','−'),RED if val=='-I' else None,True)
 return (m.r('−',RED) if val.startswith('-') else '')+(m.sup(m.r('K',RED),m.r('*',RED,True)) if 'T' in val else m.r('K',RED))
def add(stage,key,x,y,fn,size=23,w=100):
 s.equation(f'Full D {stage} {key}',x,y,fn,size,w=w)
 states[stage][key]={'id':first(frag(s.parts[-1]),'p:cNvPr').getAttribute('id'),'x':x,'y':y}
def poly(stage,key,points):
 s.poly(f'Full D {stage} {key}',points,width=1.15)
 states[stage][key]={'id':first(frag(s.parts[-1]),'p:cNvPr').getAttribute('id'),'x':0,'y':0}
def factor(m,left,active=False):
 rr=[['0','−I'],['I','0']] if left else [['0','I'],['−I','0']]
 return m.d(m.matrix([[m.r(x,RED if active else None,True) for x in row] for row in rr]),'[',']')
values={1:['I','0','-K','I'],2:['I','-KT','0','I'],3:['0','-I','I','-KT'],4:['I','0','KT','I'],5:['I','0','-KT','I']}
captions=['Start from the full dual operation','Substitute the filter into the full expression','Transpose the filter matrix','Multiply by the matrix on the left','Multiply by the matrix on the right','Apply the inverse to obtain the dual filter']
for stage in range(6):
 states[stage]={}
 px=135 if stage<=2 else 220 if stage==3 else 262
 add(stage,'prefix',px,252,lambda m:m.r('D',plain=True)+m.d(theta(m,False))+m.r('='),23,145)
 if stage<5:
  add(stage,'open',215 if stage<=2 else 314,246,lambda m:m.r('(',plain=True),62,30)
  add(stage,'close',548 if stage<=3 else 442,246,lambda m:m.r(')',plain=True),62,30)
  add(stage,'inverse',568 if stage<=3 else 460,217,lambda m:m.r('−1',RED,True),16,42)
 if stage<=2:add(stage,'left factor',267,252,lambda m:factor(m,True),23,93)
 if stage<=3:add(stage,'right factor',493,252,lambda m:factor(m,False),23,93)
 if stage==0:add(stage,'symbol',378,252,lambda m:m.sup(theta(m,False),m.r('*',plain=True)),26,110)
 else:
  for j,((x,y),val) in enumerate(zip(positions,values[stage])):add(stage,f'cell{j}',x,y,lambda m,val=val:entry(m,val),23,73)
  poly(stage,'left bracket',[(334,225),(326,225),(326,280),(334,280)])
  poly(stage,'right bracket',[(422,225),(430,225),(430,280),(422,280)])
  if stage==1:add(stage,'transpose',440,219,lambda m:m.r('*',RED,True),16,22)
 if stage==5:add(stage,'answer',493,252,lambda m:m.r('=')+theta(m,True),25,100)
 s.label(f'Full D {stage} caption',360,347,captions[stage],16,w=650)
 states[stage]['caption']={'id':first(frag(s.parts[-1]),'p:cNvPr').getAttribute('id'),'x':360,'y':347}
s.outline('Full dual operation box',(60,193,600,122),RED,1.8)
boxid=first(frag(s.parts[-1]),'p:cNvPr').getAttribute('id')
for prefix,uri in b.NS.items():d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:tree.appendChild(d.importNode(frag(xml),True))
nextid=max(int(n.getAttribute('id')) for n in timing.getElementsByTagName('p:cTn'))+1
for node in ast.parse((B.parent/'slide43_matrix_animation/build.py').read_text(encoding='utf8')).body:
 if isinstance(node,ast.FunctionDef) and node.name in ['fresh','effect','newgroup']:exec(compile(ast.Module(body=[node],type_ignores=[]),'<animation>','exec'))
groupnodes=[n for n in groups.childNodes if n.nodeType==1]
second=first(first(first(first(groupnodes[1],'p:cTn'),'p:childTnLst'),'p:cTn'),'p:childTnLst')
for item in list(states[0].values())+[{'id':boxid}]:second.appendChild(d.importNode(effect(item['id'],delay=300),True))
def arc(j,kind):
 x,y=positions[j]
 if kind=='transpose':cx,cy,rx,ry=378,252,math.hypot(26,13),math.hypot(26,13)
 elif kind=='rows':cx,cy,rx,ry=x,252,12,13
 else:cx,cy,rx,ry=378,y,26,10
 angle=math.atan2((y-cy)/ry,(x-cx)/rx);out='M 0 0 ';k=0.5522847498307936
 def p(a):return cx+rx*math.cos(a),cy+ry*math.sin(a)
 def vel(a):return -rx*math.sin(a),ry*math.cos(a)
 def q(pt):return f'{(pt[0]-x)/720:.9f} {(pt[1]-y)/405:.9f}'
 for _ in range(2):
  a=p(angle);av=vel(angle);b2=p(angle+math.pi/2);bv=vel(angle+math.pi/2)
  out+='C '+q((a[0]+k*av[0],a[1]+k*av[1]))+' '+q((b2[0]-k*bv[0],b2[1]-k*bv[1]))+' '+q(b2)+' '
  angle+=math.pi/2
 return out+'E'
for stage in range(1,6):
 before=states[stage-1];after=states[stage];duration=700 if stage in [1,5] else 1200;effects=[effect(before['caption']['id'],'out',duration=200)]
 for key,old in before.items():
  if key=='caption':continue
  if key.startswith('cell') and stage in [2,3,4]:effects.append(effect(old['id'],duration=duration,path=arc(int(key[-1]),{2:'transpose',3:'rows',4:'columns'}[stage])))
  elif key in after and (old['x'],old['y'])!=(after[key]['x'],after[key]['y']):
   target=after[key];effects.append(effect(old['id'],duration=duration,path=f'M 0 0 L {(target["x"]-old["x"])/720:.9f} {(target["y"]-old["y"])/405:.9f} E'))
  effects.append(effect(old['id'],'out',delay=duration-250 if key in after else 0,duration=250))
 for key,item in after.items():effects.append(effect(item['id'],delay=0 if key=='caption' else duration-250,duration=300))
 newgroup(effects)
files['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
assert len([n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='clickEffect'])==7
assert files['ppt/slides/slide42.xml']==original['ppt/slides/slide42.xml']
assert d.getElementsByTagName('p159:morph')[0].toxml()==D.parseString(original['ppt/slides/slide43.xml']).getElementsByTagName('p159:morph')[0].toxml()
(B/'states.json').write_text(json.dumps(states))
pack=(B.parent/'slide43_matrix_animation/package.py').read_text().replace('slide43animated_','slide43full_').replace('==12','==11')
(B/'package.py').write_text(pack)
(B/'render.ps1').write_text((B.parent/'slide43_matrix_animation/render.ps1').read_text().replace('-ne 5','-ne 7').replace('Expected 5','Expected 7'))
(B/'install.ps1').write_text((B.parent/'slide43_matrix_animation/install.ps1').read_text().replace('slide 43 animated dual operation','slide 43 full dual expression'))
print('Full-expression derivation: substitute, transpose, left multiply, right multiply, inverse; Morph preserved.')
