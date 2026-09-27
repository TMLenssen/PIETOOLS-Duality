"""Snapshot the current deck and identify graphics/media overlays to bake."""
from pathlib import Path
from xml.dom import minidom as D
import zipfile,json,hashlib,posixpath
from build_image_overlays import SOURCE,els,first
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/simple_deck';OUT.mkdir(parents=True,exist_ok=True)

def geom(node):
    x=first(node,'a:xfrm');o=first(x,'a:off');e=first(x,'a:ext')
    return [int(o.getAttribute('x'))/12700,int(o.getAttribute('y'))/12700,int(e.getAttribute('cx'))/12700,int(e.getAttribute('cy'))/12700]

def main():
    raw=SOURCE.read_bytes();(OUT/'source.pptx').write_bytes(raw)
    with zipfile.ZipFile(OUT/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
    pres=D.parseString(files['ppt/presentation.xml']);size=first(pres,'p:sldSz');W=int(size.getAttribute('cx'))/12700;H=int(size.getAttribute('cy'))/12700
    rels={r.getAttribute('Id'):posixpath.normpath('ppt/'+r.getAttribute('Target')) for r in els(D.parseString(files['ppt/_rels/presentation.xml.rels']),'Relationship')}
    slides=[]
    for idx,sid in enumerate(els(pres,'p:sldId'),1):
        part=rels[sid.getAttribute('r:id')];doc=D.parseString(files[part]);tree=first(doc,'p:spTree');nodes=[n for n in tree.childNodes if n.nodeType==1 and els(n,'p:cNvPr')]
        videos=[];groups=[]
        targets={n.getAttribute('spid') for n in els(doc,'p:spTgt')}
        rrkey=posixpath.dirname(part)+'/_rels/'+posixpath.basename(part)+'.rels'
        rr={r.getAttribute('Id'):posixpath.normpath(posixpath.dirname(part)+'/'+r.getAttribute('Target')) for r in els(D.parseString(files[rrkey]),'Relationship')}
        for node in nodes:
            nv=first(node,'p:cNvPr');ident=int(nv.getAttribute('id'));name=nv.getAttribute('name')
            if node.tagName=='p:grpSp':
                children={n.getAttribute('id') for n in els(node,'p:cNvPr')[1:]}
                if not children.intersection(targets):groups.append(dict(id=ident,name=name))
            if els(node,'a:videoFile'):
                videos.append(dict(id=ident,name=name,box=geom(node),media=rr[first(node,'a:videoFile').getAttribute('r:link')],poster=rr[first(node,'a:blip').getAttribute('r:embed')],labels=[],tracks={}))
        for node in nodes:
            if not videos or node.tagName in ['p:pic','p:nvGrpSpPr','p:grpSpPr'] or not els(node,'a:xfrm'):continue
            nv=first(node,'p:cNvPr');name=nv.getAttribute('name');ident=int(nv.getAttribute('id'))
            if len(videos)==1 or name.startswith(('Moving ','Rigid cart','Flexible beam','Clamped and free','Free shear','Flexible cart drive')):
                box=geom(node);center=box[0]+box[2]/2
                video=min(videos,key=lambda v:abs(center-v['box'][0]-v['box'][2]/2))
                video['labels'].append(dict(id=ident,name=name,box=box))
        for anim in els(doc,'p:anim'):
            if not els(anim,'p:spTgt'):continue
            ident=int(first(anim,'p:spTgt').getAttribute('spid'))
            for video in videos:
                if any(v['id']==ident for v in video['labels']):
                    track=[(int(n.getAttribute('tm'))/100000,float(first(n,'p:fltVal').getAttribute('val'))*W) for n in els(anim,'p:tav')]
                    duration=float(first(anim,'p:cTn').getAttribute('dur'))/1000
                    video['tracks'][str(ident)]=dict(duration=duration,points=track)
        slides.append(dict(index=idx,part=part,groups=groups,videos=videos))
    plan=dict(source=str(SOURCE),source_sha256=hashlib.sha256(raw).hexdigest().upper(),width=W,height=H,slides=slides)
    (OUT/'plan.json').write_text(json.dumps(plan,indent=2))
    print('Groups:',sum(len(s['groups']) for s in slides),'videos:',sum(len(s['videos']) for s in slides),'video labels:',sum(len(v['labels']) for s in slides for v in s['videos']))

if __name__=='__main__':main()
