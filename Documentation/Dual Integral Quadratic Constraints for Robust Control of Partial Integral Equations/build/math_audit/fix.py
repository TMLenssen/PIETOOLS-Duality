from pathlib import Path
from xml.dom import minidom as D
from zipfile import ZipFile,ZIP_DEFLATED
from xml.sax.saxutils import escape
import sys,json,posixpath,hashlib,copy,re
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,Overlay,els,first
from build_video_overlays import namespaces,insert_parts
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
with ZipFile(ROOT/'build/simple_deck/source.pptx') as z:old={n:z.read(n) for n in z.namelist()}
rp=lambda p:posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def relmap(f,p):return {r.getAttribute('Id'):posixpath.normpath(posixpath.dirname(p)+'/'+r.getAttribute('Target')) for r in els(D.parseString(f[rp(p)]),'Relationship')}
rm=relmap(files,'ppt/presentation.xml');parts=[rm[s.getAttribute('r:id')] for s in els(D.parseString(files['ppt/presentation.xml']),'p:sldId')]
def sid(s):return first(s,'p:cNvPr').getAttribute('id')
def shape(doc,i):return next(s for s in first(doc,'p:spTree').childNodes if s.nodeType==1 and els(s,'p:cNvPr') and sid(s)==str(i))
def rect(s):
 xf=first(s,'a:xfrm');off=first(xf,'a:off');ext=first(xf,'a:ext')
 return [int(off.getAttribute(k))/12700 for k in ['x','y']]+[int(ext.getAttribute(k))/12700 for k in ['cx','cy']]
def fragment(s):return D.parseString(f'<root {b.DECL}>'+s+'</root>').documentElement.firstChild
def mathrun(self,s,c=None,plain=False):
 return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in s)
b.Math.r=mathrun
class Labels:
 def __init__(self,doc,container=None):self.doc=doc;self.tree=container or first(doc,'p:spTree');self.ident=5000;self.parts=[]
 def add(self,s):self.tree.appendChild(self.doc.importNode(fragment(s),True))
 def text(self,name,x,y,text,size=14,color='252529',width=160,bold=False):
  self.ident+=1;self.add(b.lib.tb(self.ident,name,(x-width/2,y-size*.9,width,size*1.8),text,size,color,'Arial',bold=bold))
 def eq(self,name,x,y,fn,size=14,color='252529',width=180,ident=None):
  self.ident+=1;m=b.Math(size,color);s=b.lib.tb(ident or self.ident,name,(x-width/2,y-size*1.2,width,size*2.4),'',size,color,'Cambria Math')
  eq='<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+fn(m)+'</m:oMath></m:oMathPara></a14:m>'
  self.add(re.sub(r'<a:r>.*?</a:r>',lambda _:eq,s))
 def sub(self,m,c,idx):return m.sub(m.r(c),m.r(idx,plain=True))
def replace_clean_pic(doc,part,oldnum,oldid,currentid):
 od=D.parseString(old[f'ppt/slides/slide{oldnum}.xml']);group=next(g for g in els(od,'p:grpSp') if sid(g)==str(oldid));pic=first(group,'p:pic').cloneNode(True)
 first(pic,'p:cNvPr').setAttribute('id',str(currentid));first(pic,'p:cNvPr').setAttribute('name','Figure with corrected editable mathematics')
 oldr=relmap(old,f'ppt/slides/slide{oldnum}.xml');src=oldr[first(pic,'a:blip').getAttribute('r:embed')]
 media=f'ppt/media/audit_clean_{oldnum}_{oldid}.png';files[media]=old[src]
 rel=D.parseString(files[rp(part)]);rid=f'rIdAudit{currentid}';rr=rel.createElement('Relationship');rr.setAttribute('Id',rid);rr.setAttribute('Type',b.NS['r']+'/image');rr.setAttribute('Target','../media/'+Path(media).name);rel.documentElement.appendChild(rr)
 first(pic,'a:blip').setAttributeNS(b.NS['r'],'r:embed',rid);files[rp(part)]=rel.toxml(encoding='utf-8')
 previous=shape(doc,currentid);previous.parentNode.replaceChild(doc.importNode(pic,True),previous)
 return shape(doc,currentid)
