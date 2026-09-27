from pathlib import Path
import ast
# Reuse the editable equation/shape helpers, without executing the prior edits.
PREV=Path(__file__).resolve().parent.parent/'sector_dissipativity_story/build.py'
tree=ast.parse(PREV.read_text(encoding='utf8'))
nodes=[]
for node in tree.body:
 if isinstance(node,(ast.FunctionDef,ast.ClassDef,ast.Import,ast.ImportFrom)):nodes.append(node)
 elif getattr(node,'lineno',1000)<40:nodes.append(node)
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(PREV),'exec'))
SOURCE=Path(b.SOURCE)
old=ZipFile(B.parent/'sector_dissipativity_story/source.pptx')
od=D.parseString(old.read('ppt/slides/slide37.xml'))
original_group=next(n for n in els(od,'p:grpSp') if name(n)=='Editable paper diagram').cloneNode(True)
# Keep the supplied schematic geometry. Discard only the two orphan labels below it.
for n in list(original_group.childNodes):
 if n.nodeType==1 and els(n,'p:cNvPr') and name(n) in ['Controller label','Controller external channel']:original_group.removeChild(n)
for ac in list(els(original_group,'mc:AlternateContent')):
 choice=first(ac,'mc:Choice');child=next(c for c in choice.childNodes if c.nodeType==1);ac.parentNode.replaceChild(child.cloneNode(True),ac)
xf=first(original_group,'a:xfrm');co=first(xf,'a:chOff');ce=first(xf,'a:chExt')
crop=[2005330/12700,1274064/12700,(6840601-2005330)/12700,(3454400-1274064)/12700]
for k,vv in zip(['x','y'],crop[:2]):co.setAttribute(k,b.emu(vv))
for k,vv in zip(['cx','cy'],crop[2:]):ce.setAttribute(k,b.emu(vv))
# The pasted group had an empty filter-label shape; supply its native editable Theta.
lab=v.Slide();lab.i=8000;lab.equation('Original filter label',(4871720+469900)/12700,(1274064+469900)/12700,lambda m:m.r('Θ'),25,w=70)
original_group.appendChild(original_group.ownerDocument.importNode(frag(lab.parts[0]),True))
def add_original(s,box,split=False):
 g=original_group.cloneNode(True);remap(g,5000,'Original paper schematic');geom(g,box)
 if split:
  dn=[n for n in list(g.childNodes) if n.nodeType==1 and els(n,'p:cNvPr') and name(n) in ['Uncertainty','Uncertainty label']]
  for n in dn:g.removeChild(n)
  bb=rect(dn[0]);focus=group('!!Delta focus',dn,bb,7000)
  geom(focus,[box[0]+(bb[0]-crop[0])*box[2]/crop[2],box[1]+(bb[1]-crop[1])*box[3]/crop[3],bb[2]*box[2]/crop[2],bb[3]*box[3]/crop[3]])
  remap(focus,7000,'!!Delta focus');s.extra.append(focus.toxml())
 s.extra.append(g.toxml())

s=Slide(34,'Describe the nonlinearity Δ')
temp=v.Slide();temp.i=1200;plot(temp,True,True)
curveparts=[]
for xml in temp.parts:
 n=frag(xml);nm=name(n)
 if nm in ['Sector region','Upper sector line','Lower sector line']:first(n,'p:cNvPr').setAttribute('name','Sector bounds '+nm)
 if nm in ['Input axis','Output axis','Shifted sigmoid curve']:curveparts.append(n.toxml())
 else:s.parts.append(n.toxml())
s.extra.append(group('!!Sector plot',curveparts,[38,80,300,220],1300).toxml())
s.i=1400;graphlabels(s)
s.parts=[x for x in s.parts if name(frag(x))!='Graph description']
add_original(s,[389,97,290,131],True)
s.eq('Initial map',533,266,lambda m:m.r('w=Δ')+m.d(m.r('z')),22,w=310)
s.eq('Introduce Theta',533,268,lambda m:vec(m,[tilde(m,'z'),tilde(m,'w')])+m.r('=Θ')+vec(m,[m.r('z'),m.r('w')]),19,w=310)
s.eq('Sector condition',188,299,lambda m:m.r('α=0,  β≈0.7344'),16,w=300)
def sigmoid(m):return m.r('S')+m.d(m.r('q'))+m.r('=')+m.frac(m.r('M'),m.r('2'))+m.d(m.r('1+')+m.r('tanh',plain=True)+m.d(m.frac(m.r('2q'),m.r('M'))),'[',']')
s.eq('Activation function',211,338,sigmoid,18,w=350)
s.eq('Shifted function',536,338,lambda m:m.r('Δ')+m.d(m.r('z'))+m.r('=S')+m.d(m.sup(m.r('z'),m.r('*'))+m.r('+z'))+m.r('−S')+m.d(m.sup(m.r('z'),m.r('*'))),18,w=345)
s.eq('Equilibrium parameters',360,370,lambda m:m.r('M=300,  ')+m.sup(m.r('z'),m.r('*'))+m.r('≈−196.17,  Δ')+m.d(m.r('0'))+m.r('=0'),12,w=650)
s.finish(morph=True)

