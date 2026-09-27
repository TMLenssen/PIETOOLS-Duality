from pathlib import Path
import zipfile,xml.dom.minidom as M
base=Path(__file__).parent
src=zipfile.ZipFile(base/'source.pptx'); template=zipfile.ZipFile(base/'blank.pptx')
files={n:template.read(n) for n in template.namelist()}
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
for n in src.namelist():
    if n.startswith('ppt/media/'): files[n]=src.read(n)
pr=M.parseString(files['ppt/_rels/presentation.xml.rels'])
for e in list(pr.getElementsByTagName('Relationship')):
    if e.getAttribute('Type')==R+'slide': e.parentNode.removeChild(e)
pres=M.parseString(files['ppt/presentation.xml']); sl=pres.getElementsByTagName('p:sldIdLst')[0]
for e in list(sl.childNodes): sl.removeChild(e)
ct=M.parseString(files['[Content_Types].xml'])
existing={e.getAttribute('Extension') for e in ct.getElementsByTagName('Default')}
for e in M.parseString(src.read('[Content_Types].xml')).getElementsByTagName('Default'):
    if e.getAttribute('Extension') not in existing: ct.documentElement.appendChild(e.cloneNode(True))
for i in range(1,12):
    files[f'ppt/slides/slide{i}.xml']=src.read(f'ppt/slides/slide{i}.xml')
    rel=M.parseString(src.read(f'ppt/slides/_rels/slide{i}.xml.rels'))
    for e in list(rel.getElementsByTagName('Relationship')):
        if e.getAttribute('Type')==R+'slideLayout': e.setAttribute('Target','../slideLayouts/slideLayout7.xml')
        if e.getAttribute('Type')==R+'notesSlide': e.parentNode.removeChild(e)
    files[f'ppt/slides/_rels/slide{i}.xml.rels']=rel.toxml(encoding='utf-8')
    e=pr.createElement('Relationship'); e.setAttribute('Id',f'rIdNew{i}'); e.setAttribute('Type',R+'slide'); e.setAttribute('Target',f'slides/slide{i}.xml'); pr.documentElement.appendChild(e)
    e=pres.createElement('p:sldId'); e.setAttribute('id',str(255+i)); e.setAttributeNS(R[:-1],'r:id',f'rIdNew{i}'); sl.appendChild(e)
    if i>1:
        e=ct.createElement('Override'); e.setAttribute('PartName',f'/ppt/slides/slide{i}.xml'); e.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml'); ct.documentElement.appendChild(e)
files['ppt/_rels/presentation.xml.rels']=pr.toxml(encoding='utf-8')
files['ppt/presentation.xml']=pres.toxml(encoding='utf-8')
files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
with zipfile.ZipFile(base/'transplant.pptx','w',zipfile.ZIP_DEFLATED) as out:
    for n,data in files.items(): out.writestr(n,data)
