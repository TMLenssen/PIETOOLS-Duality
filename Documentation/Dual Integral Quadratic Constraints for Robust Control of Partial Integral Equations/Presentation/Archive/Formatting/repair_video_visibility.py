from pathlib import Path
import hashlib, json, zipfile
import xml.dom.minidom as M
import xml.etree.ElementTree as E

SOURCE=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx')
B=Path(__file__).parent/'video_fix'
B.mkdir(exist_ok=True)
NS={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main'}

def rectangle(doc,props):
    if props.getElementsByTagName('a:prstGeom') or props.getElementsByTagName('a:custGeom'):return False
    geom=doc.createElementNS(NS['a'],'a:prstGeom');geom.setAttribute('prst','rect')
    geom.appendChild(doc.createElementNS(NS['a'],'a:avLst'))
    following=next((c for c in props.childNodes if c.nodeType==c.ELEMENT_NODE and c.tagName!='a:xfrm'),None)
    if following:props.insertBefore(geom,following)
    else:props.appendChild(geom)
    return True

def repair(source,out,is_deck):
    with zipfile.ZipFile(source) as z:original={n:z.read(n) for n in z.namelist()}
    files=dict(original)
    if is_deck:
        doc=M.parseString(files['ppt/slides/slide2.xml'])
        videos=[]
        for pic in doc.getElementsByTagName('p:pic'):
            if not pic.getElementsByTagName('a:videoFile'):continue
            videos.append(pic.getElementsByTagName('p:cNvPr')[0].getAttribute('name'))
            for ph in list(pic.getElementsByTagName('p:ph')):ph.parentNode.removeChild(ph)
            rectangle(doc,pic.getElementsByTagName('p:spPr')[0])
        assert len(videos)==2,videos
        files['ppt/slides/slide2.xml']=doc.toxml(encoding='utf-8')
    for n in files:
        if n.startswith(('ppt/slideLayouts/slideLayout','ppt/slideMasters/slideMaster')) and n.endswith('.xml'):
            doc=M.parseString(files[n]);changed=False
            for sp in doc.getElementsByTagName('p:sp'):
                if sp.getElementsByTagName('p:ph'):
                    changed=rectangle(doc,sp.getElementsByTagName('p:spPr')[0]) or changed
            if changed:files[n]=doc.toxml(encoding='utf-8')
    if is_deck:
        for n in original:
            if n.startswith(('ppt/media/','ppt/embeddings/','ppt/notesSlides/')) or n.endswith('.rels'):assert files[n]==original[n],n
            if n.startswith('ppt/slides/') and n.endswith('.xml'):
                before=E.fromstring(original[n]);after=E.fromstring(files[n])
                for tag in ['a:t','a:xfrm','p:timing','p:transition']:
                    assert [E.tostring(e) for e in before.findall('.//'+tag,NS)]==[E.tostring(e) for e in after.findall('.//'+tag,NS)],(n,tag)
                if n!='ppt/slides/slide2.xml':assert files[n]==original[n],n
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
        for n,b in files.items():z.writestr(n,b)
    return [n for n in files if files[n]!=original[n]]

(B/'before.pptx').write_bytes(SOURCE.read_bytes())
out=B/SOURCE.name
changed=repair(B/'before.pptx',out,True)
templates=[]
for p in [SOURCE.parent/'TUe - Clean White.potx',Path(__file__).parent/'template_fix'/'TUe - Clean White.potx']:
    if p.exists():
        target=B/('TUe - Clean White.potx' if not templates else 'TUe - Clean White - staging.potx')
        repair(p,target,False);templates.append({'source':str(p.resolve()),'output':str(target.resolve()),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
report={'source':str(SOURCE),'source_sha256':hashlib.sha256((B/'before.pptx').read_bytes()).hexdigest(),'output':str(out.resolve()),'changed':changed,'templates':templates}
(B/'report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