# Large plot, simple definitions and synchronized editable numerical readouts.
s=Slide(35,'The gaps between the curve and its sector')
temp=v.Slide();temp.i=2000;plot(temp,False,False)
gg=group('!!Sector plot',temp.parts,[38,80,300,220],2100);geom(gg,[50,78,620,225]);s.extra.append(gg.toxml())
s.i=2200
s.eq('Graph input',682,190,lambda m:m.r('z'),15,w=25)
s.eq('Graph output',360,72,lambda m:m.r('w'),15,w=25)
s.eq('Upper boundary label',638,102,lambda m:m.r('βz'),14,w=60)
s.eq('Lower boundary label',630,220,lambda m:m.r('αz=0'),13,w=85)
for z in [-400,400]:s.text('Input tick '+str(z),360+.558*z,210,str(z),9,GRAY,w=45)
s.text('Origin',348,203,'0',9,GRAY,w=20)
s.eq('Upper gap definition',204,330,lambda m:m.r('a=βz−w',BLUE),24,w=310)
s.eq('Lower gap definition',522,330,lambda m:m.r('b=w−αz',GREEN),24,w=310)
FPS=12;DURATION=12;N=FPS*DURATION
values=[]
for k in range(N):
 t=k/(N-1)*DURATION;z=float(250*np.sin(2*np.pi*t/DURATION));w=float(delta(z));a=BETA*z-w;bb=w
 def fmt(x):return f'{0.0 if abs(x)<.005 else x:+.2f}'
 def draw(d,z=z,a=a,bb=bb):
  d.equation('z numerical value',118,89,lambda m:m.r('z='+fmt(z)),17,w=158)
  d.equation('a numerical value',204,365,lambda m:m.r(fmt(a),BLUE),26,w=250)
  d.equation('b numerical value',522,365,lambda m:m.r(fmt(bb),GREEN),26,w=250)
 s.packed(f'Readout {k:03d}',draw,[35,64,630,319]);values.append(dict(t=t,z=z,w=w,a=a,b=bb))
s.finish(morph=True)
(B/'readouts.json').write_text(json.dumps(dict(fps=FPS,duration=DURATION,values=values)))

s=Slide(36,'Choose Θ so the nonlinearity is dissipative')
s.eq('Parameterize Theta',360,116,lambda m:m.r('Θ')+m.d(m.r('v'))+m.r('=')+mat(m,[['v','1'],['v','−1']])+mat(m,[['β','−1'],['−α','1']])+m.r(',  v>0'),25,w=670)
s.eq('Transformed gaps',360,186,lambda m:tilde(m,'z')+m.r('=va+b,     ')+tilde(m,'w')+m.r('=va−b'),24,w=650)
s.eq('Supply identity',360,252,lambda m:m.r('σ=')+sigma(m)+m.r('=')+m.sup(m.d(m.r('va+b')),m.r('2'))+m.r('−')+m.sup(m.d(m.r('va−b')),m.r('2'))+m.r('=4vab≥0',GREEN),21,w=680)
s.eq('Delta dissipativity',360,316,lambda m:integral(m,m.r('σ')+m.d(m.r('t'))+m.r('dt'))+m.r('≥0,  ∀T≥0'),23,w=650)
s.text('Dissipativity meaning',360,365,'The transformed output energy cannot exceed the input energy.',15,GREEN,w=670)
s.finish()

