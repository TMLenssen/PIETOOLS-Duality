"""Bake exported PowerPoint labels into figures and efficient H.264 videos."""
from pathlib import Path
from xml.dom import minidom as D
import json,zipfile,subprocess,posixpath,math,io,hashlib
import numpy as np
from PIL import Image
from build_image_overlays import b,els,first
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/simple_deck'
S=1920/720

def crop_export(e):
    im=Image.open(OUT/e['file']).convert('RGBA');bounds=im.getbbox()
    assert bounds,e
    x,y,w,h=e['box'];sx=im.width/w;sy=im.height/h
    left,top,right,bottom=bounds
    return im.crop(bounds),(x+left/sx,y+top/sy,(right-left)/sx,(bottom-top)/sy)

def png(im):
    buff=io.BytesIO();im.save(buff,format='PNG',optimize=True);return buff.getvalue()

def bake_video(v,slide,export,files):
    records=[e for e in export if e['slide']==slide and e['id']==v['id'] and e['kind']!='group']
    layers=[]
    for e in records:
        im,box=crop_export(e);layers.append((im,box,e.get('label')))
    x,y,w,h=v['box'];left,top,right,bottom=x,y,x+w,y+h
    for im,box,label in layers:
        xx,yy,ww,hh=box;low=high=0
        if label is not None:
            points=np.array(v['tracks'][str(label)]['points']);low=points[:,1].min()-points[0,1];high=points[:,1].max()-points[0,1]
        left=min(left,xx+low);right=max(right,xx+ww+high);top=min(top,yy);bottom=max(bottom,yy+hh)
    if w>700:left,top,right,bottom=0,0,720,405
    else:left-=1;top-=1;right+=1;bottom+=1
    width=math.ceil((right-left)*S/2)*2;height=math.ceil((bottom-top)*S/2)*2
    box=[left,top,width/S,height/S]
    basewidth=round(w*S/2)*2;baseheight=round(h*S/2)*2
    inputfile=OUT/f'input-{slide}-{v["id"]}.mp4';inputfile.write_bytes(files[v['media']])
    metadata=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=r_frame_rate,nb_frames','-of','json',str(inputfile)]))['streams'][0]
    numerator,denominator=map(int,metadata['r_frame_rate'].split('/'));fps=numerator/denominator
    output=OUT/f'baked-{slide}-{v["id"]}.mp4'
    decode=subprocess.Popen(['ffmpeg','-v','error','-i',str(inputfile),'-vf',f'scale={basewidth}:{baseheight}:flags=lanczos','-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
    encode=subprocess.Popen(['ffmpeg','-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{width}x{height}','-r',str(fps),'-i','-','-an','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(output)],stdin=subprocess.PIPE)
    prepared=[]
    for im,(xx,yy,ww,hh),label in layers:
        im=im.resize((max(1,round(ww*S)),max(1,round(hh*S))),Image.Resampling.LANCZOS)
        prepared.append((im,round((xx-left)*S),round((yy-top)*S),label))
    n=0;poster=None
    while True:
        raw=decode.stdout.read(basewidth*baseheight*3)
        if not raw:break
        assert len(raw)==basewidth*baseheight*3
        frame=Image.new('RGB',(width,height),'white')
        frame.paste(Image.frombytes('RGB',(basewidth,baseheight),raw),(round((x-left)*S),round((y-top)*S)))
        for layer,lx,ly,label in prepared:
            shift=0
            if label is not None:
                track=v['tracks'][str(label)];points=np.array(track['points']);t=min(n/fps/track['duration'],1)
                shift=round((np.interp(t,points[:,0],points[:,1])-points[0,1])*S)
            frame.paste(layer,(lx+shift,ly),layer)
        if n==0 or w>700:poster=frame.copy()
        if n==round(fps*5):frame.save(OUT/f'preview-{slide}-{v["id"]}.png')
        encode.stdin.write(frame.tobytes());n+=1
    decode.stdout.close();assert decode.wait()==0
    encode.stdin.close();assert encode.wait()==0
    assert n==int(metadata['nb_frames']),(n,metadata)
    poster.save(OUT/f'poster-{slide}-{v["id"]}.png')
    print(f'Baked slide {slide}, {v["name"]}: {width}x{height}, {n} frames',flush=True)
    return output.read_bytes(),png(poster),box,dict(slide=slide,name=v['name'],width=width,height=height,frames=n,fps=fps)

def pic_xml(ident,name,rid,box):
    return f'<p:pic {b.DECL}><p:nvPicPr><p:cNvPr id="{ident}" name="{b.lib.escape(name)}"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr>{b.xf(*box)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>'

def main():
    plan=json.loads((OUT/'plan.json').read_text());exports=json.loads((OUT/'exports.json').read_text(encoding='utf-8-sig'))
    with zipfile.ZipFile(OUT/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
    notes={n:v for n,v in files.items() if n.startswith('ppt/notesSlides/')};before_shapes=sum(v.count(b'<p:sp>') for n,v in files.items() if n.startswith('ppt/slides/') and n.endswith('.xml'))
    stats=[];flattened=0
    for spec in plan['slides']:
        if not spec['groups'] and not spec['videos']:continue
        part=spec['part'];doc=D.parseString(files[part]);tree=first(doc,'p:spTree')
        rrkey=posixpath.dirname(part)+'/_rels/'+posixpath.basename(part)+'.rels';rr=D.parseString(files[rrkey])
        for group in spec['groups']:
            node=next(n for n in tree.childNodes if n.nodeType==1 and els(n,'p:cNvPr') and first(n,'p:cNvPr').getAttribute('id')==str(group['id']))
            e=next(e for e in exports if e['kind']=='group' and e['slide']==spec['index'] and e['id']==group['id'])
            im,box=crop_export(e);path=f'ppt/media/bakedFigure{spec["index"]}_{group["id"]}.png';files[path]=png(im)
            rid=f'rIdBakedFigure{group["id"]}';r=rr.createElement('Relationship');r.setAttribute('Id',rid);r.setAttribute('Type',b.NS['r']+'/image');r.setAttribute('Target','../media/'+posixpath.basename(path));rr.documentElement.appendChild(r)
            new=D.parseString(pic_xml(group['id'],'Baked figure with larger labels',rid,box)).documentElement
            tree.replaceChild(doc.importNode(new,True),node);flattened+=1
        for v in spec['videos']:
            video,poster,box,stat=bake_video(v,spec['index'],exports,files);stats.append(stat)
            files[v['media']]=video;files[v['poster']]=poster
            node=next(n for n in tree.childNodes if n.nodeType==1 and els(n,'p:cNvPr') and first(n,'p:cNvPr').getAttribute('id')==str(v['id']))
            xf=first(node,'a:xfrm');new=D.parseString(f'<root {b.DECL}>'+b.xf(*box)+'</root>').documentElement.firstChild;xf.parentNode.replaceChild(doc.importNode(new,True),xf)
            ids={str(l['id']) for l in v['labels']}
            for n in list(tree.childNodes):
                if n.nodeType==1 and els(n,'p:cNvPr') and first(n,'p:cNvPr').getAttribute('id') in ids:tree.removeChild(n)
            for anim in list(els(doc,'p:anim')):
                if any(n.getAttribute('spid') in ids for n in els(anim,'p:spTgt')):anim.parentNode.removeChild(anim)
        # Discard obsolete picture/math fallback relationships after baking.
        used=set()
        for n in doc.getElementsByTagName('*'):
            for i in range(n.attributes.length):
                attr=n.attributes.item(i)
                if attr.namespaceURI==b.NS['r']:used.add(attr.value)
        for r in list(els(rr,'Relationship')):
            if r.getAttribute('Type').rsplit('/',1)[-1] in ['image','video','media'] and r.getAttribute('Id') not in used:r.parentNode.removeChild(r)
        files[part]=doc.toxml(encoding='utf-8');files[rrkey]=rr.toxml(encoding='utf-8')
    # Remove media no longer referenced anywhere; leave notes and other parts intact.
    referenced=set()
    for name,content in files.items():
        if not name.endswith('.rels'):continue
        base='' if name=='_rels/.rels' else posixpath.dirname(posixpath.dirname(name))
        for r in els(D.parseString(content),'Relationship'):
            if r.getAttribute('TargetMode')!='External':referenced.add(posixpath.normpath(posixpath.join(base,r.getAttribute('Target'))).lstrip('/'))
    removed=[n for n in files if n.startswith('ppt/media/') and n not in referenced]
    for name in removed:del files[name]
    ct=D.parseString(files['[Content_Types].xml'])
    for n in list(els(ct,'Override')):
        if n.getAttribute('PartName').lstrip('/') in removed:n.parentNode.removeChild(n)
    files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
    assert all(files[n]==v for n,v in notes.items())
    output=OUT/Path(plan['source']).name
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
        for name,value in files.items():z.writestr(name,value)
    after_shapes=sum(v.count(b'<p:sp>') for n,v in files.items() if n.startswith('ppt/slides/') and n.endswith('.xml'))
    report=dict(source=plan['source'],source_sha256=plan['source_sha256'],output=str(output),groups_flattened=flattened,videos=stats,shapes_before=before_shapes,shapes_after=after_shapes,notes_preserved=len(notes),unused_media_removed=len(removed),bytes_before=(OUT/'source.pptx').stat().st_size,bytes_after=output.stat().st_size)
    (OUT/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))

if __name__=='__main__':main()
