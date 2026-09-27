from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import sys,json,re,posixpath,hashlib
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,els,first
from build_video_overlays import namespaces
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy();parts=json.loads((B/'parts.json').read_text())
INK='252529';GRAY='747B82';RED='D61016';BLUE='20558B'
def run(self,s,c=None,plain=False):
 return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in s)
b.Math.r=run
def sub(m,s,i):return m.sub(m.r(s),m.r(i,plain=i in ['S','G','GS','SG','GG','f','4']))
def call(m,s,args='t'):return s+m.d(m.r(args))
def x(m,i='i',args='t'):return call(m,sub(m,'x',i),args)
def phi(m,ij='ij',args='t,s'):return call(m,sub(m,'φ',ij),args)
def v(m,ij='ij',args='t,s'):return call(m,sub(m,'v',ij),args)
def dot(m,e):return '<m:acc><m:accPr><m:chr m:val="̇"/>'+m.ctrl()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
def dx(m,i='i'):return call(m,dot(m,sub(m,'x',i)))
def part(m,s):return sub(m,'∂',s)
def integral(m,e,upper='s'):
 return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r(upper)+'</m:sup><m:e>'+e+'</m:e></m:nary>'
def vec(m,entries):
 body='<m:m><m:mPr>'+m.ctrl()+'</m:mPr>'+''.join('<m:mr><m:e>'+s+'</m:e></m:mr>' for s in entries)+'</m:m>'
 return m.d(body,'[',']')
