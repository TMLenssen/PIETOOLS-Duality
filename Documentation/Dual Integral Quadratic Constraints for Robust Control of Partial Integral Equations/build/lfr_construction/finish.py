from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import sys,json,posixpath,re,copy
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,els,first
from build_video_overlays import namespaces
def load(p):
 with ZipFile(p) as z:return {n:z.read(n) for n in z.namelist()}
files=load(B/'source.pptx');animated=load(B/'animated.pptx');staged=load(B/'staged.pptx')
rp=lambda p:posixpath.dirname(p)+'/_rels/'+posixpath.basename(p)+'.rels'
def rels(data,part):return {r.getAttribute('Id'):r for r in els(D.parseString(data[rp(part)]),'Relationship')}
def target(part,r):return posixpath.normpath(posixpath.dirname(part)+'/'+r.getAttribute('Target'))
pr=D.parseString(files['ppt/_rels/presentation.xml.rels']);pres=D.parseString(files['ppt/presentation.xml']);lst=first(pres,'p:sldIdLst')
rm={r.getAttribute('Id'):target('ppt/presentation.xml',r) for r in els(pr,'Relationship')};parts=[rm[s.getAttribute('r:id')] for s in els(pres,'p:sldId')]
def sid(n):return first(n,'p:cNvPr').getAttribute('id')
part=parts[18];ar=rels(animated,'ppt/slides/slide19.xml');fr=D.parseString(files[rp(part)]);existing=rels(files,part)
doc=D.parseString(animated['ppt/slides/slide19.xml']);namespaces(doc)
# Custom motion effects are emphasis/path operations on already visible objects.
# The COM default labels them as entrances, which would hide the source terms.
for c in els(doc,'p:cTn'):
 if c.getAttribute('presetID')=='0' and c.hasAttribute('presetClass'):c.setAttribute('presetClass','path')
mapping={}
for r in ar.values():
 typ=r.getAttribute('Type').split('/')[-1]
 if typ in ['slideLayout','notesSlide']:
  mapping[r.getAttribute('Id')]=next(x.getAttribute('Id') for x in existing.values() if x.getAttribute('Type').endswith('/'+typ));continue
 oldtarget=target('ppt/slides/slide19.xml',r);newtarget='ppt/media/lfr19_'+Path(oldtarget).name
 if r.getAttribute('TargetMode')!='External':files[newtarget]=animated[oldtarget]
 nr=r.cloneNode(True);rid='rIdLFR'+str(len(mapping)+100);nr.setAttribute('Id',rid)
 if r.getAttribute('TargetMode')!='External':nr.setAttribute('Target',posixpath.relpath(newtarget,posixpath.dirname(part)))
 fr.documentElement.appendChild(fr.importNode(nr,True));mapping[r.getAttribute('Id')]=rid
for el in doc.getElementsByTagName('*'):
 for attr in ['r:embed','r:link','r:id']:
  val=el.getAttribute(attr)
  if val in mapping:el.setAttributeNS(b.NS['r'],attr,mapping[val])
