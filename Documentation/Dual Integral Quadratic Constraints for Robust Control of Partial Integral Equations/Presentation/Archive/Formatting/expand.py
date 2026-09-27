from pathlib import Path
import zipfile,xml.dom.minidom as M,posixpath,json
b=Path(__file__).parent
z=zipfile.ZipFile(b/'source.pptx')
files={n:z.read(n) for n in z.namelist()}
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
pr=M.parseString(files['ppt/_rels/presentation.xml.rels'])
for e in list(pr.getElementsByTagName('Relationship')):
    if e.getAttribute('Type')==R+'/slide': e.parentNode.removeChild(e)
pres=M.parseString(files['ppt/presentation.xml']); ids=pres.getElementsByTagName('p:sldIdLst')[0]
for e in list(ids.childNodes): ids.removeChild(e)
ct=M.parseString(files['[Content_Types].xml'])
for e in list(ct.getElementsByTagName('Override')):
    if e.getAttribute('PartName').startswith(('/ppt/slides/','/ppt/notesSlides/')): e.parentNode.removeChild(e)
for n in list(files):
    if n.startswith(('ppt/slides/','ppt/notesSlides/')): del files[n]
def content_type(part,typ):
    e=ct.createElement('Override');e.setAttribute('PartName','/'+part);e.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.'+typ+'+xml');ct.documentElement.appendChild(e)
mapping=[]
index=0
for original in range(1,12):
    for stage in range({9:7}.get(original,1)):
        index+=1
        part=f'ppt/slides/slide{index}.xml'
        files[part]=z.read(f'ppt/slides/slide{original}.xml')
        rel=M.parseString(z.read(f'ppt/slides/_rels/slide{original}.xml.rels'))
        for e in rel.getElementsByTagName('Relationship'):
            if e.getAttribute('Type')==R+'/notesSlide':
                oldnote=posixpath.normpath(posixpath.join('ppt/slides',e.getAttribute('Target')))
                newnote=f'ppt/notesSlides/notesSlide{index}.xml'
                files[newnote]=z.read(oldnote)
                content_type(newnote,'notesSlide')
                nr=M.parseString(z.read('ppt/notesSlides/_rels/'+posixpath.basename(oldnote)+'.rels'))
                for ne in nr.getElementsByTagName('Relationship'):
                    if ne.getAttribute('Type')==R+'/slide':ne.setAttribute('Target',f'../slides/slide{index}.xml')
                files[f'ppt/notesSlides/_rels/notesSlide{index}.xml.rels']=nr.toxml(encoding='utf-8')
                e.setAttribute('Target',f'../notesSlides/notesSlide{index}.xml')
        files[f'ppt/slides/_rels/slide{index}.xml.rels']=rel.toxml(encoding='utf-8')
        e=pr.createElement('Relationship');e.setAttribute('Id',f'rIdStage{index}');e.setAttribute('Type',R+'/slide');e.setAttribute('Target',f'slides/slide{index}.xml');pr.documentElement.appendChild(e)
        e=pres.createElement('p:sldId');e.setAttribute('id',str(300+index));e.setAttributeNS(R,'r:id',f'rIdStage{index}');ids.appendChild(e)
        content_type(part,'slide')
        mapping.append({'slide':index,'original':original,'stage':stage})
files['ppt/presentation.xml']=pres.toxml(encoding='utf-8')
files['ppt/_rels/presentation.xml.rels']=pr.toxml(encoding='utf-8')
files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
with zipfile.ZipFile(b/'expanded.pptx','w',zipfile.ZIP_DEFLATED) as out:
    for n,data in files.items():out.writestr(n,data)
(b/'stage_map.json').write_text(json.dumps(mapping,indent=2))
print('Expanded native slides:',index)
