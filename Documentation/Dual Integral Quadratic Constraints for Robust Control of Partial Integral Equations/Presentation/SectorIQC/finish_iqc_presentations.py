"""Update current sector video and insert the two ZF views, preserving old notes."""
from pathlib import Path
from xml.dom import minidom as D
import sys,zipfile,json,hashlib,re,posixpath,shutil
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,Overlay,els,first
from build_video_overlays import namespaces,insert_parts
ZF=Path(__file__).parent/'Simulation/STN_GPe_Zames_Falb'
OUT=ROOT/'build/iqc_final';OUT.mkdir(exist_ok=True)

def main():
    raw=b.SOURCE.read_bytes()
    with zipfile.ZipFile(b.SOURCE) as z:files={n:z.read(n) for n in z.namelist()}
    old_notes={n:v for n,v in files.items() if n.startswith('ppt/notesSlides/')}
    # Existing native legend equations need their Office math extension declared
    # ignorable at the slide root after the deck was saved by PowerPoint.
    for part in ['ppt/slides/slide12.xml','ppt/slides/slide13.xml']:
        md=D.parseString(files[part]);namespaces(md);files[part]=md.toxml(encoding='utf-8')
    sector=next(n for n in files if re.fullmatch(r'ppt/slides/slide\d+\.xml',n) and b'Sector simulation' in files[n])
    doc=D.parseString(files[sector]);namespaces(doc)
    pic=next(p for p in els(doc,'p:pic') if els(p,'a:videoFile'))
    relkey=posixpath.dirname(sector)+'/_rels/'+posixpath.basename(sector)+'.rels'
    rel=D.parseString(files[relkey]);rels={n.getAttribute('Id'):n for n in els(rel,'Relationship')}
    for rid,filename in [(first(pic,'a:videoFile').getAttribute('r:link'),'sector_clean.mp4'),(first(pic,'a:blip').getAttribute('r:embed'),'sector_clean.png')]:
        target=posixpath.normpath('ppt/slides/'+rels[rid].getAttribute('Target'))
        files[target]=(ROOT/'build/deck_label_overlays'/filename).read_bytes()
    tree=first(doc,'p:spTree')
    for n in list(tree.childNodes):
        if any(first(s,'p:cNvPr').getAttribute('name')=='Vertical axis Supply function' or first(s,'p:cNvPr').getAttribute('name').startswith('Response legend ') for s in ([n] if getattr(n,'tagName','')=='p:sp' else els(n,'p:sp'))):tree.removeChild(n)
    start=max(int(n.getAttribute('id')) for n in els(doc,'p:cNvPr'))+1
    o=Overlay(doc,pic,1440,810,start)
    for k,tag in enumerate(['S','G']):
        o.equation('Response legend '+tag,260,495+k*24,lambda m,tag=tag:m.sub(m.r('x'),m.r(tag,plain=True))+m.r(' (STN)' if tag=='S' else ' (GPe)',plain=True),20,width=230)
        o.parts[-1]=o.parts[-1].replace('algn="ctr"','algn="l"').replace('m:val="center"','m:val="left"')
    for k,tag in enumerate(['STN','GPe']):o.text(tag,885,495+k*24,20,width=75,name='Sector supply legend '+tag)
    def integ(m):
        sig=m.sub(m.r('σ'),m.r('i'))+m.d(m.r('t'))
        return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('T')+'</m:sup><m:e>'+sig+m.r(' dt')+'</m:e></m:nary>'
    o.equation('Vertical axis Supply function',695,602.5,integ,24,width=260,angle=-90)
    insert_parts(doc,o.parts);files[sector]=doc.toxml(encoding='utf-8')
    pres=D.parseString(files['ppt/presentation.xml']);lst=first(pres,'p:sldIdLst')
    pr=D.parseString(files['ppt/_rels/presentation.xml.rels'])
    srid=next(n.getAttribute('Id') for n in els(pr,'Relationship') if posixpath.normpath('ppt/'+n.getAttribute('Target'))==sector)
    ids=els(lst,'p:sldId');position=next(i for i,n in enumerate(ids) if n.getAttribute('r:id')==srid)
    before=ids[position+1] if position+1<len(ids) else None
    ct=D.parseString(files['[Content_Types].xml'])
    number=max(int(re.search(r'slide(\d+)\.xml',n)[1]) for n in files if re.fullmatch(r'ppt/slides/slide\d+\.xml',n))
    maxid=max(int(n.getAttribute('id')) for n in ids)
    with zipfile.ZipFile(ZF/'Zames-Falb - Editable.pptx') as z:
        for j in [1,2]:
            num=number+j
            files[f'ppt/slides/slide{num}.xml']=z.read(f'ppt/slides/slide{j}.xml')
            rr=D.parseString(z.read(f'ppt/slides/_rels/slide{j}.xml.rels'))
            for r in list(els(rr,'Relationship')):
                if r.getAttribute('Type').endswith('/notesSlide'):r.parentNode.removeChild(r)
                elif '/media/' in r.getAttribute('Target'):
                    target=posixpath.normpath('ppt/slides/'+r.getAttribute('Target'))
                    files[target]=z.read(target)
            files[f'ppt/slides/_rels/slide{num}.xml.rels']=rr.toxml(encoding='utf-8')
            sid=pres.createElement('p:sldId');sid.setAttribute('id',str(maxid+j));sid.setAttributeNS(b.NS['r'],'r:id',f'rIdZamesFalb{j}')
            if before:lst.insertBefore(sid,before)
            else:lst.appendChild(sid)
            r=pr.createElement('Relationship');r.setAttribute('Id',f'rIdZamesFalb{j}');r.setAttribute('Type',b.NS['r']+'/slide');r.setAttribute('Target',f'slides/slide{num}.xml');pr.documentElement.appendChild(r)
            n=ct.createElement('Override');n.setAttribute('PartName',f'/ppt/slides/slide{num}.xml');n.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');ct.documentElement.appendChild(n)
    for key,d in [('ppt/presentation.xml',pres),('ppt/_rels/presentation.xml.rels',pr),('[Content_Types].xml',ct)]:files[key]=d.toxml(encoding='utf-8')
    for j in [1,2]:b.add_notes(files,number+j,(ZF/'README.md').read_text(encoding='utf-8')+'\nThe plotted integrals are accumulated supplies, not storage functions. Nonnegativity of a storage function alone does not prove dissipativity; the supply inequality is essential. Sector IQCs permit zero storage directly. Dynamic IQCs describe the filtered signals and can require filter storage in a state-space interpretation.')
    assert all(files[n]==v for n,v in old_notes.items()),'Existing notes changed'
    for name,content in files.items():
        if not name.endswith('.rels'):continue
        base='' if name=='_rels/.rels' else posixpath.dirname(posixpath.dirname(name))
        for r in els(D.parseString(content),'Relationship'):
            if r.getAttribute('TargetMode')=='External':continue
            target=posixpath.normpath(posixpath.join(base,r.getAttribute('Target'))).lstrip('/')
            assert target in files,(name,target)
    output=OUT/b.SOURCE.name
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
        for n,v in files.items():z.writestr(n,v)
    sectorout=Path(__file__).parent/'Simulation/STN_GPe'
    for ext in ['mp4','png']:shutil.copyfile(ROOT/f'build/deck_label_overlays/sector_clean.{ext}',sectorout/f'STN-GPe sector simulation.{ext}')
    report=dict(source=str(b.SOURCE),source_sha256=hashlib.sha256(raw).hexdigest().upper(),output=str(output),slides=[position+1,position+2,position+3],existing_notes_preserved=len(old_notes))
    (OUT/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))

if __name__=='__main__':main()