files[part]=doc.toxml(encoding='utf8').replace(b'encoding="utf8"',b'encoding="utf-8"');files[rp(part)]=fr.toxml(encoding='utf-8')
note=next(target(part,r) for r in existing.values() if r.getAttribute('Type').endswith('/notesSlide'));files[note]=staged[note]
# Closing slide placed after Future work, before References and backup material.
newpart='ppt/slides/slide52.xml';newrel=D.parseString(b.lib.xml('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'))
rr=newrel.createElement('Relationship');rr.setAttribute('Id','rIdLayout');rr.setAttribute('Type',b.NS['r']+'/slideLayout');rr.setAttribute('Target','../slideLayouts/slideLayout12.xml');newrel.documentElement.appendChild(rr)
def geometry(node,x,y,w,h):
 xf=first(node,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 for k,v in [('x',x),('y',y)]:o.setAttribute(k,b.emu(v))
 for k,v in [('cx',w),('cy',h)]:e.setAttribute(k,b.emu(v))
ident=14000
def cloneasset(sourcepart,node,name,box):
 global ident
 node=node.cloneNode(True);geometry(node,*box)
 for nv in els(node,'p:cNvPr'):ident+=1;nv.setAttribute('id',str(ident))
 first(node,'p:cNvPr').setAttribute('name',name)
 srcmap=rels(files,sourcepart);mapping={}
 for el in [node]+list(node.getElementsByTagName('*')):
  for att in ['r:embed','r:link','r:id']:
   rid=el.getAttribute(att)
   if not rid or rid not in srcmap:continue
   if rid not in mapping:
    src=srcmap[rid];r=src.cloneNode(True);newid='rIdClosing'+str(len(els(newrel,'Relationship')));r.setAttribute('Id',newid)
    if src.getAttribute('TargetMode')!='External':r.setAttribute('Target',posixpath.relpath(target(sourcepart,src),'ppt/slides'))
    newrel.documentElement.appendChild(newrel.importNode(r,True));mapping[rid]=newid
   el.setAttributeNS(b.NS['r'],att,mapping[rid])
 return node.toxml()
source3=D.parseString(files[parts[2]]);shapes=list(first(source3,'p:spTree').childNodes)
def pick(i):return next(n for n in shapes if n.nodeType==1 and els(n,'p:cNvPr') and sid(n)==str(i))
assets=[cloneasset(parts[2],pick(7),'ASML wafer stage',(40,103,200,104)),cloneasset(parts[2],pick(19),'Canon production printer',(487,105,200,98))]
base19=D.parseString(staged[part]);neural=next(g for g in els(base19,'p:grpSp') if sid(g)=='54')
# All diagram resources are inherited from the original slide, whose rIds remain valid.
assets.append(cloneasset(part,neural,'STN-GPe example schematic',(257,109,201,97)))
d=b.Slide();d.i=15000
d.label('Closing title',360,46,'Beyond the STN–GPe example',25,w=648,bold=True);d.parts[-1]=d.parts[-1].replace('algn="ctr"','algn="l"')
for x,title,model in [(140,'ASML wafer stages','Wave / beam models'),(360,'STN–GPe network','Delayed neural models'),(587,'Canon production printers','Heat / moisture models')]:
 d.label('Application '+title,x,85,title,15,'D61016',w=215,bold=True)
 d.label('Model class '+title,x,222,model,13,w=220)
d.path('ASML to common framework',[(140,239),(140,274),(192,274)],width=1.2)
d.path('STN-GPe to common framework',[(360,239),(360,261)],width=1.2)
d.path('Canon to common framework',[(587,239),(587,274),(528,274)],width=1.2)
d.outline('Shared framework',(192,261,336,68),width=1)
d.label('Framework title',360,282,'Common PIE / LFR representation',18,w=330,bold=True)
d.label('Framework capability',360,309,'Robust analysis and controller synthesis',14,w=335)
d.label('Closing takeaway',360,354,'The framework applies across distributed systems.',17,'D61016',w=660,bold=True)
d.label('Footer',236,390,'Msc Defence T.M. Lenssen',8,b.GRAY,w=400);d.parts[-1]=d.parts[-1].replace('algn="ctr"','algn="l"')
d.label('Slide number',634,390,'43',8,b.GRAY,w=28)
logo=next(n for n in shapes if n.nodeType==1 and els(n,'p:cNvPr') and 'logo' in first(n,'p:cNvPr').getAttribute('name').lower())
assets.append(cloneasset(parts[2],logo,'Original TUe logo',(666,379,36,20)))
tree='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+''.join(d.parts+assets)
files[newpart]=b.lib.xml(f'<p:sld {b.DECL} mc:Ignorable="a14"><p:cSld><p:spTree>{tree}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>');files[rp(newpart)]=newrel.toxml(encoding='utf-8')
ids=els(pres,'p:sldId');refidx=next(i for i,p in enumerate(parts) if b'>References<' in files[p])
newid=pres.createElement('p:sldId');newid.setAttribute('id',str(max(int(x.getAttribute('id')) for x in ids)+1));newid.setAttributeNS(b.NS['r'],'r:id','rIdClosingLFR');lst.insertBefore(newid,ids[refidx])
rr=pr.createElement('Relationship');rr.setAttribute('Id','rIdClosingLFR');rr.setAttribute('Type',b.NS['r']+'/slide');rr.setAttribute('Target','slides/slide52.xml');pr.documentElement.appendChild(rr)
files['ppt/presentation.xml']=pres.toxml(encoding='utf-8');files['ppt/_rels/presentation.xml.rels']=pr.toxml(encoding='utf-8')
ct=D.parseString(files['[Content_Types].xml']);ov=ct.createElement('Override');ov.setAttribute('PartName','/'+newpart);ov.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');ct.documentElement.appendChild(ov);files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
b.add_notes(files,52,'STN-GPe is the worked example, not a restriction on application. Distributed wave/beam models of ASML wafer stages and coupled heat/moisture models of Canon production printers can be put into suitable PIE and LFR representations. The uncertainty/nonlinearity class and performance channels are chosen for each model; the same robust-analysis and controller-synthesis framework can then be applied under its stated assumptions. The images are the existing images from slide 3, and the neural circuit is the existing editable schematic. This slide communicates scope, not a claim that every industrial model has already been synthesized or experimentally validated.')
parts.insert(refidx,newpart)
# Maintain correct visible numbering after inserting the closing slide.
for i,p in enumerate(parts,1):
 if i<=refidx:continue
 dd=D.parseString(files[p]);changed=False
 for sp in els(dd,'p:sp'):
  name=first(sp,'p:cNvPr').getAttribute('name').lower()
  if name=='slide number' or 'slide number placeholder' in name:
   for t in els(sp,'a:t'):
    if t.firstChild and t.firstChild.data!=str(i):t.firstChild.data=str(i);changed=True
 if changed:files[p]=dd.toxml(encoding='utf-8')
for p in parts:
 dd=D.parseString(files[p])
 for f in list(els(dd,'mc:Fallback')):f.parentNode.removeChild(f)
 ids=[n.getAttribute('id') for n in els(dd,'p:cNvPr')];assert len(ids)==len(set(ids)),p
 for r in rels(files,p).values():
  if r.getAttribute('TargetMode')!='External':assert target(p,r) in files,(p,r.toxml())
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
 for n,data in files.items():z.writestr(n,data)
# A one-slide copy for actual animation playback export.
vd=files.copy();pp=D.parseString(vd['ppt/presentation.xml']);sl=first(pp,'p:sldIdLst')
for i,node in enumerate(list(els(pp,'p:sldId'))):
 if i!=18:sl.removeChild(node)
vd['ppt/presentation.xml']=pp.toxml(encoding='utf-8')
with ZipFile(B/'playback-check.pptx','w',ZIP_DEFLATED) as z:
 for n,data in vd.items():z.writestr(n,data)
print('Final deck: 52 slides; four-click build on 19; closing slide '+str(refidx+1)+' before References.')
