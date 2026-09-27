from pathlib import Path
import zipfile,xml.dom.minidom as M,xml.etree.ElementTree as E,posixpath,json
B=Path(__file__).parent
SRC=B.parent/'Dual IQC - Structured.pptx';OUT=B.parent/'Dual IQC - Refined.pptx'
z=zipfile.ZipFile(SRC);original={n:z.read(n) for n in z.namelist()};files=dict(original)
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
def els(n,tag):return list(n.getElementsByTagName(tag))
def direct(n,tag):return next((c for c in n.childNodes if c.nodeType==c.ELEMENT_NODE and c.tagName==tag),None)
def add(n,tag,attrs={}):
    e=n.ownerDocument.createElement(tag)
    for k,v in attrs.items():e.setAttribute(k,str(v))
    n.appendChild(e);return e
def shapes(d):
    tree=els(d,'p:spTree')[0]
    return {int(els(c,'p:cNvPr')[0].getAttribute('id')):c for c in tree.childNodes if c.nodeType==c.ELEMENT_NODE and els(c,'p:cNvPr')},tree
def box(s,x,y,w,h,size=None):
    for xf in els(s,'a:xfrm'):
        off=direct(xf,'a:off');ext=direct(xf,'a:ext')
        if off is not None and ext is not None:
            for k,v in {'x':x,'y':y}.items():off.setAttribute(k,str(round(v*12700)))
            for k,v in {'cx':w,'cy':h}.items():ext.setAttribute(k,str(round(v*12700)))
    if size:
        for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
            for r in els(s,tag):r.setAttribute('sz',str(round(size*100)))
def text_replace(t,value):
    for c in list(t.childNodes):t.removeChild(c)
    t.appendChild(t.ownerDocument.createTextNode(value))
pres=M.parseString(files['ppt/presentation.xml']);ids=els(pres,'p:sldIdLst')[0]
for c in list(ids.childNodes):ids.removeChild(c)
pr=M.parseString(files['ppt/_rels/presentation.xml.rels'])
for e in els(pr,'Relationship'):
    if e.getAttribute('Type')==R+'/slide':e.parentNode.removeChild(e)
ct=M.parseString(files['[Content_Types].xml'])
for e in els(ct,'Override'):
    if e.getAttribute('PartName').startswith(('/ppt/slides/','/ppt/notesSlides/')):e.parentNode.removeChild(e)
for n in list(files):
    if n.startswith(('ppt/slides/','ppt/notesSlides/')):del files[n]
