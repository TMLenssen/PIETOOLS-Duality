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
def part(i):return parts[i-1]
def rp(p):return posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def sid(n):return first(n,'p:cNvPr').getAttribute('id')
def name(n):return first(n,'p:cNvPr').getAttribute('name')
def shapes(doc):return [n for n in first(doc,'p:spTree').childNodes if n.nodeType==1 and els(n,'p:cNvPr') and n.tagName!='p:nvGrpSpPr']
def rect(n):
 xf=first(n,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 return [int(o.getAttribute(k))/12700 for k in ['x','y']]+[int(e.getAttribute(k))/12700 for k in ['cx','cy']]
def geom(n,bb):
 xf=first(n,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 for k,v in zip(['x','y'],bb[:2]):o.setAttribute(k,b.emu(v))
 for k,v in zip(['cx','cy'],bb[2:]):e.setAttribute(k,b.emu(v))
def frag(s):return D.parseString(f'<root {b.DECL}>'+s+'</root>').documentElement.firstChild
def clear_timing(d):
 for node in list(d.documentElement.childNodes):
  if node.nodeType==1 and (node.tagName in ['p:timing','p:transition'] or (node.tagName=='mc:AlternateContent' and els(node,'p:transition'))):d.documentElement.removeChild(node)
def transition(d,morph=False):
 if morph:
  ns='http://schemas.microsoft.com/office/powerpoint/2015/09/main'
  s='<mc:AlternateContent xmlns:mc="'+b.NS['mc']+'" xmlns:p159="'+ns+'" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main"><mc:Choice Requires="p159"><p:transition p14:dur="1200"><p159:morph option="byObject"/></p:transition></mc:Choice><mc:Fallback><p:transition><p:fade/></p:transition></mc:Fallback></mc:AlternateContent>'
 else:s='<p:transition xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" p14:dur="250"><p:fade/></p:transition>'
 d.documentElement.appendChild(d.importNode(frag(s),True))

d20=D.parseString(files[part(20)]);nodes20={sid(n):n.cloneNode(True) for n in shapes(d20)}
pde=nodes20['5019'];pie=nodes20['10'];pdebox=[323,84,70,70];piebox=[583,84,70,70]
def named(n,nm):first(n,'p:cNvPr').setAttribute('name',nm);return n
named(pde,'!!PDE block');named(pie,'!!PIE block')
for i in range(20,25):
 d=D.parseString(files[part(i)]);namespaces(d);tr=first(d,'p:spTree');rd=D.parseString(files[rp(part(i))]);clear_timing(d)
 ident=10000
 def asset(node,nm,bb,sourcepart=part(20)):
  global ident
  node=node.cloneNode(True);geom(node,bb);remap={}
  for nv in els(node,'p:cNvPr'):
   oid=nv.getAttribute('id')
   if oid not in remap:ident+=1;remap[oid]=str(ident)
   nv.setAttribute('id',remap[oid])
  named(node,nm)
  if sourcepart!=part(i):
   rr={r.getAttribute('Id'):r for r in els(D.parseString(original[rp(sourcepart)]),'Relationship')};mp={}
   for el in node.getElementsByTagName('*'):
    for att in ['r:embed','r:link','r:id']:
     rid=el.getAttribute(att)
     if rid in rr:
      if rid not in mp:
       r=rr[rid].cloneNode(True);new='rIdBlock'+str(len(els(rd,'Relationship'))+100);r.setAttribute('Id',new);rd.documentElement.appendChild(rd.importNode(r,True));mp[rid]=new
      el.setAttributeNS(b.NS['r'],att,mp[rid])
  tr.appendChild(d.importNode(node,True))
 for n in list(shapes(d)):
  if sid(n) in (['5019','10'] if i==20 else ['11','13']):tr.removeChild(n)
 # The same canonical block groups are used on every property slide.
 asset(pde,'!!PDE block',rect(pde) if i==20 else pdebox)
 asset(pie,'!!PIE block',piebox)
 if i==20:
  for n in shapes(d):
   if sid(n)=='7':
    named(n,'PIE dynamics');geom(n,[467,204,239,158])
    for pp in els(n,'a:rPr')+els(n,'a:endParaRPr'):
     if pp.hasAttribute('sz'):pp.setAttribute('sz','1050')
   if sid(n)=='9':named(n,'PDE dynamics');geom(n,[272,190,176,173])
   if sid(n)=='3':named(n,'Property list')
   if sid(n)=='14':named(n,'Equivalence arrow')
   if sid(n)=='15':named(n,'Exact label');geom(n,[453,156,78,24])
  # Correct accidental literal alignment markers introduced by PowerPoint's LaTeX import.
  for n in shapes(d):
   if name(n) in ['PDE dynamics','PIE dynamics']:
    for t in els(n,'m:t'):
     if t.firstChild:t.firstChild.data=t.firstChild.data.replace('&','')
 else:
  for n in shapes(d):
   if sid(n)=='15':geom(n,[453,156,78,24])
 transition(d)
 files[part(i)]=d.toxml(encoding='utf-8');files[rp(part(i))]=rd.toxml(encoding='utf-8')

# Full-height pillars reuse the exact problem-box fill, including its opacity.
d=D.parseString(original[part(25)]);namespaces(d);tr=first(d,'p:spTree');rd=D.parseString(files[rp(part(25))]);oldnodes={name(n):n.cloneNode(True) for n in shapes(d)}
for n in list(shapes(d)):
 if not any(k in name(n).lower() for k in ['footer','slide number','logo']):tr.removeChild(n)
clear_timing(d)
problem=D.parseString(original[part(16)]);prob=next(n for n in shapes(problem) if 'Problems' in ''.join(t.firstChild.data for t in els(n,'a:t') if t.firstChild))
fill=next(n for n in first(prob,'p:spPr').childNodes if n.nodeType==1 and n.tagName=='a:solidFill').toxml()
s=b.Slide();s.i=20000
for xx,nm in [(0,'!!Physical pillar'),(436,'!!PIE pillar')]:
 s.add(f'<p:sp>{b.nv(s.ident(),nm)}<p:spPr>{b.xf(xx,0,284,405)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{fill}<a:ln><a:noFill/></a:ln></p:spPr></p:sp>')
for nm,xx,yy,txt,sz in [('Physical heading',142,45,'Distributed models',22),('Pillar number',578,33,'PILLAR 1',12),('PIE heading',578,64,'Partial Integral Equations',20)]:s.label(nm,xx,yy,txt,sz,'252529',w=264,bold=True)
s.label('Physical subtitle',142,77,'Original dynamics',13,'633434',w=252)
s.label('PIE subtitle',578,91,'Equivalent representation',13,'633434',w=264)
s.path('Tractability arrow',[(305,184),(415,184)],width=1.1,color='633434')
s.label('Tractability',360,164,'Tractability',14,'633434',w=140)
s.path('Solutions arrow',[(415,258),(305,258)],width=1.1,color='633434')
s.label('Solutions',360,281,'Solutions',14,'633434',w=140)
s.label('PIE result',578,337,'Analysis and synthesis',18,'252529',w=260,bold=True)
s.label('PIE method',578,363,'using LMIs',16,'633434',w=250)
for xml in reversed(s.parts):tr.insertBefore(d.importNode(frag(xml),True),next(n for n in tr.childNodes if n.nodeType==1 and n.tagName not in ['p:nvGrpSpPr','p:grpSpPr']))
ident=30000
def addasset(node,nm,bb,src=part(25)):
 global ident
 node=node.cloneNode(True);geom(node,bb);remap={}
 for nv in els(node,'p:cNvPr'):
  oid=nv.getAttribute('id')
  if oid not in remap:ident+=1;remap[oid]=str(ident)
  nv.setAttribute('id',remap[oid])
 named(node,nm)
 # The pale problem-box color needs dark labels instead of the former white labels.
 for rr in els(node,'a:rPr')+els(node,'a:endParaRPr'):
  for c in els(rr,'a:srgbClr'):
   if c.getAttribute('val')=='FFFFFF':c.setAttribute('val','252529')
  for c in list(els(rr,'a:schemeClr')):
   if c.getAttribute('val') in ['bg1','lt1']:
    nc=c.ownerDocument.createElement('a:srgbClr');nc.setAttribute('val','252529');c.parentNode.replaceChild(nc,c)
 if src!=part(25):
  rs={r.getAttribute('Id'):r for r in els(D.parseString(original[rp(src)]),'Relationship')};mp={}
  for el in node.getElementsByTagName('*'):
   for att in ['r:embed','r:link','r:id']:
    rid=el.getAttribute(att)
    if rid in rs:
     if rid not in mp:
      r=rs[rid].cloneNode(True);new='rIdPillarBlock'+str(len(els(rd,'Relationship')));r.setAttribute('Id',new);rd.documentElement.appendChild(rd.importNode(r,True));mp[rid]=new
     el.setAttributeNS(b.NS['r'],att,mp[rid])
 tr.appendChild(d.importNode(node,True))
 return node
for key,xx,canonical,nm in [('Physical PDE LFR',31,pde,'!!PDE block'),('PIE LFR',467,pie,'!!PIE block')]:
 full=oldnodes[key].cloneNode(True);outer=[xx,124,230,176.3]
 xf=first(full,'a:xfrm');co=first(xf,'a:chOff');ce=first(xf,'a:chExt')
 cb=[int(co.getAttribute(k))/12700 for k in ['x','y']]+[int(ce.getAttribute(k))/12700 for k in ['cx','cy']]
 plant=next(n for n in full.childNodes if n.nodeType==1 and els(n,'p:cNvPr') and name(n)=='Plant')
 pb=rect(plant)
 bb=[outer[0]+(pb[0]-cb[0])*outer[2]/cb[2],outer[1]+(pb[1]-cb[1])*outer[3]/cb[3],pb[2]*outer[2]/cb[2],pb[3]*outer[3]/cb[3]]
 for n in list(full.childNodes):
  if n.nodeType==1 and els(n,'p:cNvPr') and name(n) in ['Plant','Plant label']:full.removeChild(n)
 addasset(full,'Restored '+key+' connections',outer)
 addasset(canonical,nm,bb,part(20))
# Original model images form one aligned row at the base of the physical pillar.
for key,nm,bb in [('STN-GPe image','STN-GPe image',[15,335,78,37.5]),('ASML image','ASML image',[104,334,77,40]),('Canon image','Canon image',[192,335,77,37.7])]:addasset(oldnodes[key],nm,bb)
# A white backing keeps the neural artwork legible, matching the photo backgrounds.
tile=frag(f'<p:sp>{b.nv(39990,"Neural image backing")}<p:spPr>{b.xf(12,331,84,46)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{b.fill("FFFFFF")}<a:ln><a:noFill/></a:ln></p:spPr></p:sp>')
neuralnode=next(n for n in shapes(d) if name(n)=='STN-GPe image');tr.insertBefore(d.importNode(tile,True),neuralnode)
lbl=frag(b.lib.tb(39991,'Application names',(12,309,260,20),'STN–GPe · ASML · Canon',12,'633434','Aptos'));tr.appendChild(d.importNode(lbl,True))
transition(d,True)
files[part(25)]=d.toxml(encoding='utf-8');files[rp(part(25))]=rd.toxml(encoding='utf-8')

# Separate the two sides of the explicit PIE so that they can gather into T and A.
def run(self,txt,c=None,plain=False):return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in txt)
b.Math.r=run
def sub(m,a,i):return m.sub(m.r(a),m.r(i,plain=True))
def dot(m,e):return '<m:acc><m:accPr><m:chr m:val="̇"/>'+m.ctrl()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
def args(m,e,a='t'):return e+m.d(m.r(a))
def dx(m,i):return args(m,dot(m,sub(m,'x',i)))
def intterm(m,ij):
 return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('s')+'</m:sup><m:e>'+args(m,m.sub(dot(m,m.r('φ')),m.r(ij+',θ',plain=True)),'t,θ')+m.r('dθ')+'</m:e></m:nary>'
def group(nm,xml,bb,ident):
 x,y,w,h=bb
 return frag(f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{ident}" name="{nm}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{b.emu(x)}" y="{b.emu(y)}"/><a:ext cx="{b.emu(w)}" cy="{b.emu(h)}"/><a:chOff x="{b.emu(x)}" y="{b.emu(y)}"/><a:chExt cx="{b.emu(w)}" cy="{b.emu(h)}"/></a:xfrm></p:grpSpPr>'+''.join(xml)+'</p:grpSp>')
groups=[]
for side,color,cx,width,bb in [('time','20558B',538,146,[465,195,146,166]),('spatial','A82222',664,80,[624,195,80,166]),('equals','252529',617,20,[607,195,20,166])]:
 ss=b.Slide();ss.i={'time':40000,'spatial':40100,'equals':40200}[side]
 for j,(yy,ii,ij) in enumerate([(211,'S',None),(235,'G',None),(270,'G','GS'),(309,'S','SG'),(348,'G','GG')]):
  if side=='equals':fn=lambda m:m.r('=',plain=True)
  elif side=='time':fn=(lambda m,ii=ii:sub(m,'τ',ii)+dx(m,ii)) if ij is None else (lambda m,ii=ii,ij=ij:dx(m,ii)+m.r('+')+intterm(m,ij))
  else:fn=(lambda m,ii=ii:m.r('−')+args(m,sub(m,'x',ii))) if ij is None else (lambda m,ij=ij:m.r('−')+m.frac(m.r('1'),sub(m,'τ',ij))+args(m,sub(m,'φ',ij+',s'),'t,s'))
  ss.equation(side+' component '+str(j),cx,yy,fn,10.5,w=width,color=color)
  if side=='time':ss.parts[-1]=ss.parts[-1].replace('m:val="center"','m:val="right"').replace('algn="ctr"','algn="r"')
  if side=='spatial':ss.parts[-1]=ss.parts[-1].replace('m:val="center"','m:val="left"').replace('algn="ctr"','algn="l"')
 groups.append(group('!!PIE '+side+' terms',ss.parts,bb,ss.i+10))
d20=D.parseString(files[part(20)]);tr20=first(d20,'p:spTree')
for n in list(shapes(d20)):
 if name(n)=='PIE dynamics':tr20.removeChild(n)
for g in groups:tr20.appendChild(d20.importNode(g,True))
files[part(20)]=d20.toxml(encoding='utf-8')
d21=D.parseString(files[part(21)]);tr21=first(d21,'p:spTree')
for g in groups:tr21.appendChild(d21.importNode(g,True))
pdesource=next(n for n in shapes(d20) if name(n)=='PDE dynamics').cloneNode(True)
named(pdesource,'PDE dynamics leaving');first(pdesource,'p:cNvPr').setAttribute('id','40999');tr21.appendChild(d21.importNode(pdesource,True))
for n in shapes(d21):
 if name(n)=='PIE dynamics':
  for rr in els(n,'m:r'):
   text=''.join(t.firstChild.data for t in els(rr,'m:t') if t.firstChild)
   col='20558B' if text in ['𝒯'] else 'A82222' if text in ['𝒜'] else None
   if col:
    for cc in els(rr,'a:srgbClr'):cc.setAttribute('val',col)
files[part(21)]=d21.toxml(encoding='utf-8')

def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,v in data.items():z.writestr(n,v)
write(B/'staged.pptx',files)
# Static end state of extraction for layout review.
preview=files.copy();dd=D.parseString(files[part(20)]);tt=first(dd,'p:spTree')
for n in list(shapes(dd)):
 if name(n)=='Surrounding LFR':tt.removeChild(n)
 if name(n)=='!!PDE block':geom(n,pdebox)
preview[part(20)]=dd.toxml(encoding='utf-8')
dd=D.parseString(preview[part(21)]);tt=first(dd,'p:spTree')
for n in list(shapes(dd)):
 if name(n).startswith('!!PIE ') and name(n).endswith(' terms') or name(n)=='PDE dynamics leaving':tt.removeChild(n)
preview[part(21)]=dd.toxml(encoding='utf-8');write(B/'static.pptx',preview)
for i,p in enumerate(parts,1):
 if i not in range(20,26):assert files[p]==original[p],i
(B/'source.json').write_text(json.dumps(dict(source=str(b.SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper(),slides=len(parts))))
(B/'animation.json').write_text(json.dumps(dict(pdebox=pdebox,sourcebox=rect(pde),slides=len(parts))))
print('Updated canonical blocks on slides 20–24 and full-height, color-matched pillars on 25.')
