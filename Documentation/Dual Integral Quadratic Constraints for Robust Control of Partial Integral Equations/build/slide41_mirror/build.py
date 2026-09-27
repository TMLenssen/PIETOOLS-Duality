from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import importlib.util

B=Path(__file__).resolve().parent; ROOT=B.parents[1]
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec); spec.loader.exec_module(v); b=v.b
def run(self,t,c=None,plain=False):
 return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in t)
v.M.r=run
def under(m,e): return '<m:bar><m:barPr><m:pos m:val="bot"/>'+m.ctrl()+'</m:barPr><m:e>'+e+'</m:e></m:bar>'
def tilde(m,e): return '<m:acc><m:accPr><m:chr m:val="̃"/>'+m.ctrl()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
def sig(m,x,dual=False,filtered=False,t=True):
 e=m.r(x)
 if filtered:e=tilde(m,e)
 if dual:e=under(m,e)
 return e+(m.d(m.r('t')) if t else '')
def k(m,dual): return m.sup(m.r('K'),m.r('⊤',plain=True)) if dual else m.r('K')
def theta(m,dual): return under(m,m.r('Θ')) if dual else m.r('Θ')
def vec(m,rr): return m.d(m.matrix([[r] for r in rr]),'[',']')
def mat(m,dual): return m.d(m.matrix([[m.r('I'),m.r('0',plain=True)],[m.r('−')+k(m,dual),m.r('I')]]),'[',']')
def norm2(m,e): return m.sup(m.d(e,'‖','‖'),m.r('2',plain=True))
def first(n,tag): return n.getElementsByTagName(tag)[0]
def frag(xml): return D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
d=D.parseString(files['ppt/slides/slide41.xml']); tree=first(d,'p:spTree')
original=[n for n in tree.childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr')]
left={50,63,192,193,194,195,196,197,198,8,10,11,12}
right={22,27,28,29,30,31,32,33,34,35,36,37,38}
diagrams=[]
for dual,keep in [(False,left),(True,right)]:
 children=[n.cloneNode(True) for n in original if int(first(n,'p:cNvPr').getAttribute('id')) in keep]
 sourcex=36 if not dual else 360
 targetx=48 if not dual else 388
 # Preserve all user diagram lines and labels in two identically scaled groups.
 group=frag(f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{9000+int(dual)}" name="'+('Dual' if dual else 'Primal')+' controller diagram"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="'+b.emu(targetx)+'" y="'+b.emu(77)+'"/><a:ext cx="'+b.emu(272)+'" cy="'+b.emu(110.5)+'"/><a:chOff x="'+b.emu(sourcex)+'" y="'+b.emu(70)+'"/><a:chExt cx="'+b.emu(320)+'" cy="'+b.emu(130)+'"/></a:xfrm></p:grpSpPr>'+''.join(n.toxml() for n in children)+'</p:grpSp>')
 diagrams.append(group)
for n in list(tree.childNodes):
 if n.nodeType!=1 or n.tagName in ['p:nvGrpSpPr','p:grpSpPr']:continue
 nv=n.getElementsByTagName('p:cNvPr')
 if nv and int(nv[0].getAttribute('id')) in [3,4]:continue
 tree.removeChild(n)
for n in diagrams:tree.appendChild(d.importNode(n,True))
s=v.Slide(); s.i=9100
s.label('Title',360,37,'Thought experiment: constrain K and Kᵀ',25,w=648,bold=True)
s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
for dual,cx in [(False,190),(True,530)]:
 prefix='Dual ' if dual else 'Primal '
 s.label(prefix+'heading',cx,65,'Dual controller' if dual else 'Controller',14,'C81919',w=310,bold=True)
 s.equation(prefix+'controller relation',cx,202,lambda m,q=dual:sig(m,'u',q)+m.r('=')+k(m,q)+sig(m,'y',q),18,w=310)
 s.equation(prefix+'filter matrix',cx,245,lambda m,q=dual:vec(m,[sig(m,'y',q,True,False),sig(m,'u',q,True,False)])+m.r('=')+theta(m,q)+vec(m,[sig(m,'y',q,False,False),sig(m,'u',q,False,False)])+m.r('=')+mat(m,q)+vec(m,[sig(m,'y',q,False,False),sig(m,'u',q,False,False)]),17,w=318)
 s.equation(prefix+'transformed signals',cx,287,lambda m,q=dual:sig(m,'y',q,True,False)+m.r('=')+sig(m,'y',q,False,False)+m.r(',   ')+sig(m,'u',q,True,False)+m.r('=')+sig(m,'u',q,False,False)+m.r('−')+k(m,q)+sig(m,'y',q,False,False)+m.r('=0'),17,w=318)
 s.equation(prefix+'expanded inequality',cx,322,lambda m,q=dual:norm2(m,sig(m,'u',q)+m.r('−')+k(m,q)+sig(m,'y',q))+m.r('≤')+norm2(m,sig(m,'y',q)),17,w=318)
 s.equation(prefix+'final inequality',cx,358,lambda m,q=dual:norm2(m,sig(m,'u',q,True))+m.r('=0≤')+norm2(m,sig(m,'y',q,True)),19,w=318,color='C81919')
for prefix,uri in b.NS.items():d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:tree.appendChild(d.importNode(frag(xml),True))
for n in list(d.documentElement.childNodes):
 if n.nodeType==1 and n.tagName=='p:timing':d.documentElement.removeChild(n)
files['ppt/slides/slide41.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
print('Mirrored controller/filter/inequality derivations; retained both diagrams and dual underlines.')