def ctype(part,typ):add(ct.documentElement,'Override',{'PartName':'/'+part,'ContentType':'application/vnd.openxmlformats-officedocument.presentationml.'+typ+'+xml'})
mapping=[];i=0
for old in range(1,18):
    for stage in range(6 if old==4 else 1):
        i+=1;d=M.parseString(original[f'ppt/slides/slide{old}.xml']);S,tree=shapes(d)
        if old==4:
            for t in els(d,'p:timing'):t.parentNode.removeChild(t)
            keep=[set(),{17,18},{21},{22},{23},set()][stage]
            for sid in {17,18,21,22,23}-keep:tree.removeChild(S[sid])
            paragraphs=els(S[3],'a:p')
            for j,p in enumerate(paragraphs):
                if j!=stage:p.parentNode.removeChild(p)
            box(S[3],36,84,648,52,20)
            for pp in els(S[3],'a:pPr'):
                pp.setAttribute('algn','l')
                for e in els(pp,'a:spcPts'):e.setAttribute('val','0')
            for sid,x in [(11,110),(13,435)]:box(S[sid],x,150,175,48,22)
            box(S[14],330,164,60,18);box(S[15],321,201,78,24,14)
            if stage==1:box(S[17],70,236,255,114,19);box(S[18],355,236,329,114,15)
            if stage==2:box(S[21],90,238,540,127,23)
            if stage==3:box(S[22],36,253,648,70,18)
            if stage==4:box(S[23],50,245,620,105,22)
            if stage in [0,5]:
                for sid,x in [(11,110),(13,435)]:box(S[sid],x,200,175,62,25)
                box(S[14],330,220,60,20);box(S[15],321,266,78,24,14)
        if old==17:
            goal='Goal: Develop a unified framework to analyse and control a broad class of Partial Integral Equations (PIEs).'
            p=els(S[6],'a:p')[0];runs=els(p,'a:r');first=runs[0]
            text_replace(els(first,'a:t')[0],goal)
            for r in runs[1:]:r.parentNode.removeChild(r)
            box(S[6],36,48,648,115,24)
            box(S[7],36,204,648,145,21)
        for s in S.values():
            if 'Slide Number' in els(s,'p:cNvPr')[0].getAttribute('name'):
                for t in els(s,'a:t'):text_replace(t,str(i))
        files[f'ppt/slides/slide{i}.xml']=d.toxml(encoding='utf-8');ctype(f'ppt/slides/slide{i}.xml','slide')
        rel=M.parseString(original[f'ppt/slides/_rels/slide{old}.xml.rels'])
        for e in els(rel,'Relationship'):
            if e.getAttribute('Type')==R+'/notesSlide':
                oldnote=posixpath.normpath(posixpath.join('ppt/slides',e.getAttribute('Target')));newnote=f'ppt/notesSlides/notesSlide{i}.xml'
                files[newnote]=original[oldnote];ctype(newnote,'notesSlide')
                nr=M.parseString(original['ppt/notesSlides/_rels/'+posixpath.basename(oldnote)+'.rels'])
                for ne in els(nr,'Relationship'):
                    if ne.getAttribute('Type')==R+'/slide':ne.setAttribute('Target',f'../slides/slide{i}.xml')
                files[f'ppt/notesSlides/_rels/notesSlide{i}.xml.rels']=nr.toxml(encoding='utf-8')
                e.setAttribute('Target',f'../notesSlides/notesSlide{i}.xml')
        files[f'ppt/slides/_rels/slide{i}.xml.rels']=rel.toxml(encoding='utf-8')
        add(pr.documentElement,'Relationship',{'Id':f'rIdRefined{i}','Type':R+'/slide','Target':f'slides/slide{i}.xml'})
        e=add(ids,'p:sldId',{'id':400+i});e.setAttributeNS(R,'r:id',f'rIdRefined{i}')
        mapping.append({'slide':i,'previous':old,'stage':stage})
files['ppt/presentation.xml']=pres.toxml(encoding='utf-8');files['ppt/_rels/presentation.xml.rels']=pr.toxml(encoding='utf-8');files['[Content_Types].xml']=ct.toxml(encoding='utf-8')

ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','m':'http://schemas.openxmlformats.org/officeDocument/2006/math'}
def content(root):
    values=[]
    for s in root.find('p:cSld/p:spTree',ns):
        nv=s.find('.//p:cNvPr',ns)
        if nv is not None and 'Slide Number' in nv.get('name',''):continue
        values.extend(e.text or '' for e in s.iter() if e.tag in ['{'+ns['a']+'}t','{'+ns['m']+'}t'])
    return values
for old in range(1,18):
    source=E.fromstring(original[f'ppt/slides/slide{old}.xml']);results=[E.fromstring(files[f"ppt/slides/slide{r['slide']}.xml"]) for r in mapping if r['previous']==old]
    if old!=17:
        pool=[v for result in results for v in content(result)]
        assert all(v in pool for v in content(source)),('Content missing',old)
    for result in results:
        for tag in ['p:transition']+([] if old==4 else ['p:timing']):
            assert [E.tostring(e) for e in source.findall('.//'+tag,ns)]==[E.tostring(e) for e in result.findall('.//'+tag,ns)],(old,tag)
for n,b in files.items():
    if n.startswith('ppt/media/'):assert b==original[n]
    if n.endswith(('.xml','.rels')):E.fromstring(b)
    if n.endswith('.rels'):
        for rel in E.fromstring(b):
            if rel.get('TargetMode')!='External':assert posixpath.normpath(posixpath.join(posixpath.dirname(posixpath.dirname(n)),rel.get('Target'))).lstrip('/') in files
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED) as out:
    for n,b in files.items():out.writestr(n,b)
(B/'refined_map.json').write_text(json.dumps(mapping,indent=2))
print('Saved '+str(OUT))
print('PASS: 22 slides; all non-goal content preserved; all media unchanged; original morph and other transitions preserved; only PIE reveals replaced by static pages.')
