"""Rebake the flexible-cart labels and temperature symbols without restoring overlays."""
from pathlib import Path
from xml.dom import minidom as D
import json,zipfile,re,hashlib,unicodedata,posixpath
from build_image_overlays import SOURCE,b,els,first
import bake_simple_deck as baker
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/spatial_labels';OUT.mkdir(exist_ok=True)
RED='D61016'

def read(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in z.namelist()}

def save(path,files):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        for n,v in files.items():z.writestr(n,v)

def red(prop):
    for n in list(prop.childNodes):
        if getattr(n,'tagName','') in ['a:solidFill','a:noFill','a:gradFill','a:pattFill']:prop.removeChild(n)
    fill=D.parseString(f'<a:solidFill xmlns:a="{b.NS["a"]}"><a:srgbClr val="{RED}"/></a:solidFill>').documentElement
    before=next((n for n in prop.childNodes if getattr(n,'tagName','') in ['a:latin','a:ea','a:cs','a:sym','a:hlinkClick','a:extLst']),None)
    if before:prop.insertBefore(prop.ownerDocument.importNode(fill,True),before)
    else:prop.appendChild(prop.ownerDocument.importNode(fill,True))

def prepare():
    current=SOURCE.read_bytes();(OUT/'current.pptx').write_bytes(current)
    files=read(ROOT/'build/simple_deck/source.pptx')
    doc=D.parseString(files['ppt/slides/slide2.xml']);count=0
    for sp in els(doc,'p:sp'):
        name=first(sp,'p:cNvPr').getAttribute('name')
        if name in ['Clamped and free boundary','Free shear boundary']:
            for pr in els(sp,'a:rPr'):red(pr)
        elif name in ['Moving tip displacement','Moving spatial coordinate','Flexible beam PDE']:
            for run in list(els(sp,'m:r')):
                if not els(run,'m:t'):continue
                text=first(run,'m:t').firstChild.data
                pieces=[]
                for char in text:
                    color=unicodedata.normalize('NFKC',char) in ['s','L']
                    if pieces and pieces[-1][1]==color:pieces[-1]=(pieces[-1][0]+char,color)
                    else:pieces.append((char,color))
                for value,color in pieces:
                    clone=run.cloneNode(True);first(clone,'m:t').firstChild.data=value
                    if color:
                        pr=els(clone,'a:rPr')
                        if not pr:
                            p=doc.createElement('a:rPr');clone.insertBefore(p,first(clone,'m:t'));pr=[p]
                        red(pr[0]);count+=1
                    run.parentNode.insertBefore(clone,run)
                run.parentNode.removeChild(run)
    files['ppt/slides/slide2.xml']=doc.toxml(encoding='utf-8')
    doc=D.parseString(files['ppt/slides/slide4.xml'])
    for t in els(doc,'m:t'):
        if t.firstChild:t.firstChild.data=re.sub(r'\btemp\b','t',t.firstChild.data)
    files['ppt/slides/slide4.xml']=doc.toxml(encoding='utf-8');save(OUT/'source.pptx',files)
    plan=json.loads((ROOT/'build/simple_deck/plan.json').read_text())
    for s in plan['slides']:
        s['groups']=[g for g in s['groups'] if s['index']==4 and g['id']==7]
        s['videos']=[v for v in s['videos'] if s['index']==2 and v['name']=='cart_flexible']
    plan['slides']=[s for s in plan['slides'] if s['groups'] or s['videos']]
    plan.update(source=str(SOURCE),source_sha256=hashlib.sha256(current).hexdigest().upper())
    (OUT/'plan.json').write_text(json.dumps(plan,indent=2));print('Prepared spatial highlights and temperature symbols;',count,'spatial runs colored.')

def finish():
    plan=json.loads((OUT/'plan.json').read_text());exports=json.loads((OUT/'exports.json').read_text(encoding='utf-8-sig'))
    original=read(OUT/'current.pptx');files=original.copy();assets=read(OUT/'source.pptx');baker.OUT=OUT
    edits=0
    for part,data in list(files.items()):
        if not re.fullmatch(r'ppt/slides/slide\d+\.xml',part):continue
        doc=D.parseString(data);changed=False
        for t in els(doc,'m:t'):
            if t.firstChild and re.search(r'\btemp\b',t.firstChild.data):t.firstChild.data=re.sub(r'\btemp\b','t',t.firstChild.data);edits+=1;changed=True
        if changed:files[part]=doc.toxml(encoding='utf-8')
    for spec in plan['slides']:
        doc=D.parseString(files[spec['part']]);rrkey=posixpath.dirname(spec['part'])+'/_rels/'+posixpath.basename(spec['part'])+'.rels'
        rr={r.getAttribute('Id'):posixpath.normpath(posixpath.dirname(spec['part'])+'/'+r.getAttribute('Target')) for r in els(D.parseString(files[rrkey]),'Relationship')}
        for g in spec['groups']:
            pic=next(p for p in els(doc,'p:pic') if first(p,'p:cNvPr').getAttribute('id')==str(g['id']))
            e=next(e for e in exports if e['kind']=='group' and e['id']==g['id']);im,box=baker.crop_export(e)
            files[rr[first(pic,'a:blip').getAttribute('r:embed')]]=baker.png(im)
            old=first(pic,'a:xfrm');new=D.parseString(f'<root {b.DECL}>'+b.xf(*box)+'</root>').documentElement.firstChild;old.parentNode.replaceChild(doc.importNode(new,True),old)
        for v in spec['videos']:
            movie,poster,box,stat=baker.bake_video(v,spec['index'],exports,assets)
            pic=next(p for p in els(doc,'p:pic') if first(p,'p:cNvPr').getAttribute('name')==v['name'])
            files[rr[first(pic,'a:videoFile').getAttribute('r:link')]]=movie;files[rr[first(pic,'a:blip').getAttribute('r:embed')]]=poster
            old=first(pic,'a:xfrm');new=D.parseString(f'<root {b.DECL}>'+b.xf(*box)+'</root>').documentElement.firstChild;old.parentNode.replaceChild(doc.importNode(new,True),old)
        files[spec['part']]=doc.toxml(encoding='utf-8')
    assert all(files[n]==v for n,v in original.items() if n.startswith('ppt/notes'))
    output=OUT/SOURCE.name;save(output,files)
    report=dict(source=plan['source'],source_sha256=plan['source_sha256'],output=str(output),native_temp_symbols_replaced=edits,highlight_color=RED)
    (OUT/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))

if __name__=='__main__':
    import sys
    prepare() if sys.argv[-1]=='prepare' else finish()
