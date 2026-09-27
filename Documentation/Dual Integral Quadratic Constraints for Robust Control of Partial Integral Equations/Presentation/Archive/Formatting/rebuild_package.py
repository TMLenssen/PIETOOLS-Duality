import zipfile,xml.dom.minidom as M
from pathlib import Path
base=Path(__file__).parent
z=zipfile.ZipFile(base/'source.pptx'); t=zipfile.ZipFile(base/'test.pptx')
files={n:z.read(n) for n in z.namelist()}
for n in ['ppt/presProps.xml','ppt/viewProps.xml','docProps/app.xml','docProps/core.xml']:
    if n in t.namelist(): files[n]=t.read(n)
for n in list(files):
    if n.startswith(('ppt/notesSlides/','ppt/notesMasters/')): del files[n]
    elif n.endswith('.rels'):
        d=M.parseString(files[n])
        for e in list(d.getElementsByTagName('Relationship')):
            if e.getAttribute('Type').rsplit('/',1)[-1] in ['notesSlide','notesMaster']: e.parentNode.removeChild(e)
        files[n]=d.toxml(encoding='utf-8')
d=M.parseString(files['ppt/presentation.xml'])
for tag in ['p:notesMasterIdLst','p:embeddedFontLst','p:custShowLst','p:extLst']:
    for e in list(d.getElementsByTagName(tag)): e.parentNode.removeChild(e)
files['ppt/presentation.xml']=d.toxml(encoding='utf-8')
d=M.parseString(files['[Content_Types].xml'])
for e in list(d.getElementsByTagName('Override')):
    if e.getAttribute('PartName').lstrip('/') not in files: e.parentNode.removeChild(e)
files['[Content_Types].xml']=d.toxml(encoding='utf-8')
with zipfile.ZipFile(base/'rebuild.pptx','w',zipfile.ZIP_DEFLATED) as o:
    for n,data in files.items(): o.writestr(n,data)
