from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import sys,json,re,posixpath,hashlib
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,els,first
from build_video_overlays import namespaces
def load(p):
 with ZipFile(p) as z:return {n:z.read(n) for n in z.namelist()}
files=load(B/'source.pptx');original=files.copy();old=load(B.parent/'pde_pie_alignment/source.pptx')
INK='252529';GRAY='747B82';RED='D61016'
def sid(n):return first(n,'p:cNvPr').getAttribute('id')
def name(n):return first(n,'p:cNvPr').getAttribute('name')
def part(i):return f'ppt/slides/slide{i}.xml'
def rp(p):return posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def rect(n):
 xf=first(n,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 return [int(o.getAttribute(k))/12700 for k in ['x','y']]+[int(e.getAttribute(k))/12700 for k in ['cx','cy']]
def geom(n,box):
 xf=first(n,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 for k,val in zip(['x','y'],box[:2]):o.setAttribute(k,b.emu(val))
 for k,val in zip(['cx','cy'],box[2:]):e.setAttribute(k,b.emu(val))
def frag(xml):return D.parseString(f'<root {b.DECL}>'+xml+'</root>').documentElement.firstChild
def run(self,s,c=None,plain=False):return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in s)
b.Math.r=run
def sub(m,s,i):return m.sub(m.r(s),m.r(i,plain=i in ['S','G','GS','SG','GG','f','4']))
def dot(m,e):return '<m:acc><m:accPr><m:chr m:val="̇"/>'+m.ctrl()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
def call(m,e,args='t'):return e+m.d(m.r(args))
def x(m,i):return call(m,sub(m,'x',i))
def phi(m,args='t,s'):return call(m,sub(m,'φ','ij'),args)
def state(m):return sub(m,'x','f').replace('m:val="i"','m:val="bi"')
def op(m,s):return m.r({'T':'𝒯','A':'𝒜','B':'ℬ','C':'𝒞','D':'𝒟','P':'𝒫','I':'ℐ'}[s],plain=True)
def star(m,s):return m.sup(s,m.r('*',plain=True))
def pi(m):return sub(m,'Π','4')
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,v in data.items():z.writestr(n,v)
def group(nm,children,box,ident):
 xx,yy,ww,hh=box
 return frag(f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{ident}" name="{nm}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{b.emu(xx)}" y="{b.emu(yy)}"/><a:ext cx="{b.emu(ww)}" cy="{b.emu(hh)}"/><a:chOff x="{b.emu(xx)}" y="{b.emu(yy)}"/><a:chExt cx="{b.emu(ww)}" cy="{b.emu(hh)}"/></a:xfrm></p:grpSpPr>'+''.join(n.toxml() if not isinstance(n,str) else n for n in children)+'</p:grpSp>')

# Restore the user's original property-list structure and template.
for i in range(20,26):
 files[part(i)]=old[part(i)];files[rp(part(i))]=old[rp(part(i))]
 d=D.parseString(files[part(i)]);namespaces(d);tr=first(d,'p:spTree')
 for n in list(tr.childNodes):
  if n.nodeType==1 and els(n,'p:cNvPr') and sid(n) in {21:['17','18'],22:['21'],23:['22'],24:['23'],25:['6']}.get(i,[]):tr.removeChild(n)
 for n in list(els(d,'p:timing')):n.parentNode.removeChild(n)
 for n in els(d,'a:t'):
  if n.firstChild and 'systems' in n.firstChild.data:n.firstChild.data=n.firstChild.data.replace('…..','').replace('.....','').replace('….','').replace('...','')
 # Keep the original red current-property emphasis and muted list items.
 for sp in els(d,'p:sp'):
  if name(sp)=='Content Placeholder 2':
   for n in els(sp,'a:rPr'):
    if els(n,'a:srgbClr') and first(n,'a:srgbClr').getAttribute('val') in ['BFBFBF','D9D9D9']:first(n,'a:srgbClr').setAttribute('val','A5A8AC')
 s=b.Slide();s.i=1000
 if i==21:
  s.label('Homogeneous scope',485,177,'Nominal STN–GPe · w = 0, u = 0',11,GRAY,w=400)
  for y,ii in [(215,'S'),(244,'G')]:s.equation('Nominal ODE '+ii,359,y,lambda m,ii=ii:sub(m,'τ',ii)+call(m,dot(m,sub(m,'x',ii)))+m.r('=−')+x(m,ii),16,w=215)
  s.equation('Nominal transport PDE',359,280,lambda m:sub(m,'∂','t')+phi(m)+m.r('=−')+m.frac(m.r('1'),sub(m,'τ','ij'))+sub(m,'∂','s')+phi(m),13,w=225)
  s.equation('Boundary condition',359,316,lambda m:phi(m,'t,0')+m.r('=')+x(m,'i'),16,w=215)
  s.equation('Final homogeneous PIE',614,257,lambda m:op(m,'T')+call(m,dot(m,state(m)))+m.r('=')+op(m,'A')+call(m,state(m)),20,w=188)
  s.equation('Delay channels',484,350,lambda m:m.r('(i,j)∈')+m.d(m.r('(G,S),(S,G),(G,G)',plain=True),'{','}')+m.r(',  s∈[0,1]'),11,w=425)
 elif i==22:
  s.equation('PIE dynamics',488,222,lambda m:op(m,'T')+call(m,dot(m,state(m)))+m.r('=')+op(m,'A')+call(m,state(m))+m.r('+')+op(m,'B')+call(m,m.r('w')),23,w=410)
  s.equation('PIE output',488,268,lambda m:call(m,m.r('z'))+m.r('=')+op(m,'C')+call(m,state(m))+m.r('+')+op(m,'D')+call(m,m.r('w')),23,w=410)
  s.equation('PI operator class',488,316,lambda m:op(m,'T')+m.r(',')+op(m,'A')+m.r(',')+op(m,'B')+m.r(',')+op(m,'C')+m.r(',')+op(m,'D')+m.r('∈')+pi(m),21,w=410)
 elif i==23:
  for xx,yy,nm,fn in [(378,238,'Addition',lambda m:op(m,'A')+m.r('+')+op(m,'B')+m.r('∈')+pi(m)),(591,238,'Composition',lambda m:op(m,'A')+op(m,'B')+m.r('∈')+pi(m)),(378,292,'Adjoint',lambda m:star(m,op(m,'A'))+m.r('∈')+pi(m)),(591,292,'Concatenation',lambda m:m.d(op(m,'A')+m.r('  ')+op(m,'B'),'[',']')+m.r('∈')+pi(m))]:s.equation(nm,xx,yy,fn,24,w=205)
 elif i==24:
  s.label('Stability statement',484,205,'Exponential stability of the PDE',17,w=410)
  s.equation('Coercive certificate',484,243,lambda m:op(m,'P')+m.r('≽ε')+op(m,'I')+m.r(',   ε>0'),20,w=410)
  s.equation('Stability LPI',484,283,lambda m:star(m,op(m,'T'))+op(m,'P')+op(m,'A')+m.r('+')+star(m,op(m,'A'))+op(m,'P')+op(m,'T')+m.r('≼−α')+star(m,op(m,'T'))+op(m,'T'),19,w=410)
  s.label('Computation',484,330,'PI operator parameterization → LMIs',14,GRAY,w=410)
 elif i==25:
  s.equation('Controlled linear PIE',484,220,lambda m:op(m,'T')+call(m,dot(m,state(m)))+m.r('=')+op(m,'A')+call(m,state(m))+m.r('+')+op(m,'B')+call(m,m.r('u')),23,w=410)
  s.equation('Feedback controller',484,268,lambda m:call(m,m.r('u'))+m.r('=K')+call(m,m.r('y')),23,w=410)
  s.label('Synthesis result',484,320,'Synthesize in PIE coordinates',16,w=410)
 for xml in s.parts:tr.appendChild(d.importNode(frag(xml),True))
 # Simple matching-page transitions retain the original incremental structure.
 for node in list(d.documentElement.childNodes):
  if node.nodeType==1 and (node.tagName=='p:transition' or (node.tagName=='mc:AlternateContent' and els(node,'p:transition'))):d.documentElement.removeChild(node)
 if i>20:d.documentElement.appendChild(d.importNode(frag('<p:transition><p:fade/></p:transition>'),True))
 files[part(i)]=d.toxml(encoding='utf-8')

# Native extraction: start from the final LFR on 19, then pull out only its PDE.
d=D.parseString(files[part(20)]);tr=first(d,'p:spTree');rd=D.parseString(files[rp(part(20))]);d19=D.parseString(files[part(19)])
lfr=next(n for n in els(d19,'p:grpSp') if name(n)=='Complete LFR').cloneNode(True)
initial=[203.2,102.8315,313.6,240.337]
geom(lfr,initial)
rr19={r.getAttribute('Id'):r for r in els(D.parseString(files[rp(part(19))]),'Relationship')};mapping={}
for el in lfr.getElementsByTagName('*'):
 for att in ['r:embed','r:link','r:id']:
  rid=el.getAttribute(att)
  if rid in rr19:
   if rid not in mapping:
    r=rr19[rid].cloneNode(True);new='rIdExtract'+str(len(els(rd,'Relationship')));r.setAttribute('Id',new);rd.documentElement.appendChild(rd.importNode(r,True));mapping[rid]=new
   el.setAttributeNS(b.NS['r'],att,mapping[rid])
xf=first(lfr,'a:xfrm');co=first(xf,'a:chOff');ce=first(xf,'a:chExt')
cb=[int(co.getAttribute(k))/12700 for k in ['x','y']]+[int(ce.getAttribute(k))/12700 for k in ['cx','cy']]
plantchildren=[]
for n in list(lfr.childNodes):
 if n.nodeType==1 and els(n,'p:cNvPr') and name(n) in ['Plant','Plant label']:
  plantchildren.append(n.cloneNode(True));lfr.removeChild(n)
plantshape=next(n for n in plantchildren if name(n)=='Plant');pb=rect(plantshape)
pg=group('Extracted PDE block',plantchildren,pb,4000)
outer=[initial[0]+(pb[0]-cb[0])*initial[2]/cb[2],initial[1]+(pb[1]-cb[1])*initial[3]/cb[3],pb[2]*initial[2]/cb[2],pb[3]*initial[3]/cb[3]]
geom(pg,outer)
ident=5000
for node,nm in [(lfr,'Surrounding LFR'),(pg,'Extracted PDE block')]:
 remap={}
 for nv in els(node,'p:cNvPr'):
  oldid=nv.getAttribute('id')
  if oldid not in remap:ident+=1;remap[oldid]=str(ident)
  nv.setAttribute('id',remap[oldid])
 first(node,'p:cNvPr').setAttribute('name',nm);tr.appendChild(d.importNode(node,True))
files[part(20)]=d.toxml(encoding='utf-8');files[rp(part(20))]=rd.toxml(encoding='utf-8')
(B/'extraction.json').write_text(json.dumps(dict(box=outer,target=[359.5,117],scale=60)))

# Restore the original two explicit red pillars, with a clean white header/footer.
d=D.parseString(old[part(26)]);namespaces(d);tr=first(d,'p:spTree');rd=D.parseString(old[rp(part(26))])
for n in list(tr.childNodes):
 if n.nodeType==1 and n.tagName not in ['p:nvGrpSpPr','p:grpSpPr'] and not(els(n,'p:cNvPr') and any(k in name(n).lower() for k in ['footer','slide number'])):tr.removeChild(n)
s=b.Slide();s.i=1000
s.label('Title',360,45,'Partial Integral Equations',25,w=648,bold=True);s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
for xx,nm in [(36,'Physical model pillar'),(434,'PIE solution pillar')]:
 s.add(f'<p:sp>{b.nv(s.ident(),nm)}<p:spPr>{b.xf(xx,85,250,284)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{b.fill("C9141A")}<a:ln><a:noFill/></a:ln></p:spPr></p:sp>')
s.label('Physical heading',161,105,'Distributed models',17,'FFFFFF',w=230,bold=True)
s.label('First pillar heading',559,105,'Pillar 1: PIEs',19,'FFFFFF',w=230,bold=True)
s.path('Tractability arrow',[(307,188),(412,188)],width=1.3)
s.label('Tractability label',360,170,'Tractability',14,w=130)
s.path('Solutions arrow',[(412,269),(307,269)],width=1.3)
s.label('Solutions label',360,290,'Solutions',14,w=130)
s.label('Pillar conclusion',559,328,'Analysis and synthesis',16,'FFFFFF',w=230,bold=True)
s.label('Pillar computation',559,349,'using LMIs',16,'FFFFFF',w=230)
for xml in s.parts:tr.appendChild(d.importNode(frag(xml),True))
src=D.parseString(old[part(26)]);assets={sid(n):n for n in first(src,'p:spTree').childNodes if n.nodeType==1 and els(n,'p:cNvPr')}
ident=6000
def appendasset(node,nm,box,rels_source=None):
 global ident
 node=node.cloneNode(True);geom(node,box);remap={}
 for nv in els(node,'p:cNvPr'):
  oldid=nv.getAttribute('id')
  if oldid not in remap:ident+=1;remap[oldid]=str(ident)
  nv.setAttribute('id',remap[oldid])
 first(node,'p:cNvPr').setAttribute('name',nm)
 if rels_source:
  relmap={r.getAttribute('Id'):r for r in els(D.parseString(files[rp(rels_source)]),'Relationship')};mapping={}
  for el in node.getElementsByTagName('*'):
   for att in ['r:embed','r:link','r:id']:
    rid=el.getAttribute(att)
    if rid in relmap:
     if rid not in mapping:
      r=relmap[rid].cloneNode(True);new='rIdPillar'+str(len(els(rd,'Relationship')));r.setAttribute('Id',new);rd.documentElement.appendChild(rd.importNode(r,True));mapping[rid]=new
     el.setAttributeNS(b.NS['r'],att,mapping[rid])
 tr.appendChild(d.importNode(node,True))
appendasset(assets['11'],'Physical PDE LFR',[57,128,208,159.4])
appendasset(assets['26'],'PIE LFR',[455,128,208,159.4])
# Photos stay inside the physical-model pillar, as in the user's original.
appendasset(assets['55'],'ASML image',[130,316,68,35.4])
appendasset(assets['56'],'Canon image',[207,317,66,32.3])
# Keep the neural schematic's clean original artwork at an appropriate small scale.
neural=next(n for n in els(d19,'p:grpSp') if name(n)=='Original neural schematic').cloneNode(True)
for child in list(neural.childNodes):
 if child.nodeType==1 and child.tagName in ['p:sp','mc:AlternateContent'] and (els(child,'a:t') or els(child,'m:t')):neural.removeChild(child)
tile=f'<p:sp>{b.nv(6998,"Neural image background")}<p:spPr>{b.xf(49,312,75,45)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{b.fill("FFFFFF")}<a:ln><a:noFill/></a:ln></p:spPr></p:sp>'
tr.appendChild(d.importNode(frag(tile),True))
appendasset(neural,'STN-GPe image',[52,317,69,33.2],part(19))
# The physical column already contains its LFR; a short caption covers all examples.
lbl=b.lib.tb(6999,'Physical examples',(46,292,230,16),'STN–GPe · ASML · Canon',11,'FFFFFF','Aptos')
tr.appendChild(d.importNode(frag(lbl),True))
logo=next(n for n in first(D.parseString(old[part(25)]),'p:spTree').childNodes if n.nodeType==1 and els(n,'p:cNvPr') and 'logo' in name(n).lower())
appendasset(logo,'Original TUe logo',[666,379,36,20],part(25))
for node in list(d.documentElement.childNodes):
 if node.nodeType==1 and (node.tagName=='p:timing' or node.tagName=='p:transition' or (node.tagName=='mc:AlternateContent' and els(node,'p:transition'))):d.documentElement.removeChild(node)
d.documentElement.appendChild(d.importNode(frag('<p:transition><p:fade/></p:transition>'),True))
files[part(26)]=d.toxml(encoding='utf-8');files[rp(part(26))]=rd.toxml(encoding='utf-8')

# Replace the rejected derivation notes with concise matching presentation notes.
notes={20:'After the LFR is defined, extract only its nominal PDE block. The rest of the feedback connection stays fixed. Introduce the original property list and highlight exact equivalent dynamics.',21:'Show only the starting nominal homogeneous ODE-PDE and the final PIE, with no derivation or substitution on screen. Set w=0 and u=0 in the nominal STN-GPe block: tau_S xdot_S=-x_S, tau_G xdot_G=-x_G; partial_t phi_ij=-tau_ij^{-1}partial_s phi_ij and phi_ij(t,0)=x_i(t). Channels are GS,SG,GG. The final compact form is T xdot_f=A x_f. Boundary conditions are built into T. For technical reference only: x_f=(x,partial_s phi), T reconstructs the compatible PDE state. Initial histories must match.',22:'Bounded PI operators represent the system dynamics and outputs. Here w denotes the grouped exogenous input to the linear system, as in the original generic PIE slide.',23:'The PI operator class is closed under addition, composition, adjoints and block concatenation for compatible dimensions.',24:'P is self-adjoint and coercive. For alpha>0, the displayed inequality is a sufficient Lyapunov condition for exponential stability of the reconstructed PDE state. Polynomial PI parameterization gives sufficient LMIs; exact model conversion does not imply a lossless finite certificate search.',25:'Highlight the original controller-synthesis property. Synthesis is carried out in PIE coordinates; the corresponding controller is implemented in the original system. The displayed K is a generic controller block, not a claim that arbitrary output-feedback synthesis is convex.',26:'Restore the two clear pillars: distributed physical models with a PDE nominal block on the left, and the PIE solution representation on the right. The forward arrow gives tractability, and the reverse arrow returns solutions. PIEs are the first pillar of the solution: a representation enabling analysis and synthesis using LMIs. Robust treatment of Delta follows later.'}
for i,txt in notes.items():
 # Preserve prior historical notes in the archive, not as conflicting narration.
 pp=part(i);nr=next((r for r in els(D.parseString(files[rp(pp)]),'Relationship') if r.getAttribute('Type').endswith('/notesSlide')),None)
 if nr is not None:
  nk=posixpath.normpath('ppt/slides/'+nr.getAttribute('Target'));files.pop(nk,None)
 b.add_notes(files,i,txt)
write(B/'staged.pptx',files)
# Inspectable end state of slide 20, before adding native animation.
preview=files.copy();dd=D.parseString(preview[part(20)]);tt=first(dd,'p:spTree')
for node in list(tt.childNodes):
 if node.nodeType==1 and els(node,'p:cNvPr') and name(node) in ['Surrounding LFR','Extracted PDE block']:tt.removeChild(node)
preview[part(20)]=dd.toxml(encoding='utf-8');write(B/'static.pptx',preview)
(B/'source.json').write_text(json.dumps(dict(source=str(b.SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper())))
print('Restored property-list slides, two red pillars, and staged PDE extraction.')
