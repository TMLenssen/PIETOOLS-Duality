"""Editable shifted-sigmoid sector -> gap filter -> dissipativity presentation."""
from pathlib import Path
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import importlib.util,zipfile,json,hashlib,math
import numpy as np

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/shifted_sector'
spec=importlib.util.spec_from_file_location('sector_base',Path(__file__).with_name('build_visualization.py'))
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
b=v.b;BLUE=v.BLUE;GREEN=v.GREEN;RED=v.RED;GRAY=v.GRAY
SOURCE=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Sector IQC - Editable.pptx')
with np.load(Path(__file__).parent/'Simulation/STN_GPe/stn_gpe_sector_data.npz') as data:
 ZSTAR=data['zStar'].copy();BETA=data['beta'].copy()
M=300.;STAR=float(ZSTAR[0]);BETA_S=float(BETA[0])
def phi(z):return M/2*(np.tanh(2*(STAR+np.asarray(z))/M)-np.tanh(2*STAR/M))
def run(self,t,c=None,plain=False):
 return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in t)
v.M.r=run
def tilde(m,s):return '<m:acc><m:accPr><m:chr m:val="̃"/>'+m.ctrl()+'</m:accPr><m:e>'+m.r(s)+'</m:e></m:acc>'
def vector(m,rows):return m.d(m.matrix([[r] for r in rows]),'[',']')
def matrix(m,rows):return m.d(m.matrix([[m.r(c) for c in row] for row in rows]),'[',']')
def integral(m,body):return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('T')+'</m:sup><m:e>'+body+'</m:e></m:nary>'
def plot(s,gaps=False):
 def p(z,w):return 188+.27*z,181-.20*w
 for sign in [-1,1]:s.poly('Global sector [0, beta]',[p(0,0),p(sign*500,0),p(sign*500,sign*500*BETA_S)],width=0,filled='EDF2F5')
 s.path('Input axis',[p(-525,0),p(545,0)],color='A9ADB2',width=.7)
 s.path('Output axis',[p(0,-415),p(0,420)],color='A9ADB2',width=.7)
 s.poly('Upper sector boundary',[p(-500,-500*BETA_S),p(500,500*BETA_S)],GRAY,.9)
 s.poly('Shifted STN sigmoid',[p(z,float(phi(z))) for z in np.linspace(-500,500,241)],RED,1.8)
 s.equation('Graph input',342,184,lambda m:m.r('z'),12,w=25)
 s.equation('Graph output',188,86,lambda m:m.r('w'),12,w=30)
 s.equation('Upper sector line',315,97,lambda m:m.r('βz'),12,w=55)
 s.equation('Lower sector line',296,214,lambda m:m.r('αz=0'),11,w=72)
 for z in [-400,400]:
  x,y=p(z,0);s.path('Input tick',[(x,y-2),(x,y+2)],arrow=False,color=GRAY,width=.5);s.label('Input tick value',x,y+15,str(z),8,GRAY,w=42)
 s.label('Origin',177,194,'0',8,GRAY,w=18)
 if gaps:
  z=135.;w=float(phi(z));x,y=p(z,w)
  for name,lo,hi,col in [('a: upper gap',w,BETA_S*z,BLUE),('b: lower gap',0,w,GREEN)]:
   s.path(name,[p(z,lo),p(z,hi)],arrow=False,color=col,width=3)
  for val in [0,w,BETA_S*z]:
   yy=p(z,val)[1];s.path('Gap endpoint',[(x-3,yy),(x+3,yy)],arrow=False,color=v.INK,width=.6)
  s.dot(x,y)
 s.label('Plot identity',188,279,'STN activation about its equilibrium',10,GRAY,w=290)
def block(s):
 s.path('Nonlinearity input',[(419,139),(493,139)],color=v.INK,width=1)
 s.path('Nonlinearity output',[(547,139),(650,139)],color=v.INK,width=1)
 s.outline('Shifted activation block',(493,115,54,48),RED,1)
 s.equation('Nonlinearity label',520,139,lambda m:m.r('φ',RED),25,w=45)
 s.equation('Input label',446,120,lambda m:m.r('z'),15,w=45)
 s.equation('Output label',604,120,lambda m:m.r('w'),15,w=45)