def network_labels(doc,pic,variant):
 # Coordinates come directly from stn_proto_overlay_set.tex, not PDF glyph extraction.
 o=Overlay(doc,pic,18,9,6000)
 def text(t,x,y,size=12,color='252529',bold=False,width=2):o.text(t,x,9-y,size/o.sy,color,bold=bold,width=width)
 def eq(name,x,y,fn,size=14,color='252529',width=4):o.equation(name,x,9-y,fn,size/o.sy,width=width,color=color)
 def sub(m,s,i):return m.sub(m.r(s),m.r(i,plain=True))
 for t,x in [('Proto',3.4),('STN',15)]:text(t,x,4.5,12)
 for t,x,y,c in [('+',2.8,5.65,'174A80'),('−',15.65,3.25,'FF484D'),('−',1.95,3.65,'FF484D')]:eq('Synaptic sign '+t,x,y,lambda m,t=t:m.r(t,plain=True),20,c,1.5)
 if variant=='sums':
  for x,y,c in [(8.15,8.28,'174A80'),(8.15,2.68,'FF484D'),(.6,2.83,'FF484D')]:eq('Summation operator',x,y,lambda m:m.r('∑',plain=True),20,c,1)
 if variant=='delays':
  for idx,x,y,c in [('SG',10,8.25,'174A80'),('GS',9.6,1.3,'FF484D')]:eq('Delay '+idx,x,y,lambda m,idx=idx:sub(m,'τ',idx)+m.r(' = 6 ms',plain=True),12,c,4)
  eq('Self delay',.8,4.65,lambda m:sub(m,'τ','GG'),12,'FF484D',2)
  eq('Self delay value',.8,4.05,lambda m:m.r('= 4 ms',plain=True),11,'FF484D',2)
  eq('Delay interval',8.69,6.0,lambda m:m.sub(m.r('τ'),m.r('ij')),11,'747B82',2)
 if variant=='weights':
  for idx,x,y,c in [('SG',9.5,8.25,'174A80'),('GS',9.1,1.3,'FF484D'),('GG',.8,4.6,'FF484D')]:eq('Connection weight '+idx,x,y,lambda m,idx=idx:sub(m,'w',idx),16,c,3)
 if variant=='nonlinear':
  for x,idx,c in [(6,'G','FF484D'),(12.2,'S','174A80')]:
   eq('Activation '+idx,x,5.8,lambda m,idx=idx:sub(m,'δ',idx)+m.d(sub(m,'z',idx)),12,c,3)
   eq('Activation input '+idx,x+1.25,4.16,lambda m,idx=idx:sub(m,'z',idx),11,'747B82',1.5)
 if variant=='electrode':eq('Stimulation input',17.1,8.1,lambda m:m.r('u')+m.d(m.r('t')),12,width=2)
 o.finish()
changes=[]
for number,oldnum,ident,var in [(7,7,56,'sums'),(8,8,62,'delays'),(9,9,60,'weights'),(10,10,60,'weights'),(11,11,58,'nonlinear'),(12,12,54,'electrode'),(19,18,54,'electrode')]:
 part=parts[number-1];doc=D.parseString(files[part]);namespaces(doc)
 # The archived repeat of slide 12 moved to slide 18 before the controller insertion.
 if number==19:oldnum=12
 pic=replace_clean_pic(doc,part,oldnum,ident,ident);network_labels(doc,pic,var)
 files[part]=doc.toxml(encoding='utf-8');changes.append(f'{number}: complete figure math labels rebuilt')
