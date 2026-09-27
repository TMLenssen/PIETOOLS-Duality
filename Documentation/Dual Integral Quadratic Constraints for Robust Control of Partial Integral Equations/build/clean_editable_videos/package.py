from pathlib import Path
from xml.dom import minidom as D
import sys,json,zipfile,posixpath,hashlib,copy,subprocess,re
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,Overlay,els,first
from build_video_overlays import insert_parts,namespaces
with zipfile.ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
with zipfile.ZipFile(ROOT/'build/simple_deck/source.pptx') as z:old={n:z.read(n) for n in z.namelist()}
relpath=lambda part:posixpath.dirname(part)+'/_rels/'+posixpath.basename(part)+'.rels'
def rmap(data,part):return {r.getAttribute('Id'):r for r in els(D.parseString(data[relpath(part)]),'Relationship')}
def target(part,rel):return posixpath.normpath(posixpath.dirname(part)+'/'+rel.getAttribute('Target'))
rels={r.getAttribute('Id'):target('ppt/presentation.xml',r) for r in els(D.parseString(files['ppt/_rels/presentation.xml.rels']),'Relationship')}
parts=[rels[r.getAttribute('r:id')] for r in els(D.parseString(files['ppt/presentation.xml']),'p:sldId')]
manifest=[]
def shape_id(sp):return first(sp,'p:cNvPr').getAttribute('id')
def box(pic):
 xf=first(pic,'a:xfrm');o=first(xf,'a:off');e=first(xf,'a:ext')
 return [int(o.getAttribute(k))/12700 for k in ['x','y']]+[int(e.getAttribute(k))/12700 for k in ['cx','cy']]
def setbox(sp,x,y,w,h):
 xf=first(sp,'a:xfrm');off=first(xf,'a:off');ext=first(xf,'a:ext')
 for k,v in [('x',x),('y',y)]:off.setAttribute(k,b.emu(v))
 for k,v in [('cx',w),('cy',h)]:ext.setAttribute(k,b.emu(v))
def import_labels(doc,part,oldpart,select):
 od=D.parseString(old[oldpart]);tree=first(doc,'p:spTree');r=D.parseString(files[relpath(part)]);orm=rmap(old,oldpart)
 remap={}
 for sp in list(first(od,'p:spTree').childNodes):
  if sp.nodeType!=1 or not els(sp,'p:cNvPr') or not select(sp):continue
  clone=sp.cloneNode(True)
  for el in [clone]+list(clone.getElementsByTagName('*')):
   for attr in ['r:embed','r:link']:
    rid=el.getAttribute(attr)
    if not rid:continue
    if rid not in remap:
     rr=orm[rid];src=target(oldpart,rr);dest='ppt/media/editable_'+str(len(files))+'_'+Path(src).name;files[dest]=old[src]
     new=r.importNode(rr,True);nrid='rIdEditable'+str(len(remap)+100);new.setAttribute('Id',nrid);new.setAttribute('Target',posixpath.relpath(dest,posixpath.dirname(part)));r.documentElement.appendChild(new);remap[rid]=nrid
    el.setAttributeNS(b.NS['r'],attr,remap[rid])
  tree.appendChild(doc.importNode(clone,True))
 files[relpath(part)]=r.toxml(encoding='utf-8')
 return od
def replace_media(part,doc,pic,path):
 rm=rmap(files,part);data=path.read_bytes()
 for el,att in [(first(pic,'a:videoFile'),'r:link'),(first(pic,'p14:media'),'r:embed')]:files[target(part,rm[el.getAttribute(att)])]=data
 poster=B/(path.stem+'-first.png')
 if not poster.exists():subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(path),'-frames:v','1',str(poster)],check=True)
 files[target(part,rm[first(pic,'a:blip').getAttribute('r:embed')])]=poster.read_bytes()
 # Video crop was used when baking labels; clean media uses its full frame.
 for crop in list(els(pic,'a:srcRect')):crop.parentNode.removeChild(crop)
 manifest.append(dict(slide=parts.index(part)+1,name=first(pic,'p:cNvPr').getAttribute('name'),media=str(path)))
def native_labels(doc,pic,name,W,H):
 x,y,w,h=box(pic);sx=w/W;sy=h/H;pieces=[]
 labels=json.loads((B/(name+'-labels.json')).read_text(encoding='utf-8'))
 for i,v in enumerate(labels,1000):
  l,t,r,bot=v['box'];fs=v['size']*sy;cx=x+(l+r)/2*sx;cy=y+(t+bot)/2*sy
  width=(r-l)*sx+8
  pieces.append(b.lib.tb(i,'Editable video label: '+v['text'],(cx-width/2,cy-fs*.9,width,fs*1.8),v['text'],fs,v['color'].lstrip('#'),'Arial',bold=v['bold']))
 insert_parts(doc,pieces)
 return len(labels)