def bold(m,s):return m.r(s).replace('m:val="i"','m:val="bi"')
def state(m):return m.sub(bold(m,'x'),m.r('f',plain=True))
def op(m,s):return m.r({'T':'𝒯','A':'𝒜','B':'ℬ','C':'𝒞','D':'𝒟','P':'𝒫','I':'ℐ','K':'𝒦'}[s],plain=True)
def star(m,s):return m.sup(s,m.r('*',plain=True))
def pi(m):return sub(m,'Π','4')
def geom(n,box):
 xf=first(n,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 for k,val in zip(['x','y'],box[:2]):o.setAttribute(k,b.emu(val))
 for k,val in zip(['cx','cy'],box[2:]):e.setAttribute(k,b.emu(val))
def name(n):return first(n,'p:cNvPr').getAttribute('name')
def sid(n):return first(n,'p:cNvPr').getAttribute('id')
def fragment(xml):return D.parseString(f'<root {b.DECL}>'+xml+'</root>').documentElement.firstChild
def rp(p):return posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
source26=D.parseString(files[parts[25]])
assets={sid(n):n for n in first(source26,'p:spTree').childNodes if n.nodeType==1 and els(n,'p:cNvPr')}
source19=D.parseString(files[parts[18]])
neural19=next(n for n in els(source19,'p:grpSp') if name(n)=='Original neural schematic')
notes={}
class Slide(b.Slide):
 def __init__(self,num,title,subtitle):
  super().__init__();self.i=1000;self.num=num;self.doc=D.parseString(files[parts[num-1]]);namespaces(self.doc)
  self.rd=D.parseString(files[rp(parts[num-1])]);self.assets=[]
  self.label('Title '+str(num),360,45,title,25,w=648,bold=True);self.parts[-1]=self.parts[-1].replace('algn="ctr"','algn="l"')
  self.label('Subtitle '+str(num),360,76,subtitle,12,GRAY,w=648);self.parts[-1]=self.parts[-1].replace('algn="ctr"','algn="l"')
 def text(self,n,x,y,t,size=15,color=INK,w=630,bold=False):self.label(n,x,y,t,size,color,w,bold)
 def eq(self,n,x,y,fn,size=20,w=640,color=INK):self.equation(n,x,y,fn,size,w,color)
 def rule(self,y=98):self.path('Section rule',[(36,y),(684,y)],False,'E4E6E9',.65)
 def asset(self,node,nm,box,sourcepart=None,delta_red=False):
  node=node.cloneNode(True);geom(node,box);mapping={};ridmap={}
  if nm=='!!Neural model':
   # At icon size the population and probe labels overwhelm the artwork.
   for child in list(node.childNodes):
    if child.nodeType==1 and child.tagName in ['p:sp','mc:AlternateContent'] and (els(child,'a:t') or els(child,'m:t')):node.removeChild(child)
   assert els(node,'p:pic'),'Neural model artwork must remain'
  for nv in els(node,'p:cNvPr'):
   old=nv.getAttribute('id')
   if old not in mapping:mapping[old]=str(self.ident())
   nv.setAttribute('id',mapping[old])
  first(node,'p:cNvPr').setAttribute('name',nm)
  # Text was white on the user's red panels. Restore contrast on white.
  for rr in els(node,'a:rPr')+els(node,'a:defRPr')+els(node,'a:endParaRPr'):
   for cc in els(rr,'a:srgbClr'):
    if cc.getAttribute('val')=='FFFFFF':cc.setAttribute('val',INK)
   for cc in list(els(rr,'a:schemeClr')):
    if cc.getAttribute('val') in ['bg1','lt1']:
     replacement=cc.ownerDocument.createElement('a:srgbClr');replacement.setAttribute('val',INK);cc.parentNode.replaceChild(replacement,cc)
  if delta_red:
   for sp in els(node,'p:sp'):
    if name(sp) in ['Uncertainty','Uncertainty label']:
     for rr in els(sp,'a:ln')+els(sp,'a:rPr'):
      for cc in els(rr,'a:srgbClr'):cc.setAttribute('val',RED)
  if sourcepart:
   src=D.parseString(files[rp(sourcepart)]);rrs={r.getAttribute('Id'):r for r in els(src,'Relationship')}
   for el in node.getElementsByTagName('*'):
    for att in ['r:embed','r:link','r:id']:
     rid=el.getAttribute(att)
     if rid in rrs:
      if rid not in ridmap:
       r=rrs[rid].cloneNode(True);new='rIdPIE'+str(len(els(self.rd,'Relationship'))+100);r.setAttribute('Id',new);self.rd.documentElement.appendChild(self.rd.importNode(r,True));ridmap[rid]=new
      el.setAttributeNS(b.NS['r'],att,ridmap[rid])
  self.assets.append(node.toxml())
 def lfrpair(self,arrows=False,delta_red=False,y=111,width=244):
  height=width*2725557/3556000
  for x0,aid,nm in [(51,'11','!!Physical LFR'),(425,'26','!!PIE LFR')]:self.asset(assets[aid],nm,(x0,y,width,height),parts[25],delta_red)
  self.text('!!Physical model heading',173,99,'ODE–PDE model',14,w=250,bold=True)
  self.text('!!PIE model heading',547,99,'PIE model',14,w=250,bold=True)
  if arrows:
   self.path('!!Conversion arrow',[(313,164),(406,164)],width=1)
   self.text('!!Conversion label',360,148,'Convert',12,GRAY,w=115)
   self.path('!!Implementation arrow',[(406,247),(313,247)],width=1)
   self.text('!!Implementation label',360,267,'Implement K',12,GRAY,w=115)
  else:self.eq('Exact equivalence',360,206,lambda m:m.r('⇔',plain=True),31,100)
 def industrialrow(self):
  self.asset(neural19,'!!Neural model',(45,319,87,42),parts[18])
  self.asset(assets['55'],'!!ASML model',(146,319,81,42),parts[25])
  self.asset(assets['56'],'!!Canon model',(242,321,84,41),parts[25])
  for xx,txt in [(88,'STN–GPe'),(187,'ASML'),(284,'Canon')]:self.text('!!Application '+txt,xx,371,txt,9,GRAY,w=92)
 def save(self,morph=False):
  # Retain the deck footer, number and original logo without replacing media.
  for n in first(self.doc,'p:spTree').childNodes:
   if n.nodeType==1 and els(n,'p:cNvPr') and any(k in name(n).lower() for k in ['footer','slide number','logo']):self.assets.append(n.toxml())
  tr='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+''.join(self.parts+self.assets)
  new=D.parseString(b.lib.xml(f'<p:sld {b.DECL} mc:Ignorable="a14"><p:cSld><p:spTree>{tr}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'))
  if morph:
   old6=D.parseString(files[parts[5]])
   trans=next(t.parentNode.parentNode for t in els(old6,'p:transition') if els(t,'p159:morph')).cloneNode(True)
   # Carry all transition namespace declarations from the original document.
   for i in range(old6.documentElement.attributes.length):
    at=old6.documentElement.attributes.item(i)
    if at.name.startswith('xmlns:'):new.documentElement.setAttribute(at.name,at.value)
   for t in els(trans,'p:transition'):
    t.setAttribute('spd','med')
    if t.hasAttribute('p14:dur'):t.setAttribute('p14:dur','900')
   new.documentElement.appendChild(new.importNode(trans,True))
  else:
   trans=D.parseString('<p:transition xmlns:p="'+b.NS['p']+'" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" p14:dur="450"><p:fade/></p:transition>').documentElement
   new.documentElement.appendChild(new.importNode(trans,True))
  files[parts[self.num-1]]=new.toxml(encoding='utf-8');files[rp(parts[self.num-1])]=self.rd.toxml(encoding='utf-8')

s=Slide(20,'From PDEs to PIEs','Change the representation of the nominal block.')
s.lfrpair()
s.text('Equivalence message',360,327,'Same dynamics. Same signals. Same interconnection.',19,w=650,bold=True)
s.text('Exactness',360,354,'Exact conversion without spatial discretization.',14,RED,w=650)
s.save()
notes[20]='We have separated Delta, the nominal dynamics and K. We now change only the representation of the nominal dynamics. For the systems covered by the PIE representation theorem, the PDE and PIE descriptions are equivalent with matching initial data and the same input/output signals. Thus the surrounding feedback interconnection stays the same. Exact representation is distinct from the finite parameterization used later to search for certificates.'

s=Slide(21,'Build the boundary conditions into the state','Nominal STN–GPe dynamics · homogeneous case: w = 0, u = 0')
s.rule();s.text('PDE heading',186,116,'ODE–PDE',16,bold=True,w=288);s.text('PIE heading',540,116,'PIE',16,bold=True,w=288)
s.eq('PDE ODE dynamics',186,157,lambda m:sub(m,'τ','i')+dx(m)+m.r('=−')+x(m),20,300)
s.eq('Transport PDE',186,202,lambda m:part(m,'t')+phi(m)+m.r('=−')+m.frac(m.r('1'),sub(m,'τ','ij'))+part(m,'s')+phi(m),18,320)
s.eq('Boundary condition',186,247,lambda m:phi(m,args='t,0')+m.r('=')+x(m),19,320,RED)
s.eq('PIE ODE dynamics',540,157,lambda m:sub(m,'τ','i')+dx(m)+m.r('=−')+x(m),20,300)
s.eq('PIE distributed dynamics',540,208,lambda m:dx(m)+m.r('+')+integral(m,call(m,dot(m,sub(m,'v','ij')),'t,θ')+m.r('dθ'))+m.r('=−')+m.frac(v(m),sub(m,'τ','ij')),18,332)
s.eq('PIE state definition',540,258,lambda m:v(m)+m.r(':=')+part(m,'s')+phi(m),17,315,BLUE)
s.eq('Equivalence direction',360,204,lambda m:m.r('⇔',plain=True),24,38)
s.path('Identity separator',[(50,285),(670,285)],False,'E4E6E9',.65)
s.eq('Exact state reconstruction',360,312,lambda m:phi(m)+m.r('=')+x(m)+m.r('+')+integral(m,v(m,args='t,θ')+m.r('dθ')),20,648,BLUE)
s.eq('Indices and interval',360,351,lambda m:m.r('i∈')+m.d(m.r('S,G',plain=True),'{','}')+m.r(',  (i,j)∈')+m.d(m.r('(G,S),(S,G),(G,G)',plain=True),'{','}')+m.r(',  s∈[0,1]'),13,665)
s.save()
notes[21]='This slide is the homogeneous nominal block from the LFR: set the nonlinearity-output input w and the control input u to zero. Do not replace w by delta(z), and do not interpret this as the full nonlinear closed loop. For i=S,G, tau_i xdot_i=-x_i. For the three delayed channels ij=GS,SG,GG, phi_ij(t,s)=x_i(t-tau_ij s), so partial_t phi_ij=-tau_ij^{-1}partial_s phi_ij and phi_ij(t,0)=x_i(t). Define v_ij=partial_s phi_ij. The fundamental theorem of calculus gives phi_ij(t,s)=x_i(t)+integral_0^s v_ij(t,theta)dtheta. Differentiating in time and substituting the transport equation gives xdot_i+integral_0^s vdot_ij=-tau_ij^{-1}v_ij. This is the displayed PIE. Conversely reconstruct phi from x,v; the boundary condition holds automatically and the transport PDE follows. Match initial histories; in the strong-solution interpretation use compatible regular initial data, and interpret general solutions in the usual weak/PIE sense. Source: Section 9, equation stn-gpe_ode-pde of the local paper.'

s=Slide(22,'Same dynamics, bounded operators','The reconstruction becomes a partial integral operator.')
s.eq('Fundamental state',174,140,lambda m:call(m,state(m))+m.r(':=')+vec(m,[bold(m,'x')+m.d(m.r('t')),bold(m,'v')+m.d(m.r('t,·'))]),23,286)
s.eq('Reconstruction operator',520,140,lambda m:op(m,'T')+call(m,state(m))+m.r('=')+vec(m,[bold(m,'x')+m.d(m.r('t')),bold(m,'φ')+m.d(m.r('t,·'))]),23,306)
s.text('Free coordinates',174,199,'Finite state + spatial derivatives',12,GRAY,w=300)
s.text('Reconstructed coordinates',520,199,'Boundary conditions included',12,BLUE,w=310)
s.eq('PIE with both LFR inputs',360,245,lambda m:op(m,'T')+call(m,dot(m,state(m)))+m.r('=')+op(m,'A')+call(m,state(m))+m.r('+')+m.sub(op(m,'B'),m.r('w'))+call(m,m.r('w'))+m.r('+')+m.sub(op(m,'B'),m.r('u'))+call(m,m.r('u')),23,660)
s.eq('Same LFR outputs',360,289,lambda m:call(m,m.r('z'))+m.r('=')+m.sub(op(m,'C'),m.r('z'))+call(m,state(m))+m.r(',     ')+call(m,m.r('y'))+m.r('=')+m.sub(op(m,'C'),m.r('y'))+call(m,state(m)),21,650)
s.text('Bounded operator statement',360,340,'All system operators are bounded PI operators.',17,RED,w=650,bold=True)
s.save()
notes[22]='Here x=col(x_S,x_G), v=col(v_GS,v_SG,v_GG), phi has the same channel order, and x_f=(x,v) belongs to R^2 x L2([0,1];R^3). The bounded reconstruction operator is T[x;v]=[x;E x+integral_0^s v(theta)dtheta] with E=[[0,1],[1,0],[0,1]]. In homogeneous dynamics A[x;v]=[-diag(1/tau_S,1/tau_G)x; -diag(1/tau_GS,1/tau_SG,1/tau_GG)v]. Inputs w,u act on the finite-dimensional rows of T xdot_f=A x_f+B_w w+B_u u. Restore the same w,u ports from the LFR. In this model y=col(x_S,x_G), z_S=-w_GS phi_GS(t,1), z_G=w_SG phi_SG(t,1)-w_GG phi_GG(t,1); using reconstruction makes these bounded PI output maps C_z,C_y with no direct feedthrough. T encodes the boundary conditions. Its inverse on the PDE-state range need not be bounded in the ambient L2 norm; we do not claim an arbitrary bounded inverse.'

s=Slide(23,'PI operators have a matrix-like algebra','The operations needed for control stay within the same operator class.')
items=[('Addition',190,132,lambda m:op(m,'A')+m.r('+')+op(m,'B')+m.r('∈')+pi(m)),('Composition',535,132,lambda m:op(m,'A')+op(m,'B')+m.r('∈')+pi(m)),('Adjoint',190,238,lambda m:star(m,op(m,'A'))+m.r('∈')+pi(m)),('Block operators',535,238,lambda m:m.d(op(m,'A')+m.r('  ')+op(m,'B'),'[',']')+m.r('∈')+pi(m))]
for label,xx,yy,fn in items:
 s.text(label+' label',xx,yy,label,15,GRAY,w=290);s.eq(label+' equation',xx,yy+37,fn,29,300)
s.text('Algebra conclusion',360,335,'Build control conditions directly with PI operators.',18,RED,w=660,bold=True)
s.text('Compatible dimensions',360,360,'For compatible input and output dimensions.',11,GRAY,w=640)
s.save()
notes[23]='Partial integral operators with compatible dimensions are closed under addition, composition, adjoints and block concatenation. This gives the matrix-like algebra required to construct Lyapunov, dissipativity and synthesis inequalities directly at operator level. It does not mean that these infinite-dimensional operators are finite matrices. The finite computation comes from the next slide’s chosen PI-operator parameterization. Source: local paper Section 2, Partial Integral Equations.'

s=Slide(24,'From stability to a convex test','A Lyapunov certificate for the homogeneous PIE.')
s.eq('Homogeneous PIE',360,117,lambda m:op(m,'T')+dot(m,state(m))+m.r('=')+op(m,'A')+state(m),23)
s.eq('Lyapunov functional',360,164,lambda m:m.r('V=')+m.d(op(m,'T')+state(m)+m.r(',')+op(m,'P')+op(m,'T')+state(m),'⟨','⟩')+m.r(',     ')+op(m,'P')+m.r('≽ε')+op(m,'I'),22)
s.eq('Linear PI inequality',360,218,lambda m:star(m,op(m,'T'))+op(m,'P')+op(m,'A')+m.r('+')+star(m,op(m,'A'))+op(m,'P')+op(m,'T')+m.r('≼−2α')+star(m,op(m,'T'))+op(m,'P')+op(m,'T'),24,665)
s.text('Fixed rate',360,254,'For fixed α > 0 and ε > 0, this is linear in the Lyapunov operator.',13,GRAY,w=660)
s.text('LPI step',124,306,'Operator inequality',16,w=195,bold=True)
s.path('Parameterization arrow',[(224,306),(292,306)],width=1)
s.text('Parameterization step',399,306,'Polynomial PI parameterization',14,w=218)
s.path('SDP arrow',[(515,306),(550,306)],width=1)
s.text('LMI step',621,306,'LMI / SDP',18,RED,w=135,bold=True)
s.text('Sufficient test',360,351,'A finite, sufficient test — without discretizing the PDE.',16,RED,w=660)
s.save()
notes[24]='Let q=T x_f be the reconstructed PDE state and V=<q,Pq>, with self-adjoint bounded coercive P >= epsilon I. For a strong homogeneous trajectory, dV/dt=<x_f,(T* P A+A* P T)x_f>. The displayed inequality gives dV/dt <= -2 alpha V and hence exponential decay in the reconstructed-state norm; extend in the appropriate solution class. For fixed alpha>0 the expression is affine in P. Joint optimization over alpha and P is not asserted convex; one may fix alpha or perform an outer search. A finite polynomial PI parameterization and positivity certificate yields sufficient finite-dimensional LMIs/SDPs. Exact PDE-PIE representation is not a claim that every certificate search is nonconservative. Source: local paper Section 2 for PI operator/LPI definitions; direct Lyapunov calculation for the displayed inequality.'

for num in [25,26]:
 if num==25:s=Slide(num,'Design in PIE coordinates','Compute a controller in the equivalent representation.')
 else:s=Slide(num,'Our first pillar: PIEs','An exact representation with tractable analysis and synthesis.')
 s.lfrpair(arrows=True,delta_red=num==26)
 s.industrialrow()
 if num==25:
  s.text('Design takeaway',528,327,'Analyze and synthesize',18,w=316,bold=True)
  s.text('Design scope',528,354,'for the nominal linear dynamics.',14,GRAY,w=316)
 else:
  s.text('Pillar takeaway',528,322,'Pillar 1: tractability',20,RED,w=316,bold=True)
  s.text('Pillar route',528,345,'PIE → LPI → LMI',17,w=316)
  s.text('Next ingredient',528,368,'Next: nonlinear stability and performance.',11,GRAY,w=325)
 s.save(morph=num==26)
notes[25]='The forward arrow is exact model conversion; the reverse arrow is controller implementation in the original physical coordinates. PIE methods provide computable operator conditions for analysis and synthesis of the nominal linear dynamics. The K block remains a generic controller with the same measured-signal and actuation ports as before. A controller synthesized in PIE state coordinates must be implemented using the state reconstruction/coordinate map; we do not claim a particular output-feedback structure is automatically convex. Delta is still in the full LFR: the nominal synthesis statement alone does not establish robust nonlinear closed-loop stability. The images are the user’s existing STN-GPe, ASML and Canon examples. PIETOOLS and PIE synthesis are discussed in the local paper introduction and preliminaries.'
notes[26]='First pillar: exact PIE modeling plus PI-operator optimization provides tractability for the nominal distributed dynamics. The two diagrams and three application images keep exactly the same positions as slide 25. Morph preserves this visual bridge while the first-pillar conclusion appears and Delta becomes the next focus. Next we need a way to account for the nonlinearity/uncertainty and robust stability/performance; later duality enables the synthesis argument. This is not a claim that replacing PDE by PIE already solves the full uncertain nonlinear control problem.'
for num,narration in notes.items():b.add_notes(files,int(re.search(r'slide(\d+)',parts[num-1])[1]),narration)
for n,vv in original.items():
 if n.startswith('ppt/slides/slide') and n.endswith('.xml') and n not in parts[19:26]:assert files[n]==vv,n
 if n.startswith('ppt/media/'):assert files[n]==vv,n
for num in range(20,27):
 dd=D.parseString(files[parts[num-1]])
 for node in list(els(dd,'mc:Fallback')):node.parentNode.removeChild(node)
 ids=[nv.getAttribute('id') for nv in els(dd,'p:cNvPr')];assert len(ids)==len(set(ids)),(num,'duplicate shape IDs')
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,vv in data.items():z.writestr(n,vv)
write(B/'final.pptx',files)
# Two-slide playback check for the uninterrupted 25-to-26 visual bridge.
vd=files.copy();pres=D.parseString(vd['ppt/presentation.xml']);sl=first(pres,'p:sldIdLst')
for j,node in enumerate(list(els(pres,'p:sldId'))):
 if j not in [24,25]:sl.removeChild(node)
vd['ppt/presentation.xml']=pres.toxml(encoding='utf-8');write(B/'transition-check.pptx',vd)
(B/'source.json').write_text(json.dumps(dict(source=str(b.SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper())))
(B/'narrative.md').write_text('\n\n'.join(f'Slide {n}\n{t}' for n,t in notes.items()),encoding='utf-8')
print('Rebuilt slides 20–26 with editable math. Other slides and media unchanged.')