# Slide 4: intact boundary conditions and a legend ordered by final curve height.
part=parts[3];doc=D.parseString(files[part]);namespaces(doc);pic=replace_clean_pic(doc,part,4,7,7)
o=Overlay(doc,pic,566.929,107.717,6500)
o.text('Temp in paper',283.465,43.4,20.92,color='FFFFFF',width=150)
for x,edge in [(56.705,0),(510.248,1)]:
 o.equation('Boundary condition '+str(edge),x,15.2,lambda m,edge=edge:m.r('t',plain=True)+m.d(m.r('t')+m.r(','+str(edge),plain=True))+m.r(' = 0',plain=True),12,width=108)
for x,val in [(56.705,'s = 0'),(283.465,'s'),(510.248,'s = 1')]:o.equation('Spatial coordinate',x,92.4,lambda m,val=val:m.r(val),17,width=70,color='786D5E')
o.finish()
video=next(p for p in els(doc,'p:pic') if els(p,'a:videoFile'));rm=relmap(files,part)
for el,attr in [(first(video,'a:videoFile'),'r:link'),(first(video,'p14:media'),'r:embed')]:files[rm[el.getAttribute(attr)]]=(B/'delta.mp4').read_bytes()
files[rm[first(video,'a:blip').getAttribute('r:embed')]]=(B/'delta-first.png').read_bytes()
for sp in list(first(doc,'p:spTree').childNodes):
 if sp.nodeType==1 and els(sp,'p:cNvPr') and first(sp,'p:cNvPr').getAttribute('name').startswith('Editable video label:'):sp.parentNode.removeChild(sp)
x,y,w,h=rect(video);sx=w/1920;sy=h/540;L=Labels(doc)
for v in json.loads((B/'delta-labels.json').read_text(encoding='utf8')):
 l,t,r,bot=v['box'];cx=x+(l+r)*sx/2;cy=y+(t+bot)*sy/2;fs=v['size']*sy
 if v['text'].startswith('δ ='):
  value=v['text'][4:].replace('-','−');L.eq('Uncertainty legend '+value,cx,cy,lambda m,value=value:m.r('δ')+m.r(' = '+value,plain=True),fs,v['color'].lstrip('#'),100)
 else:L.text('Editable video label: '+v['text'],cx,cy,v['text'],fs,v['color'].lstrip('#'),(r-l)*sx+8)
files[part]=doc.toxml(encoding='utf-8');changes.append('4: boundary conditions, legend sorted high to low')
# Simulations: same native mathematical signs and anatomical offsets as source diagrams.
for number in [13,14,15]:
 part=parts[number-1];doc=D.parseString(files[part]);namespaces(doc);pic=next(p for p in els(doc,'p:pic') if els(p,'a:videoFile'))
 x,y,w,h=rect(pic);sx=w/1920;sy=h/740;L=Labels(doc)
 for ident in [1002,1003,1004]:
  sp=shape(doc,ident);sp.parentNode.removeChild(sp)
 for text,xx,yy,col in [('+',122.8,205.7,'174A80'),('−',800.3,354.5,'FF484D'),('−',70.1,329.7,'FF484D')]:L.eq('Synaptic sign '+text,x+xx*sx,y+yy*sy,lambda m,text=text:m.r(text,plain=True),20,col,35)
 healthy=number==13;values=['19.0','1.12','6.60'] if healthy else ['20.0','10.7','12.3']
 for idx,value,xx,yy,col in [('SG',values[0],460,40,'174A80'),('GS',values[1],460,465,'FF484D')]:
  L.eq('Connection weight '+idx,x+xx*sx,y+yy*sy,lambda m,idx=idx,value=value:L.sub(m,'w',idx)+m.r(' = '+value,plain=True),14,col,130)
 L.eq('Self inhibition weight',x+43*sx,y+376*sy,lambda m:L.sub(m,'w','GG'),13,'FF484D',50)
 L.eq('Self inhibition value',x+43*sx,y+419*sy,lambda m:m.r(values[2],plain=True),12,'FF484D',50)
 label='Healthy' if healthy else 'Parkinson’s disease'
 L.text('Population condition',x+458*sx,y+277*sy,label,16,width=165,bold=True)
 if number<15:
  desc='Stimulation response returns to equilibrium.' if healthy else 'A small perturbation grows into oscillations.'
  L.text('Population response description',x+465*sx,y+575*sy,desc,11.5,width=315)
 else:
  L.text('Controlled response description',x+465*sx,y+676*sy,'Pulse rejected; equilibrium restored.',11,width=290)
  for ident,idx in [(1005,'G'),(1006,'S')]:
   oldsp=shape(doc,ident);xx,yy,ww,hh=rect(oldsp);oldsp.parentNode.removeChild(oldsp)
   L.eq('External pulse '+idx,xx+ww/2,yy+hh/2,lambda m,idx=idx:L.sub(m,'d',idx),10,'D68B22',40,ident=ident)
  sp=shape(doc,1008);xx,yy,ww,hh=rect(sp);sp.parentNode.removeChild(sp)
  L.eq('External pulse legend',xx+ww/2,yy+hh/2,lambda m:L.sub(m,'d','S')+m.r(', ',plain=True)+L.sub(m,'d','G')+m.r(': external pulse',plain=True),10,'D68B22',170,ident=1008)
 files[part]=doc.toxml(encoding='utf-8');changes.append(f'{number}: signs, descriptions, weights and disturbance subscripts')