for ordinal,name,W,H in [(4,'delta',1920,540),(13,'healthy',1920,740),(14,'parkinsonian',1920,740),(15,'controlled',1920,740)]:
 part=parts[ordinal-1];doc=D.parseString(files[part]);namespaces(doc)
 pic=next(p for p in els(doc,'p:pic') if els(p,'a:videoFile'))
 replace_media(part,doc,pic,B/(name+'.mp4'));count=native_labels(doc,pic,name,W,H)
 if ordinal==4:
  for tn in els(doc,'p:cTn'):
   if tn.getAttribute('dur')=='36000':tn.setAttribute('dur','18000')
 if ordinal==15:
  # Remove the repeated description; the plots and editable legend say this already.
  for sp in list(els(doc,'p:sp')):
   if shape_id(sp)=='68':sp.parentNode.removeChild(sp)
  template=D.parseString(files['ppt/slides/slide33.xml'])
  controller=next(sp for sp in els(template,'p:sp') if first(sp,'p:cNvPr').getAttribute('name')=='Controller').cloneNode(True)
  first(controller,'p:cNvPr').setAttribute('id','2000');first(controller,'p:cNvPr').setAttribute('name','Controller K block')
  x,y,w,h=box(pic);sx=w/W;sy=h/H
  
  for dash in list(els(controller,'a:prstDash')):dash.parentNode.removeChild(dash)
  setbox(controller,x+900*sx,y+70*sy,80*sx,80*sy);first(doc,'p:spTree').appendChild(doc.importNode(controller,True))
  o=Overlay(doc,pic,W,H,2001);o.equation('Controller K',940,110,lambda m:m.r('K'),48,width=70);insert_parts(doc,o.parts)
 files[part]=doc.toxml(encoding='utf-8');manifest[-1]['editable_labels']=count
# Existing videos: restore the native text/math labels and their original motion.
part=parts[1];doc=D.parseString(files[part]);namespaces(doc)
od=import_labels(doc,part,'ppt/slides/slide2.xml',lambda sp:shape_id(sp) not in ['1','2','5','6','7','20','21','22'])
for pic in [p for p in els(doc,'p:pic') if els(p,'a:videoFile')]:
 sid=shape_id(pic);op=next(p for p in els(od,'p:pic') if shape_id(p)==sid);setbox(pic,*box(op))
 replace_media(part,doc,pic,ROOT/'build/deck_label_overlays'/('cart_rigid_clean.mp4' if sid=='20' else 'cart_flexible_clean.mp4'))
timing=first(doc,'p:timing');timing.parentNode.replaceChild(doc.importNode(first(od,'p:timing'),True),timing)
files[part]=doc.toxml(encoding='utf-8')
for ordinal in [27,28,29]:
 part=parts[ordinal-1];oldpart=f'ppt/slides/slide{ordinal-1}.xml';doc=D.parseString(files[part]);namespaces(doc)
 od=import_labels(doc,part,oldpart,lambda sp:shape_id(sp) not in ['1','20'] and (ordinal==27 or int(shape_id(sp))>=119))
 pic=next(p for p in els(doc,'p:pic') if els(p,'a:videoFile'));op=next(p for p in els(od,'p:pic') if els(p,'a:videoFile'));setbox(pic,*box(op))
 path=ROOT/'build/deck_label_overlays/sector_clean.mp4' if ordinal==27 else B/('slope-integral.mp4' if ordinal==28 else 'slope-rate.mp4')
 replace_media(part,doc,pic,path)
 if ordinal in [28,29]:
  o=Overlay(doc,pic,1440,810,2000)
  for k,lim in enumerate([1150,700]):
   l=100+k*700;r=l+550;top=85;bot=330;tag=['S','G'][k]
   o.text(['STN slope','GPe slope'][k],(l+r)/2,top-29,27,bold=True)
   for v in [-lim,0,lim]:o.text(f'{v:g}',l+(v+lim)/(2*lim)*(r-l),bot+23,20,width=80)
   for v in [0,.5,1]:o.text(f'{v:g}',l-30,bot-v/1.05*(bot-top),20,width=40)
   o.equation('Slope horizontal axis '+tag,(l+r)/2,bot+58,lambda m,tag=tag:m.sub(m.r('z'),m.r(tag,plain=True)),24,width=180)
   o.equation('Slope vertical axis '+tag,l-78,(top+bot)/2,lambda m,tag=tag:m.sub(m.r('δ′'),m.r(tag,plain=True))+m.d(m.r('z')),24,width=200,angle=-90)
  insert_parts(doc,o.parts)
 files[part]=doc.toxml(encoding='utf-8')
# Every slide not involved in this request must remain byte-for-byte unchanged.
changed={parts[i-1] for i in [2,4,13,14,15,27,28,29]}
with zipfile.ZipFile(B/'source.pptx') as z:
 for part in parts:
  if part not in changed:assert files[part]==z.read(part)
for part in parts:
 
 try:d=D.parseString(files[part])
 except Exception:
  (B/'bad.xml').write_bytes(files[part]);print('BAD',part);raise
 for fallback in list(els(d,'mc:Fallback')):fallback.parentNode.removeChild(fallback)
 ids=[r.getAttribute('id') for r in els(d,'p:cNvPr')];assert len(ids)==len(set(ids)),part
 for rid,rr in rmap(files,part).items():
  if rr.getAttribute('TargetMode')!='External':assert target(part,rr) in files,(part,rid)
with zipfile.ZipFile(B/'final.pptx','w',zipfile.ZIP_DEFLATED) as z:
 for name,data in files.items():z.writestr(name,data)
(B/'manifest.json').write_text(json.dumps(manifest,indent=2))
(B/'source.json').write_text(json.dumps(dict(source=str(b.SOURCE),hash=hashlib.sha256((B/'source.pptx').read_bytes()).hexdigest().upper()),indent=2))
print('Packaged 50 slides, 9 clean videos and native editable labels.')