def make(n):
 s=v.Slide();titles=['The shifted sigmoid lies in a sector','The sector gives two signed gaps','Transform the gaps into input and output','The transformed nonlinearity is dissipative']
 s.label('Title',360,46,titles[n-1],23,w=648,bold=True);s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
 plot(s,n>1)
 if n<3:block(s)
 if n==1:
  s.equation('Shifted map',525,200,lambda m:m.r('w=φ')+m.d(m.r('z'))+m.r(',   φ')+m.d(m.r('0',plain=True))+m.r('=0'),17,w=300)
  s.equation('Global sector',525,235,lambda m:m.r('α=0,   β≈0.7344'),17,w=305)
  def shifted(m):
   term=lambda arg:m.r('tanh',plain=True)+m.d(arg)
   zstar=m.sup(m.r('z'),m.r('*',plain=True))
   return m.r('φ')+m.d(m.r('z'))+m.r('=')+m.frac(m.r('M'),m.r('2',plain=True))+m.d(term(m.frac(m.r('2')+m.d(zstar+m.r('+z')),m.r('M')))+m.r('−')+term(m.frac(m.r('2')+zstar,m.r('M'))),'[',']')
  s.equation('Equilibrium-shifted sigmoid',360,321,shifted,16,w=650)
  s.equation('STN parameters',360,357,lambda m:m.r('M=300,   ')+m.sup(m.r('z'),m.r('*',plain=True))+m.r('≈−196.17'),13,w=600)
 elif n==2:
  s.equation('Upper gap',525,199,lambda m:m.r('a=βz−w',BLUE),20,w=285)
  s.equation('Lower gap',525,237,lambda m:m.r('b=w−αz=w',GREEN),20,w=320)
  s.equation('Gap filter',360,319,lambda m:vector(m,[m.r('a',BLUE),m.r('b',GREEN)])+m.r('=')+matrix(m,[['β','−1'],['0','1']])+vector(m,[m.r('z'),m.r('w')]),20,w=650)
  s.label('Gap interpretation',360,362,'Inside the sector, the two gaps have the same sign.',15,w=650)
 elif n==3:
  s.equation('Transformed input',525,130,lambda m:tilde(m,'z')+m.r('=a+b=βz'),20,w=320)
  s.equation('Transformed output',525,181,lambda m:tilde(m,'w')+m.r('=a−b=βz−2w'),20,w=325)
  s.equation('Contraction',525,234,lambda m:m.d(tilde(m,'w'),'|','|')+m.r('≤')+m.d(tilde(m,'z'),'|','|'),23,w=250)
  s.equation('Complete filter',360,324,lambda m:vector(m,[tilde(m,'z'),tilde(m,'w')])+m.r('=')+matrix(m,[['1','1'],['1','−1']])+matrix(m,[['β','−1'],['0','1']])+vector(m,[m.r('z'),m.r('w')]),19,w=660)
  s.label('Scaling choice',360,365,'Choose unit scaling: the transformed input depends only on z.',13,GRAY,w=650)
 else:
  s.path('Transformed input',[(413,133),(492,133)],color=v.INK,width=1)
  s.path('Transformed output',[(552,133),(650,133)],color=v.INK,width=1)
  s.outline('Transformed activation',(492,109,60,48),RED,1)
  s.equation('Transformed activation label',522,133,lambda m:tilde(m,'φ'),24,w=50)
  s.equation('Transformed input label',444,112,lambda m:tilde(m,'z'),16,w=45)
  s.equation('Transformed output label',604,112,lambda m:tilde(m,'w'),16,w=45)
  s.label('Energy interpretation',524,202,'Output energy cannot exceed input energy.',13,w=325)
  s.equation('Zero storage',524,243,lambda m:m.r('V≡0'),21,w=280)
  def supply(m):return m.sup(tilde(m,'z'),m.r('2',plain=True))+m.r('−')+m.sup(tilde(m,'w'),m.r('2',plain=True))
  s.equation('Supply rate',360,316,lambda m:m.r('σ=')+supply(m)+m.r('=4ab≥0',GREEN),21,w=650)
  s.equation('Dissipativity inequality',360,357,lambda m:m.r('V')+m.d(m.r('T'))+m.r('−V')+m.d(m.r('0'))+m.r('=0≤')+integral(m,m.r('σ')+m.d(m.r('t'))+m.r(' dt'))+m.r('   ∀T≥0'),18,w=650)
 s.label('Footer',236,390,'Msc Defence T.M. Lenssen',8,GRAY,w=400);s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
 s.label('Slide number',634,390,str(n),8,GRAY,w=28)
 tree='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+''.join(s.parts)
 return b.lib.xml(f'<p:sld {b.DECL} mc:Ignorable="a14"><p:cSld><p:spTree>{tree}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')