# Missing output labels in the primal diagram on the comparison slide.
part=parts[37];doc=D.parseString(files[part]);namespaces(doc);group=next(g for g in els(doc,'p:grpSp') if sid(g)=='43')
L=Labels(doc,group)
for ident,letter in [('33','y'),('34','u')]:
 sp=next(s for s in group.childNodes if s.nodeType==1 and els(s,'p:cNvPr') and sid(s)==ident)
 xx,yy,ww,hh=rect(sp)
 def tilde(m,letter=letter):return '<m:acc><m:accPr><m:chr m:val="̃"/>'+m.ctrl()+'</m:accPr><m:e>'+m.r(letter)+'</m:e></m:acc>'
 L.eq('Primal filtered '+letter,xx+ww+11,yy+hh/2,tilde,20,width=38)
files[part]=doc.toxml(encoding='utf-8');changes.append('38: missing primal filtered-output labels restored')
# Correct repeated literal page numbers and a typo uncovered in the full review.
for number,part in enumerate(parts,1):
 doc=D.parseString(files[part]);changed=False
 for sp in els(doc,'p:sp'):
  nv=first(sp,'p:cNvPr');name=nv.getAttribute('name').lower()
  if name=='slide number':
   for t in els(sp,'a:t'):
    if t.firstChild and t.firstChild.data!=str(number):t.firstChild.data=str(number);changed=True
  for t in els(sp,'a:t'):
   if t.firstChild and 'activation funtions' in t.firstChild.data:t.firstChild.data=t.firstChild.data.replace('activation funtions','activation functions');changed=True
 if changed:files[part]=doc.toxml(encoding='utf-8');changes.append(f'{number}: footer/typography')
# Verify all internal targets and uniqueness of active shape IDs.
for part in parts:
 doc=D.parseString(files[part])
 for fallback in list(els(doc,'mc:Fallback')):fallback.parentNode.removeChild(fallback)
 ids=[n.getAttribute('id') for n in els(doc,'p:cNvPr')];assert len(ids)==len(set(ids)),part
 for rid,path in relmap(files,part).items():
  if '://' not in path:assert path in files,(part,rid,path)
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
 for name,data in files.items():z.writestr(name,data)
(B/'changes.json').write_text(json.dumps(changes,indent=2))
(B/'source.json').write_text(json.dumps(dict(source=str(b.SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper())))
print('\n'.join(changes))
