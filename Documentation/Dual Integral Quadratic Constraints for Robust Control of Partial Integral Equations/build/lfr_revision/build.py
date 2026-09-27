from pathlib import Path
from xml.dom import minidom as D
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZIP_DEFLATED
import sys,json,hashlib,posixpath,re
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,els,first
from build_video_overlays import namespaces
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
part='ppt/slides/slide19.xml';doc=D.parseString(files[part]);namespaces(doc);tree=first(doc,'p:spTree')
def sid(n):return first(n,'p:cNvPr').getAttribute('id')
def name(n):return first(n,'p:cNvPr').getAttribute('name')
def frag(s):return D.parseString(f'<root {b.DECL}>'+s+'</root>').documentElement.firstChild
def rect(s):
 xf=first(s,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 return [int(o.getAttribute(k))/12700 for k in ['x','y']]+[int(e.getAttribute(k))/12700 for k in ['cx','cy']]
def geom(s,box):
 xf=first(s,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 for k,v in zip(['x','y'],box[:2]):o.setAttribute(k,b.emu(v))
 for k,v in zip(['cx','cy'],box[2:]):e.setAttribute(k,b.emu(v))
nodes={name(n):n.cloneNode(True) for n in tree.childNodes if n.nodeType==1 and els(n,'p:cNvPr')}
for n in list(tree.childNodes):
 if n.nodeType==1 and n.tagName!='p:nvGrpSpPr' and els(n,'p:cNvPr') and name(n) not in ['Footer Placeholder 4','Slide Number Placeholder 5','Original TUe logo','Title 1']:tree.removeChild(n)
for n in list(els(doc,'p:timing')):n.parentNode.removeChild(n)
ident=20000;records={}
def register(node,nm,start=0,end=6):
 global ident
 # Remap every native object, including the matching legacy fallback IDs.
 remap={}
 for nv in els(node,'p:cNvPr'):
  old=nv.getAttribute('id')
  if old not in remap:ident+=1;remap[old]=str(ident)
  nv.setAttribute('id',remap[old])
 nv=first(node,'p:cNvPr');nv.setAttribute('name',nm)
 tree.appendChild(doc.importNode(node,True));records[nm]=dict(id=int(nv.getAttribute('id')),start=start,end=end,box=rect(node))
 return int(nv.getAttribute('id'))
exec((B/'helpers.py').read_text(encoding='utf-8'))
records['Title 1']=dict(id=3,start=0,end=5,box=rect(nodes['Title 1']))
neural=nodes['Original neural schematic'];register(neural,'Original neural schematic',0,5)
gb=rect(neural);nb=[379,94,gb[2]*.67,gb[3]*.67];records['Original neural schematic']['after1']=nb
for nm in ['Original model equations','Moving nonlinearity S','Moving nonlinearity G']:
 register(nodes[nm],nm,0,1)
nominal=nodes['Moving nominal dynamics'];geom(nominal,[371,243,310,88]);register(nominal,'Moving nominal dynamics',1,2)

# Retain the exact editable LFR supplied by the user, including G and all ports.
lfr=nodes['Editable paper diagram'];xf=first(lfr,'a:xfrm')
co=first(xf,'a:chOff');ce=first(xf,'a:chExt')
childbox=[int(co.getAttribute(k))/12700 for k in ['x','y']]+[int(ce.getAttribute(k))/12700 for k in ['cx','cy']]
box=[39,95,280,280*childbox[3]/childbox[2]]
def lfrgroup(nm,ids,start,end=5):
 g=lfr.cloneNode(True)
 for n in list(g.childNodes):
  if n.nodeType==1 and els(n,'p:cNvPr') and n.tagName not in ['p:nvGrpSpPr','p:grpSpPr'] and sid(n) not in [str(i) for i in ids]:g.removeChild(n)
 geom(g,box);return register(g,nm,start,end)
lfrgroup('Delta block',[25,26],1)
lfrgroup('G block',[27,28],2)
lfrgroup('Uncertainty connections',[7,8,23,24],2)
lfrgroup('Control signal labels',[20,21],2)
lfrgroup('Controller K',[18,19],3)
lfrgroup('Controller connections',[15,16],3)
def mappt(x,y):return (box[0]+(x-childbox[0])*box[2]/childbox[2],box[1]+(y-childbox[1])*box[3]/childbox[3])
delta=mappt(280,165.44);plant=mappt(280,235)
def openports(d):
 d.path('Open u port',[mappt(197.12,253.5),mappt(243,253.5)],width=1)
 d.path('Open y port',[mappt(317,253.5),mappt(362.88,253.5)],width=1)
diagramgroup('Open control ports',openports,box,2,3)
# A complete copy enables one coherent final move of every block and signal.
geom(lfr,box);register(lfr,'Complete LFR',5,6)
finalbox=[360-box[2]*1.12/2,223-box[3]*1.12/2,box[2]*1.12,box[3]*1.12]
records['Complete LFR']['after5']=finalbox
text('Final LFR title',360,46,'Linear fractional representation',25,648,'252529',5,6)
# Align the final title with the rest of the presentation's title placeholders.
last=tree.lastChild
for pp in els(last,'a:pPr'):pp.setAttribute('algn','l')
for rr in els(last,'a:rPr'):rr.setAttribute('b','1')

# Reuse the user's industrial photos, without adding wires to the neural model.
relpart='ppt/slides/_rels/slide19.xml.rels';rd=D.parseString(files[relpart])
closingpart='ppt/slides/slide43.xml';cd=D.parseString(files[closingpart]);cr=D.parseString(files['ppt/slides/_rels/slide43.xml.rels'])
crm={r.getAttribute('Id'):r for r in els(cr,'Relationship')}
def picture(nm,newname,bb):
 node=next(n for n in first(cd,'p:spTree').childNodes if n.nodeType==1 and els(n,'p:cNvPr') and name(n)==nm).cloneNode(True)
 geom(node,bb);mapping={}
 for el in node.getElementsByTagName('*'):
  for att in ['r:embed','r:link','r:id']:
   rid=el.getAttribute(att)
   if rid in crm:
    if rid not in mapping:
     rr=crm[rid].cloneNode(True);newrid='rIdIndustry'+str(len(els(rd,'Relationship'))+100);rr.setAttribute('Id',newrid)
     rd.documentElement.appendChild(rd.importNode(rr,True));mapping[rid]=newrid
    el.setAttributeNS(b.NS['r'],att,mapping[rid])
 register(node,newname,4,5)
picture('ASML wafer stage','ASML image',[376,257,140,72.8])
picture('Canon production printer','Canon image',[543,260,140,68.6])
text('ASML caption',446,345,'ASML',14,140,'252529',4,5)
text('Canon caption',613,345,'Canon',14,140,'252529',4,5)
text('Additional models heading',528,238,'Other distributed models',14,304,'747B82',4,5)
def shared(d):
 d.path('Models to LFR',[(359,290),(332,290),(332,211),(315,211)],width=1)
diagramgroup('Industrial model arrow',shared,(314,210,46,81),4,5)
def equivalence(d):d.equation('Same neural dynamics',348,164,lambda m:m.r('⇔',plain=True),22,w=45)
diagramgroup('Neural equivalence',equivalence,(325,145,46,40),3,5)
for i,t in enumerate(['Collect the nonlinearities in Δ.','Collect the linear dynamics and delays in G.','Connect the controller K.'],1):text('Stage '+str(i)+' caption',360,358,t,15,660,'252529',i,i+1)
files[relpart]=rd.toxml(encoding='utf-8');files[part]=doc.toxml(encoding='utf-8')
b.add_notes(files,19,'Five-click construction using the user-supplied editable LFR. 1: the two nonlinearities become Delta, with the neural schematic moving to the right. 2: the linear dynamics and delay/transport profiles become G, retaining the supplied z, w, u and y ports. 3: connect K from y to u. The neural schematic is unchanged: the equivalence is a change of representation, not extra physical neural connections. 4: ASML wafer-stage and Canon production-printer images illustrate additional distributed models that can be expressed in suitable PIE/LFR form, subject to the framework assumptions. 5: clear the examples, center the complete LFR, and reveal its name. No claim of demonstrated industrial controller performance is implied.')
def write(path,ff):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,v in ff.items():z.writestr(n,v)
write(B/'staged.pptx',files)
(B/'animation.json').write_text(json.dumps(dict(records=records,delta=delta,plant=plant,finalbox=finalbox),indent=2))
(B/'source.json').write_text(json.dumps(dict(source=r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx',hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper())))
for stage in range(6):
 ff=files.copy();dd=D.parseString(files[part]);tr=first(dd,'p:spTree')
 for node in list(tr.childNodes):
  if node.nodeType!=1 or not els(node,'p:cNvPr'):continue
  rec=records.get(name(node))
  if rec:
   if not rec['start']<=stage<rec['end']:tr.removeChild(node);continue
   for st in [1,5]:
    if stage>=st and 'after'+str(st) in rec:geom(node,rec['after'+str(st)])
 ff[part]=dd.toxml(encoding='utf-8');write(B/f'preview-{stage}.pptx',ff)
print('Built six slide states using the supplied LFR; all other slides retained.')