NOTES=[
 f'The graph is the actual equilibrium-shifted STN activation used in the Parkinsonian simulation: phi(z)=M/2[tanh(2(zStar+z)/M)-tanh(2zStar/M)], M=300, zStar={STAR:.12f}. Thus phi(0)=0. The horizontal and vertical equilibrium shifts must both be included. Global sector alpha=0, beta={BETA_S:.15f}; the displayed beta is approximate, while the graph uses the full value. Beta is the maximum secant phi(z)/z, not the maximum derivative. The corresponding GPe channel has M=400, zStar={ZSTAR[1]:.12f}, beta={BETA[1]:.15f}. The global lower sector bound is zero because this sigmoid saturates. Values come from the existing STN_GPe sector data; the local controller certificate is not used as a global bound.',
 'The upper and lower signed gaps are a=beta*z-w and b=w-alpha*z=w. The sector boundary lines pass through the shifted equilibrium (0,0). For z>0 the two gaps are nonnegative; for z<0 both are nonpositive. At zero, w=0 and both gaps vanish. The displayed filter simply computes these gaps; it does not replace the nonlinearity by a linear system.',
 'Choose the constant scaling s=1 in [[s,1],[s,-1]]. This s is not a Laplace variable or spatial coordinate. Then ztilde=a+b=beta*z and wtilde=a-b=beta*z-2w. Their squared difference is 4ab, nonnegative throughout the sector, so |wtilde|<=|ztilde|. Since beta>0, this defines the memoryless transformed map phitilde(v)=v-2phi(v/beta), with input v=ztilde and output wtilde. The original nonlinearity is still present.',
 'The transformed memoryless nonlinearity is dissipative with supply sigma=ztilde^2-wtilde^2=4ab and storage V identically zero. The supply is pointwise nonnegative, so its integral is nonnegative for every finite T>=0. For two channels, sum the channel supplies; for a spatial pointwise nonlinearity also integrate over space. These are mathematical input/output energy measures, not necessarily physical energy. No multiplier Pi or IQC formalism is needed for this explanation. Dissipativity of the isolated nonlinearity does not by itself prove stability of its feedback interconnection.'
]
def main():
 with zipfile.ZipFile(OUT/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
 pres=D.parseString(files['ppt/presentation.xml']);assert len(pres.getElementsByTagName('p:sldId'))==4
 for i in range(1,5):
  files[f'ppt/slides/slide{i}.xml']=make(i)
  # Preserve the note page structure and replace its body text only.
  npart=f'ppt/notesSlides/notesSlide{i}.xml';doc=D.parseString(files[npart])
  body=next(sp for sp in doc.getElementsByTagName('p:sp') if any(ph.getAttribute('type')=='body' for ph in sp.getElementsByTagName('p:ph')))
  tx=body.getElementsByTagName('p:txBody')[0]
  for p in list(tx.getElementsByTagName('a:p')):tx.removeChild(p)
  node=D.parseString(f'<a:p xmlns:a="{b.NS["a"]}"><a:r><a:t>{escape(NOTES[i-1])}</a:t></a:r></a:p>').documentElement;tx.appendChild(doc.importNode(node,True));files[npart]=doc.toxml(encoding='utf-8')
 # Check global sector and transformation algebra against both shifted activations.
 zz=np.r_[np.linspace(-20000,20000,100001),0.,281.66788314129474]
 ww=phi(zz);a=BETA_S*zz-ww;bb=ww;zt=a+bb;wt=a-bb
 assert phi(0)==0 and np.min(a*bb)>-1e-8
 err=float(np.max(np.abs((zt*zt-wt*wt)-4*a*bb)));assert err<1e-6
 assert np.all(np.abs(wt)<=np.abs(zt)+1e-9)
 with zipfile.ZipFile(OUT/'final.pptx','w',zipfile.ZIP_DEFLATED) as z:
  for n,data in files.items():z.writestr(n,data)
 (OUT/'source.json').write_text(json.dumps(dict(source=str(SOURCE),hash=hashlib.sha256((OUT/'source.pptx').read_bytes()).hexdigest().upper())))
 (OUT/'validation.json').write_text(json.dumps(dict(alpha=0,beta=BETA_S,zStar=STAR,M=M,sector_minimum=float(np.min(a*bb)),supply_identity_error=err,slides=4),indent=2))
 (OUT/'README.md').write_text('# Shifted-sigmoid sector and dissipativity\n\n'+'\n\n'.join(f'{i}. {t}' for i,t in enumerate(NOTES,1)),encoding='utf8')
 print('Built four editable slides using the actual shifted STN sigmoid and a direct dissipativity narrative.')
if __name__=='__main__':main()
