from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import sys,json,re,posixpath,hashlib,importlib.util
import numpy as np
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import els,first
from build_video_overlays import namespaces
spec=importlib.util.spec_from_file_location('sv',ROOT/'Presentation/SectorIQC/build_visualization.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
b=v.b;INK=v.INK;RED=v.RED;BLUE=v.BLUE;GREEN=v.GREEN;GRAY=v.GRAY
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy();parts=json.loads((B/'parts.json').read_text())
data=np.load(ROOT/'Presentation/SectorIQC/Simulation/STN_GPe/stn_gpe_sector_data.npz');BETA=float(data['beta'][0]);STAR=float(data['zStar'][0])
def delta(z):return 150*(np.tanh(2*(STAR+np.asarray(z))/300)-np.tanh(2*STAR/300))
def part(i):return parts[i-1]
def rp(p):return posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def sid(n):return first(n,'p:cNvPr').getAttribute('id')
def name(n):return first(n,'p:cNvPr').getAttribute('name')
def shapes(d):return [n for n in first(d,'p:spTree').childNodes if n.nodeType==1 and els(n,'p:cNvPr') and n.tagName!='p:nvGrpSpPr']
def frag(s):return D.parseString(f'<root {b.DECL}>'+s+'</root>').documentElement.firstChild
def rect(n):
 xf=first(n,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 return [int(o.getAttribute(k))/12700 for k in ['x','y']]+[int(e.getAttribute(k))/12700 for k in ['cx','cy']]
def geom(n,box):
 xf=first(n,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 for k,val in zip(['x','y'],box[:2]):o.setAttribute(k,b.emu(val))
 for k,val in zip(['cx','cy'],box[2:]):e.setAttribute(k,b.emu(val))
def run(self,t,c=None,plain=False):return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in t)
v.M.r=run
def tilde(m,s):return '<m:acc><m:accPr><m:chr m:val="̃"/>'+m.ctrl()+'</m:accPr><m:e>'+m.r(s)+'</m:e></m:acc>'
def dot(m,s):return '<m:acc><m:accPr><m:chr m:val="̇"/>'+m.ctrl()+'</m:accPr><m:e>'+m.r(s)+'</m:e></m:acc>'
def vec(m,rr):return m.d(m.matrix([[r] for r in rr]),'[',']')
def mat(m,rr):return m.d(m.matrix([[m.r(r) for r in row] for row in rr]),'[',']')
def norm2(m,e):return m.sup(m.d(e,'‖','‖'),m.r('2',plain=True))
def sigma(m):return norm2(m,tilde(m,'z'))+m.r('−')+norm2(m,tilde(m,'w'))
def integral(m,e):return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('T')+'</m:sup><m:e>'+e+'</m:e></m:nary>'
def group(nm,nodes,box,ident):
 x,y,w,h=box
 return frag(f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{ident}" name="{nm}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{b.emu(x)}" y="{b.emu(y)}"/><a:ext cx="{b.emu(w)}" cy="{b.emu(h)}"/><a:chOff x="{b.emu(x)}" y="{b.emu(y)}"/><a:chExt cx="{b.emu(w)}" cy="{b.emu(h)}"/></a:xfrm></p:grpSpPr>'+''.join(n if isinstance(n,str) else n.toxml() for n in nodes)+'</p:grpSp>')
def remap(node,start,nm):
 mp={}
 for nv in els(node,'p:cNvPr'):
  val=nv.getAttribute('id')
  if val not in mp:start+=1;mp[val]=str(start)
  nv.setAttribute('id',mp[val])
 first(node,'p:cNvPr').setAttribute('name',nm);return node
def clear_transition(d):
 for n in list(d.documentElement.childNodes):
  if n.nodeType==1 and (n.tagName in ['p:transition','p:timing'] or (n.tagName=='mc:AlternateContent' and els(n,'p:transition'))):d.documentElement.removeChild(n)
def transition(d,morph=False):
 if morph:
  s='<mc:AlternateContent xmlns:mc="'+b.NS['mc']+'" xmlns:p159="http://schemas.microsoft.com/office/powerpoint/2015/09/main" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main"><mc:Choice Requires="p159"><p:transition p14:dur="1100"><p159:morph option="byObject"/></p:transition></mc:Choice><mc:Fallback><p:transition><p:fade/></p:transition></mc:Fallback></mc:AlternateContent>'
 else:s='<p:transition xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" p14:dur="450"><p:fade/></p:transition>'
 d.documentElement.appendChild(d.importNode(frag(s),True))

# Give Delta its own native Morph object, preserving the user's pillar slide.
d33=D.parseString(files[part(33)]);namespaces(d33);tr33=first(d33,'p:spTree')
lfr=next(n for n in shapes(d33) if name(n)=='Restored PIE LFR connections');outer=rect(lfr);xf=first(lfr,'a:xfrm');co=first(xf,'a:chOff');ce=first(xf,'a:chExt')
cb=[int(co.getAttribute(k))/12700 for k in ['x','y']]+[int(ce.getAttribute(k))/12700 for k in ['cx','cy']]
dc=[]
for n in list(lfr.childNodes):
 if n.nodeType==1 and els(n,'p:cNvPr') and name(n) in ['Uncertainty','Uncertainty label']:dc.append(n.cloneNode(True));lfr.removeChild(n)
db=rect(next(n for n in dc if name(n)=='Uncertainty'));focus=group('!!Delta focus',dc,db,10000)
geom(focus,[outer[0]+(db[0]-cb[0])*outer[2]/cb[2],outer[1]+(db[1]-cb[1])*outer[3]/cb[3],db[2]*outer[2]/cb[2],db[3]*outer[3]/cb[3]])
remap(focus,10000,'!!Delta focus');tr33.appendChild(d33.importNode(focus,True));files[part(33)]=d33.toxml(encoding='utf-8')

class Slide(v.Slide):
 def __init__(self,num,title):
  super().__init__();self.i=1000;self.num=num;self.extra=[]
  self.label('Title',360,45,title,25,w=648,bold=True);self.parts[-1]=self.parts[-1].replace('algn="ctr"','algn="l"')
 def eq(self,n,x,y,fn,size=20,w=640,color=INK):self.equation(n,x,y,fn,size,w,color)
 def text(self,n,x,y,t,size=15,color=INK,w=640,bold=False):self.label(n,x,y,t,size,color,w,bold)
 def packed(self,nm,fn,box):
  child=Slide.__new__(Slide);v.Slide.__init__(child);child.i=self.i+1;fn(child);self.i=child.i+1
  self.extra.append(group(nm,child.parts,box,self.ident()).toxml())
 def finish(self,physical=None,morph=False):
  physical=physical or self.num
  self.text('Footer',236,390,'Msc Defence T.M. Lenssen',8,GRAY,w=400);self.parts[-1]=self.parts[-1].replace('algn="ctr"','algn="l"')
  self.text('Slide number',634,390,str(self.num),8,GRAY,w=28)
  tree='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+''.join(self.parts+self.extra)
  d=D.parseString(b.lib.xml(f'<p:sld {b.DECL} mc:Ignorable="a14"><p:cSld><p:spTree>{tree}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'));transition(d,morph)
  files[f'ppt/slides/slide{physical}.xml']=d.toxml(encoding='utf-8');return d

def plot(s,bounds=True,thick=False):
 p=lambda z,w:(188+.27*z,190-.20*w)
 if bounds:
  for sign in [-1,1]:s.poly('Sector region',[p(0,0),p(sign*500,0),p(sign*500,sign*500*BETA)],width=0,filled='EDF2F5')
 s.path('Input axis',[p(-525,0),p(540,0)],color='A9ADB2',width=.7)
 s.path('Output axis',[p(0,-415),p(0,420)],color='A9ADB2',width=.7)
 if bounds:
  s.poly('Upper sector line',[p(-500,-500*BETA),p(500,500*BETA)],GRAY,3.2 if thick else .9)
  s.poly('Lower sector line',[p(-500,0),p(500,0)],GRAY,3.2 if thick else .9)
 s.poly('Shifted sigmoid curve',[p(z,float(delta(z))) for z in np.linspace(-500,500,301)],RED,1.8)
def graphlabels(s,bounds=True):
 s.eq('Graph input',343,193,lambda m:m.r('z'),13,w=25)
 s.eq('Graph output',188,91,lambda m:m.r('w'),13,w=30)
 for z in [-400,400]:s.text('Input tick '+str(z),188+.27*z,211,str(z),8,GRAY,w=42)
 s.text('Origin',178,202,'0',8,GRAY,w=18)
 if bounds:
  s.eq('Upper boundary label',308,106,lambda m:m.r('βz'),13,w=70)
  s.eq('Lower boundary label',294,230,lambda m:m.r('αz=0'),12,w=90)
 s.text('Graph description',188,309,'Shifted STN activation',12,GRAY,w=295)

s=Slide(34,'Describe the nonlinearity Δ')
# Two groups reveal the sector only after the shifted curve is established.
tmp=v.Slide();tmp.i=1100;plot(tmp,True,True)
for xml in tmp.parts:
 node=frag(xml);nm=name(node)
 if nm in ['Sector region','Upper sector line','Lower sector line']:
  nm='Sector bounds '+nm;first(node,'p:cNvPr').setAttribute('name',nm)
 s.parts.append(node.toxml())
s.i=1200;graphlabels(s)
ff=focus.cloneNode(True);geom(ff,[482,101,76,76]);remap(ff,1500,'!!Delta focus');s.extra.append(ff.toxml())
s.path('Delta input',[(408,139),(482,139)],width=1)
s.path('Delta output',[(558,139),(655,139)],width=1)
s.eq('Delta input label',440,117,lambda m:m.r('z'),17,w=50)
s.eq('Delta output label',612,117,lambda m:m.r('w'),17,w=50)
s.eq('Shifted map',520,211,lambda m:m.r('w=Δ')+m.d(m.r('z'))+m.r(',  Δ')+m.d(m.r('0'))+m.r('=0'),21,w=326)
s.eq('Sector condition',520,270,lambda m:m.r('α≤')+m.frac(m.r('Δ')+m.d(m.r('z')),m.r('z'))+m.r('≤β,  z≠0'),20,w=330)
s.eq('Sector values',520,320,lambda m:m.r('α=0,  β≈0.7344'),17,w=330)
s.text('Shifted explanation',360,362,'The sector is measured about the shifted equilibrium.',15,w=650)
s.finish(morph=True)
# Copy Delta's fallback image relations from 33; all target media remain intact.
rd=D.parseString(files[rp(part(34))]);r33={r.getAttribute('Id'):r for r in els(D.parseString(files[rp(part(33))]),'Relationship')};dd=D.parseString(files[part(34)]);ff=next(n for n in shapes(dd) if name(n)=='!!Delta focus');mp={}
for el in ff.getElementsByTagName('*'):
 for att in ['r:embed','r:link','r:id']:
  rid=el.getAttribute(att)
  if rid in r33:
   if rid not in mp:
    rr=r33[rid].cloneNode(True);new='rIdZoom'+str(len(els(rd,'Relationship')));rr.setAttribute('Id',new);rd.documentElement.appendChild(rd.importNode(rr,True));mp[rid]=new
   el.setAttributeNS(b.NS['r'],att,mp[rid])
files[part(34)]=dd.toxml(encoding='utf-8');files[rp(part(34))]=rd.toxml(encoding='utf-8')

s=Slide(35,'The sector gives two signed gaps')
# The video contains only curves, axes and moving gaps; all text stays editable.
graphlabels(s)
s.eq('Upper gap',520,132,lambda m:m.r('a=βz−w',BLUE),23,w=325)
s.eq('Lower gap',520,179,lambda m:m.r('b=w−αz',GREEN),23,w=325)
s.eq('Positive input',520,235,lambda m:m.r('z>0:  a>0, b>0'),20,w=325)
s.eq('Negative input',520,235,lambda m:m.r('z<0:  a<0, b<0'),20,w=325)
s.eq('Gap product',520,281,lambda m:m.r('ab≥0',GREEN),28,w=300)
s.eq('Gap filter',360,338,lambda m:vec(m,[m.r('a',BLUE),m.r('b',GREEN)])+m.r('=')+mat(m,[['β','−1'],['−α','1']])+vec(m,[m.r('z'),m.r('w')]),21,w=650)
s.text('Zero gaps',360,371,'Gaps can be zero at the origin or on a sector boundary.',11,GRAY,w=650)
s.finish()

s=Slide(36,'Turn the gaps into a dissipative description')
s.eq('Gap transformation',360,118,lambda m:vec(m,[tilde(m,'z'),tilde(m,'w')])+m.r('=')+mat(m,[['v','1'],['v','−1']])+vec(m,[m.r('a',BLUE),m.r('b',GREEN)])+m.r(',  v>0'),27,w=650)
s.text('Sum versus difference',360,187,'Same-sign gaps: the weighted sum has the larger magnitude.',17,w=655)
s.eq('Supply identity',360,242,lambda m:m.r('σ=')+sigma(m)+m.r('=')+m.sup(m.d(m.r('va+b')),m.r('2'))+m.r('−')+m.sup(m.d(m.r('va−b')),m.r('2'))+m.r('=4vab≥0',GREEN),21,w=680)
s.eq('Delta dissipativity',360,313,lambda m:m.sub(m.r('S'),m.r('Δ'))+m.r('≡0:   0≤')+integral(m,m.r('σ')+m.d(m.r('t'))+m.r('dt'))+m.r(',  ∀T≥0'),22,w=660)
s.text('Dissipativity meaning',360,359,'The transformed output cannot supply more energy than its input.',16,GREEN,w=660)
s.finish()

s=Slide(37,'Construct Θ and connect it to the LFR')
theta=lambda m:m.r('Θ=')+mat(m,[['v','1'],['v','−1']])+mat(m,[['β','−1'],['−α','1']])
s.eq('Construct Theta',360,145,theta,29,w=650)
s.eq('Filtered signals',360,235,lambda m:vec(m,[tilde(m,'z'),tilde(m,'w')])+m.r('=Θ')+vec(m,[m.r('z'),m.r('w')]),26,w=650)
s.text('Filter role',360,314,'Θ transforms the existing signals z and w.',18,w=650)
def lfrdraw(d):
 d.block('Delta',232,128,60,48,'Δ',25,dashed=True)
 d.block('PIE',232,234,86,70,'PIE',25)
 d.block('Controller K',232,328,56,42,'K',23)
 d.path('Plant to Delta',[(189,213),(139,213),(139,128),(202,128)],width=1)
 d.path('Delta to plant',[(262,128),(325,128),(325,213),(275,213)],width=1)
 d.path('Measured output to K',[(275,255),(325,255),(325,328),(260,328)],width=1)
 d.path('Controller to plant',[(204,328),(139,328),(139,255),(189,255)],width=1)
 for nm,xx,yy in [('z',120,176),('w',346,176),('u',120,282),('y',346,282)]:d.equation('LFR '+nm,xx,yy,lambda m,nm=nm:m.r(nm),17,w=35)
 d.path('z signal tap to Theta',[(165,128),(165,80),(420,80),(420,112),(446,112)],width=1)
 d.path('w signal tap to Theta',[(300,128),(300,148),(446,148)],width=1)
 d.block('Filter Theta',492,130,92,76,'Θ',27)
 d.path('Filtered z output',[(538,112),(615,112)],width=1)
 d.path('Filtered w output',[(538,148),(615,148)],width=1)
 d.equation('Filtered z label',641,112,lambda m:tilde(m,'z'),19,w=45)
 d.equation('Filtered w label',641,148,lambda m:tilde(m,'w'),19,w=45)
 d.equation('Connected filter formula',505,249,theta,17,w=340)
 d.equation('Connected supply',505,309,lambda m:m.r('σ=')+sigma(m)+m.r('≥0',GREEN),18,w=330)
s.packed('Connected LFR',lfrdraw,[105,78,562,273])
s.finish()

# Align the simulation's displayed supply with sigma=4ab at v=1.
d39=D.parseString(files[part(39)]);namespaces(d39);tr39=first(d39,'p:spTree')
axis=None
for n in shapes(d39):
 nm=name(n)
 if nm=='Vertical axis Supply function':axis=n
 if nm=='Editable label Supply function':
  for t in els(n,'a:t'):
   if t.firstChild:t.firstChild.data='Accumulated supply'
 if nm in ['Editable label 1000','Editable label 2000','Editable label 3000']:
  for t in els(n,'a:t'):
   if t.firstChild:t.firstChild.data=str(4*int(t.firstChild.data))
if axis is not None:
 bb=rect(axis);rr=first(axis,'a:xfrm').getAttribute('rot')
 ss=v.Slide();ss.i=9000
 ss.equation('Vertical axis Supply function',bb[0]+bb[2]/2,bb[1]+bb[3]/2,lambda m:integral(m,m.sub(m.r('σ'),m.r('i'))+m.d(m.r('t'))+m.r('dt'))+m.r('≥0'),16,w=bb[2])
 n=frag(ss.parts[0]);geom(n,bb)
 if rr:first(n,'a:xfrm').setAttribute('rot',rr)
 tr39.replaceChild(d39.importNode(n,True),axis)
files[part(39)]=d39.toxml(encoding='utf-8')

# Insert the missing complementary plant certificate after the sector simulation.
newnum=max(int(re.search(r'slide(\d+)\.xml$',n)[1]) for n in files if re.fullmatch(r'ppt/slides/slide\d+\.xml',n))+1
newpart=f'ppt/slides/slide{newnum}.xml'
s=Slide(40,'Why this gives closed-loop stability')
s.text('Certificate setup',360,83,'For the unforced loop, find a common storage V.',15,GRAY,w=650)
s.eq('Requested dissipativity inequality',360,130,lambda m:dot(m,'V')+m.d(m.r('t'))+m.r('+')+sigma(m)+m.r('<0'),27,w=660)
s.text('Strictness qualification',360,163,'For nonzero states; use a uniform strict margin.',12,GRAY,w=650)
s.eq('Sector condition for stability',177,220,lambda m:m.r('σ≥0',GREEN),25,w=275)
s.eq('Uniform plant certificate',501,220,lambda m:dot(m,'V')+m.r('+σ≤−ε')+norm2(m,m.r('x'))+m.r(', ε>0'),22,w=365)
s.eq('Closed loop decay',360,273,lambda m:m.r('⇒  ')+dot(m,'V')+m.r('≤−ε')+norm2(m,m.r('x')),27,w=650)
s.eq('Coercive storage and rate',360,319,lambda m:m.r('m')+norm2(m,m.r('x'))+m.r('≤V≤M')+norm2(m,m.r('x'))+m.r('  ⇒  V')+m.d(m.r('t'))+m.r('≤')+m.sup(m.r('e'),m.r('−εt/M'))+m.r('V')+m.d(m.r('0')),19,w=660)
s.text('Robust conclusion',360,359,'Stable for every Δ in the sector.',19,GREEN,w=650,bold=True)
s.finish(newnum)
newrel=D.parseString(files[rp(part(36))])
for r in list(els(newrel,'Relationship')):
 if not r.getAttribute('Type').endswith('/slideLayout'):r.parentNode.removeChild(r)
files[rp(newpart)]=newrel.toxml(encoding='utf-8')
pres=D.parseString(files['ppt/presentation.xml']);lst=first(pres,'p:sldIdLst');ids=els(pres,'p:sldId')
ns=pres.createElement('p:sldId');ns.setAttribute('id',str(max(int(n.getAttribute('id')) for n in ids)+1));ns.setAttributeNS(b.NS['r'],'r:id','rIdSectorStability');lst.insertBefore(ns,ids[39])
pr=D.parseString(files['ppt/_rels/presentation.xml.rels']);r=pr.createElement('Relationship');r.setAttribute('Id','rIdSectorStability');r.setAttribute('Type',b.NS['r']+'/slide');r.setAttribute('Target',f'slides/slide{newnum}.xml');pr.documentElement.appendChild(r)
ct=D.parseString(files['[Content_Types].xml']);ov=ct.createElement('Override');ov.setAttribute('PartName','/'+newpart);ov.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');ct.documentElement.appendChild(ov)
for key,doc in [('ppt/presentation.xml',pres),('ppt/_rels/presentation.xml.rels',pr),('[Content_Types].xml',ct)]:files[key]=doc.toxml(encoding='utf-8')
parts.insert(39,newpart)
# Correct visible slide numbers in this imported section and following slides.
for i,p in enumerate(parts,1):
 if i<34:continue
 dd=D.parseString(files[p]);changed=False
 for n in shapes(dd):
  if name(n).lower()=='slide number' or 'slide number placeholder' in name(n).lower():
   for t in els(n,'a:t'):
    if t.firstChild and t.firstChild.data!=str(i):t.firstChild.data=str(i);changed=True
 if changed:files[p]=dd.toxml(encoding='utf-8')

notes={34:f'Zoom from the Delta block in the existing LFR. Delta is the actual shifted STN activation: Delta(z)=150[tanh(2(zStar+z)/300)-tanh(2zStar/300)], zStar={STAR}. First show the shifted curve with Delta(0)=0, then reveal the thick sector bounds alpha=0 and beta={BETA}. This is a secant sector, not a derivative bound.',35:'The input sweep z(t)=250 sin(2*pi*t/12) illustrates the memoryless graph, not a new neural closed-loop simulation. The signed gaps are a=beta z-w and b=w-alpha z. For the interior sample points a,b are positive at positive z and negative at negative z. Globally use nonnegative/nonpositive: gaps can vanish at the origin or a sector boundary, including the tight positive tangent. All text labels are editable overlays.',36:'Use the weighted sum/difference transform [[v,1],[v,-1]] with v>0. Then ztilde=v*a+b and wtilde=v*a-b, so sigma=|ztilde|^2-|wtilde|^2=4vab>=0. A memoryless sector graph is dissipative with zero storage S_Delta=0. The alternative matrix [[v,v],[1,-1]] requires v>=1 in general and is not the stated arbitrary-positive-weight identity. For vector channels apply componentwise and sum. No multiplier Pi is needed.',37:'Theta is the cascade of the signed-gap map [[beta,-1],[-alpha,1]] and the weighted sum/difference map [[v,1],[v,-1]]. It observes the existing LFR signals z,w and returns ztilde,wtilde; it does not replace the original nonlinearity or alter the feedback connection. The cleaned schematic follows the supplied LFR, with the original Delta–PIE loop, solid K block, and two signal taps to Theta. The simulation uses v=1.',39:'The unchanged STN-GPe sector simulation curves originally displayed integrals of q_i=a_i*b_i. With v=1 the norm-difference supply sigma_i=4q_i. The supply-axis tick values have therefore been multiplied by four; curve geometry and all simulated state trajectories are unchanged. Integral values are nonnegative for every T, not necessarily strictly positive at zero. This follows from the pointwise sector property, not merely from inspecting a finite sampled simulation. The plotted trajectory does not prove closed-loop stability.',newnum:'Assume an unforced well-posed feedback interconnection and a common differentiable/coercive storage V with m||x||^2<=V<=M||x||^2, m,M>0. Seek a plant/controller certificate Vdot+sigma<=-epsilon||x||^2 uniformly, epsilon>0, for the relevant augmented plant signals/states. For the static sector filter above, sigma>=0 pointwise on every admissible Delta graph, hence Vdot<=-epsilon||x||^2<=-(epsilon/M)V and exponential decay follows. The first displayed strict inequality is for nonzero states; at the equilibrium its value is zero. In a PIE, use the reconstructed physical state norm and compatible solution regularity. For a general dynamic filter with only integral nonnegativity, the argument must instead use the integrated inequality and appropriate augmented storage; the pointwise step is specific to this static sector example. The simulation alone supplies no plant certificate.'}
for number,txt in notes.items():
 physical=newnum if number==newnum else int(re.search(r'slide(\d+)',part(number))[1])
 b.add_notes(files,physical,txt)
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,vv in data.items():z.writestr(n,vv)
write(B/'staged.pptx',files)
(B/'output_parts.json').write_text(json.dumps(parts))
(B/'source.json').write_text(json.dumps(dict(source=str(b.SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper(),slides=len(parts),newpart=newpart)))
print('Built sector-to-dissipativity sequence and inserted stability slide 40; existing videos retained.')