# Replace the stability slide in place, then remove the redundant old slide 37.
stabilitypart=parts[39];physical=int(re.search(r'slide(\d+)',stabilitypart)[1])
s=Slide(39,'Why the PIE–Δ interconnection is stable')
add_original(s,[35,139,292,132])
s.text('Delta role',514,93,'The sector gives',16,w=365)
s.eq('Delta supply',514,139,lambda m:m.r('σ=')+sigma(m)+m.r('≥0',GREEN),21,w=380)
s.text('PIE role',514,195,'Require the PIE to dissipate that supply:',15,w=380)
s.eq('PIE decay',514,240,lambda m:dot(m,'V')+m.r('≤')+norm2(m,tilde(m,'w'))+m.r('−')+norm2(m,tilde(m,'z'))+m.r('−ε')+norm2(m,m.r('x')),20,w=380)
s.eq('Closed loop decay',514,291,lambda m:m.r('⇒  ')+dot(m,'V')+m.r('≤−ε')+norm2(m,m.r('x'))+m.r('<0',GREEN),25,w=380)
s.text('Energy intuition',360,337,'With no external input, the stored energy V can only decrease.',17,GREEN,w=670)
s.eq('Storage qualification',360,372,lambda m:m.r('0<m')+norm2(m,m.r('x'))+m.r('≤V≤M')+norm2(m,m.r('x'))+m.r(',  x≠0,  ε>0'),13,w=650)
s.finish(physical)
pres=D.parseString(files['ppt/presentation.xml']);lst=first(pres,'p:sldIdLst');ids=els(pres,'p:sldId');removed=ids[36];rid=removed.getAttribute('r:id');lst.removeChild(removed)
files['ppt/presentation.xml']=pres.toxml(encoding='utf-8')
pr=D.parseString(files['ppt/_rels/presentation.xml.rels'])
for r in list(els(pr,'Relationship')):
 if r.getAttribute('Id')==rid:pr.documentElement.removeChild(r)
files['ppt/_rels/presentation.xml.rels']=pr.toxml(encoding='utf-8');parts.pop(36)
for i,p in enumerate(parts,1):
 if i<37:continue
 d=D.parseString(files[p]);changed=False
 for n in shapes(d):
  if name(n).lower()=='slide number' or 'slide number placeholder' in name(n).lower():
   for t in els(n,'a:t'):
    if t.firstChild:t.firstChild.data=str(i);changed=True
 if changed:files[p]=d.toxml(encoding='utf-8')
for ordinal,txt in {34:'The actual activation is S(q)=M/2[1+tanh(2q/M)], and Delta(z)=S(zStar+z)-S(zStar). The original pasted PIE/Delta/filter schematic is reused without redrawing its connections. Its two orphan K and u labels are omitted. First plot Delta and the defining functions, next introduce the dashed Delta and Theta with the original schematic, finally reveal the sector. Theta is parameterized on slide 36.',35:'The large plot sweeps z=250 sin(2*pi*t/12). Readouts use the exact plotted sample, with native editable values refreshed at 12 fps. Positive and negative signs are visible in the numerical values; no comparison statements are used. a=beta*z-w and b=w-alpha*z, alpha=0. Gap arrows are signed.',36:'Theta(v)=[[v,1],[v,-1]][[beta,-1],[-alpha,1]], v>0. Thus ztilde=v*a+b, wtilde=v*a-b and sigma=4vab>=0. The memoryless nonlinearity has zero storage. This is a direct dissipativity construction, with no Pi notation.',39:'Sign convention matters: sigma=||ztilde||^2-||wtilde||^2>=0 on the Delta graph. Vdot<=+sigma does NOT imply stability (even Vdot=1, sigma=1 is allowed). The complementary PIE supply is -sigma=||wtilde||^2-||ztilde||^2. Seek a common coercive storage for the unforced well-posed interconnection with Vdot<=-sigma-epsilon||x||^2. The nonlinearity cannot provide a positive net supply to replenish this storage, so Vdot<=-epsilon||x||^2 and V(t)<=exp(-epsilon*t/M)V(0). Positive m and M and compatible state norm/solution regularity are required. Without the strict margin, V nonincrease gives Lyapunov stability under the coercive bounds, but asymptotic decay is not automatic. The strict inequality shown excludes the equilibrium. This pointwise argument applies to the present static sector filter; general dynamic integral dissipativity needs the corresponding augmented storage argument.'}.items():
 b.add_notes(files,int(re.search(r'slide(\d+)',parts[ordinal-1])[1]),txt)
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,vv in files.items():z.writestr(n,vv)
(B/'output_parts.json').write_text(json.dumps(parts))
(B/'source.json').write_text(json.dumps(dict(source=str(SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper(),slides=len(parts))))
print('Restored original schematic, added functions and editable numerical readouts, removed slide 37, clarified stability sign.')
