from pathlib import Path
from xml.dom import minidom as D
from xml.sax.saxutils import escape
from zipfile import ZipFile,ZIP_DEFLATED
import sys,json,hashlib,posixpath,copy,re
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,els,first
from build_video_overlays import namespaces
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
rels={r.getAttribute('Id'):posixpath.normpath('ppt/'+r.getAttribute('Target')) for r in els(D.parseString(files['ppt/_rels/presentation.xml.rels']),'Relationship')}
parts=[rels[r.getAttribute('r:id')] for r in els(D.parseString(files['ppt/presentation.xml']),'p:sldId')];part=parts[18]
doc=D.parseString(files[part]);namespaces(doc);tree=first(doc,'p:spTree')
def sid(s):return first(s,'p:cNvPr').getAttribute('id')
def frag(s):return D.parseString(f'<root {b.DECL}>'+s+'</root>').documentElement.firstChild
def rect(s):
 xf=first(s,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 return [int(o.getAttribute(k))/12700 for k in ['x','y']]+[int(e.getAttribute(k))/12700 for k in ['cx','cy']]
def geom(s,box):
 xf=first(s,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 for k,v in zip(['x','y'],box[:2]):o.setAttribute(k,b.emu(v))
 for k,v in zip(['cx','cy'],box[2:]):e.setAttribute(k,b.emu(v))
for s in list(tree.childNodes):
 if s.nodeType==1 and els(s,'p:cNvPr') and sid(s) in ['46','68']:tree.removeChild(s)
for timing in list(els(doc,'p:timing')):timing.parentNode.removeChild(timing)
diagram=next(g for g in els(doc,'p:grpSp') if sid(g)=='54');first(diagram,'p:cNvPr').setAttribute('name','Original neural schematic')
gbox=rect(diagram);finalbox=[181-gbox[2]*.64/2,172-gbox[3]*.64/2,gbox[2]*.64,gbox[3]*.64]
ident=11000;records={};events=[]
def register(node,name,start=0,end=5):
 global ident
 ident+=1;nv=first(node,'p:cNvPr');nv.setAttribute('id',str(ident));nv.setAttribute('name',name)
 tree.appendChild(doc.importNode(node,True));records[name]=dict(id=ident,start=start,end=end,box=rect(node));return ident
records['Original neural schematic']=dict(id=54,start=0,end=4,box=gbox,after1=finalbox)
def run(self,s,c=None,plain=False):return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in s)
b.Math.r=run
def sub(m,s,i):return m.sub(m.r(s),m.r(i,plain=True))
def sig(m,s,i):return sub(m,s,i)+m.d(m.r('t'))
def history(m,i):return sub(m,'φ',i)+m.d(m.r('t')+m.r(',1',plain=True))
def dot(m,e):return '<m:acc><m:accPr><m:chr m:val="̇"/>'+m.ctrl()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
def eqxml(name,x,y,fn,size=18,width=500,color='252529'):
 global ident
 ident+=1;m=b.Math(size,color);s=b.lib.tb(ident,name,(x-width/2,y-size*1.15,width,size*2.3),'',size,color)
 eq='<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+fn(m)+'</m:oMath></m:oMathPara></a14:m>'
 return re.sub(r'<a:r>.*?</a:r>',lambda _:eq,s)
def eq(name,x,y,fn,size=18,width=500,color='252529',start=0,end=5):return register(frag(eqxml(name,x,y,fn,size,width,color)),name,start,end)
def group(name,contents,box,start=0,end=5):
 global ident
 ident+=1;x,y,w,h=box
 node=frag(f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{ident}" name="{name}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{b.emu(x)}" y="{b.emu(y)}"/><a:ext cx="{b.emu(w)}" cy="{b.emu(h)}"/><a:chOff x="{b.emu(x)}" y="{b.emu(y)}"/><a:chExt cx="{b.emu(w)}" cy="{b.emu(h)}"/></a:xfrm></p:grpSpPr>'+''.join(contents)+'</p:grpSp>')
 return register(node,name,start,end)
def diagramgroup(name,fn,box,start,end=5):
 global ident
 d=b.Slide();d.i=ident+1;fn(d);ident=d.i+1;return group(name,d.parts,box,start,end)
def text(name,x,y,t,size=14,width=640,color='747B82',start=0,end=5):
 return register(frag(b.lib.tb(1,name,(x-width/2,y-size*.85,width,size*1.7),t,size,color,'Aptos')),name,start,end)
def zline(m,i):
 if i=='S':return sig(m,'z','S')+m.r('=−')+sub(m,'w','GS')+history(m,'GS')
 return sig(m,'z','G')+m.r('=')+sub(m,'w','SG')+history(m,'SG')+m.r('−')+sub(m,'w','GG')+history(m,'GG')
def lhs(m,i):return sub(m,'τ',i)+dot(m,sub(m,'x',i))+m.d(m.r('t'))+m.r('=')
def nonlinear(m,i):return sub(m,'δ',i)+m.d(sig(m,'z',i))
base=[eqxml('Delay dynamics S',360,238,lambda m:zline(m,'S'),18,510),eqxml('Delay dynamics G',360,260,lambda m:zline(m,'G'),18,570)]
for i,yy in [('S',285),('G',312)]:
 base.append(eqxml('State dynamics left '+i,257,yy,lambda m,i=i:lhs(m,i),18,108))
 base.append(eqxml('State dynamics right '+i,457 if i=='S' else 432,yy,lambda m,i=i:m.r('−')+sig(m,'x',i)+(m.r('+u')+m.d(m.r('t')) if i=='S' else ''),18,122 if i=='S' else 70))
group('Original model equations',base,(66,216,588,120),0,1)
for i,yy in [('S',285),('G',312)]:eq('Moving nonlinearity '+i,354,yy,lambda m,i=i:nonlinear(m,i),18,98,'D61016',0,1)
nominal=[eqxml('Nominal delay relation '+i,181,yy,lambda m,i=i:zline(m,i),12,310) for i,yy in [('S',255),('G',273)]]
for i,yy in [('S',295),('G',314)]:
 nominal.append(eqxml('Nominal state equation '+i,181,yy,lambda m,i=i:lhs(m,i)+sig(m,'w',i)+m.r('−')+sig(m,'x',i)+(m.r('+u')+m.d(m.r('t')) if i=='S' else ''),12,310))
group('Moving nominal dynamics',nominal,(26,240,310,88),1,2)
def delta(d):d.block('Nonlinearity block',538,124,92,62,'Δ',27,red=True)
diagramgroup('Delta block',delta,(492,93,92,62),1)
def plant(d):d.block('Nominal plant block',538,236,92,74,'P',29)
diagramgroup('P block',plant,(492,199,92,74),2)
def loop(d):
 d.path('z Delta channel',[(492,215),(445,215),(445,124),(492,124)],width=1)
 d.path('w Delta channel',[(584,124),(631,124),(631,215),(584,215)],width=1)
 d.equation('Nonlinearity input',425,174,lambda m:sub(m,'z','Δ'),16,w=50)
 d.equation('Nonlinearity output',651,174,lambda m:sub(m,'w','Δ'),16,w=50)
 d.path('Open control input',[(445,255),(492,255)],width=1)
 d.path('Open measured output',[(584,255),(631,255)],width=1)
 d.equation('Control input',423,265,lambda m:m.r('u')+m.d(m.r('t')),14,w=55)
 d.equation('Measured output',655,265,lambda m:m.r('y')+m.d(m.r('t')),14,w=55)
diagramgroup('LFR signal connections',loop,(396,112,288,164),2)
def controller(d):d.block('Controller',538,323,56,42,'K',24)
diagramgroup('Controller K',controller,(510,302,56,42),3)
def feedback(d):
 d.path('Measured output to K',[(631,255),(631,323),(566,323)],width=1)
 d.path('Controller output to plant',[(510,323),(445,323),(445,255)],width=1)
diagramgroup('Controller connections',feedback,(444,254,188,71),3)
# At the last click, keep the diagram at exactly its settled position, connect
# a corresponding controller, and expose the equivalence between both views.
finaldiagram=diagram.cloneNode(True);geom(finaldiagram,finalbox)
for s in list(els(finaldiagram,'p:sp')):
 if first(s,'p:cNvPr').getAttribute('name')=='Stimulation input':s.parentNode.removeChild(s)
for nv in els(finaldiagram,'p:cNvPr'):ident+=1;nv.setAttribute('id',str(ident))
register(finaldiagram,'Equivalent original schematic',4)
def physicalfeedback(d):
 d.block('Schematic controller',315,91,40,32,'K',19)
 d.path('Controller to probe',[(295,91),(287,91),(287,118),(293,118)],width=.8)
 d.path('GPe measurement',[(92,187),(92,237),(184,237)],arrow=False,color='747B82',width=.8)
 d.path('STN measurement',[(266,187),(266,237),(184,237)],arrow=False,color='747B82',width=.8)
 d.path('Measurements to controller',[(184,237),(184,249),(340,249),(340,91),(335,91)],width=.8,color='747B82')
 d.equation('Measured neural state',269,262,lambda m:m.r('y')+m.d(m.r('t')),12,w=60)
diagramgroup('Schematic controller connection',physicalfeedback,(91,74,250,198),4)
eq('Equivalence symbol',367,207,lambda m:m.r('⇔',plain=True),29,55,start=4)
text('Equivalent schematic heading',179,76,'Original schematic',12,200,start=4)
text('LFR heading',538,76,'Linear fractional representation',12,260,start=4)
for i,t in enumerate(['Collect the nonlinearities in Δ.','Collect the linear dynamics and delays in P.','Close the open y(t)–u(t) connection with K.','Same dynamics and signals; a different representation.'],1):text('Stage '+str(i)+' caption',360,355,t,15,660,'D61016' if i==4 else '252529',i,i+1)
files[part]=doc.toxml(encoding='utf-8')
# Append construction semantics and measurement convention to the existing notes.
physical=int(re.search(r'slide(\d+)',part)[1])
b.add_notes(files,physical,'Four-click LFR construction. 1: move delta_S(z_S) and delta_G(z_G) into Delta; rename their outputs w_S,w_G. 2: gather all remaining linear state dynamics, coupling weights and delay/transport profiles phi_ij into P. Define z_Delta=col(z_S,z_G), w_Delta=col(w_S,w_G), and y(t)=col(x_S(t),x_G(t)); the displayed phi_ij(t,1) notation is retained from the current slide. P includes the unchanged delay transport equations and their boundary/history data even though they are not expanded on screen. 3: connect a causal controller K from y to u; K may be dynamic and use measurement history, as in the paper. This is a structural interconnection diagram, not a claim of a new stabilization certificate or a static-gain implementation. 4: the controlled schematic and the closed LFR have exactly the same equations for the same initial histories and same controller. No dynamics are discarded in collecting blocks.')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,data in files.items():z.writestr(n,data)
(B/'animation.json').write_text(json.dumps(dict(slide=19,part=part,slideCount=len(parts),records=records),indent=2))
(B/'source.json').write_text(json.dumps(dict(source=str(b.SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper())))
# Deterministic stills at each click boundary, used to inspect the complete layout.
for stage in range(5):
 preview=files.copy();d=D.parseString(files[part]);tr=first(d,'p:spTree')
 for node in list(tr.childNodes):
  if node.nodeType!=1 or not els(node,'p:cNvPr'):continue
  name=first(node,'p:cNvPr').getAttribute('name');rec=records.get(name)
  if rec:
   if not(rec['start']<=stage<rec['end']):tr.removeChild(node);continue
   if stage>=1 and 'after1' in rec:geom(node,rec['after1'])
 preview[part]=d.toxml(encoding='utf-8')
 with ZipFile(B/f'preview-{stage}.pptx','w',ZIP_DEFLATED) as z:
  for n,data in preview.items():z.writestr(n,data)
print('Built five construction states on slide 19; retained '+str(len(parts))+' slides.')
