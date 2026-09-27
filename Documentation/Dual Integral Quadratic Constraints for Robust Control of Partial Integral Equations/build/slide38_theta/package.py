from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import posixpath

B=Path(__file__).resolve().parent
def load(p):
    with ZipFile(p) as z: return {n:z.read(n) for n in z.namelist()}
files=load(B/'source.pptx'); original=files.copy(); edited=load(B/'animated.pptx')
part='ppt/slides/slide38.xml'; relpart='ppt/slides/_rels/slide38.xml.rels'
d=D.parseString(edited[part]); er=D.parseString(edited[relpart]); sr=D.parseString(files[relpart])
rels=sr.documentElement
oldrels=list(rels.getElementsByTagName('Relationship'))
for n in list(rels.childNodes): rels.removeChild(n)
used={el.getAttribute(a) for el in d.getElementsByTagName('*') for a in ['r:id','r:embed','r:link'] if el.hasAttribute(a)}
ct=D.parseString(files['[Content_Types].xml']); ect=D.parseString(edited['[Content_Types].xml'])
extensions={n.getAttribute('Extension') for n in ct.getElementsByTagName('Default')}
for r in ect.getElementsByTagName('Default'):
    if r.getAttribute('Extension') not in extensions:
        ct.documentElement.appendChild(ct.importNode(r,True)); extensions.add(r.getAttribute('Extension'))
for r in er.getElementsByTagName('Relationship'):
    typ=r.getAttribute('Type').split('/')[-1]
    if typ not in ['slideLayout','notesSlide'] and r.getAttribute('Id') not in used: continue
    nr=r.cloneNode(True)
    if typ in ['slideLayout','notesSlide']:
        nr.setAttribute('Target',next(x.getAttribute('Target') for x in oldrels if x.getAttribute('Type').endswith('/'+typ)))
    elif r.getAttribute('TargetMode')!='External':
        src=posixpath.normpath('ppt/slides/'+r.getAttribute('Target'))
        dst='ppt/media/slide38theta_'+Path(src).name
        files[dst]=edited[src]; nr.setAttribute('Target',posixpath.relpath(dst,'ppt/slides'))
        for ov in ect.getElementsByTagName('Override'):
            if ov.getAttribute('PartName')=='/'+src:
                nv=ov.cloneNode(True); nv.setAttribute('PartName','/'+dst); ct.documentElement.appendChild(ct.importNode(nv,True))
    rels.appendChild(sr.importNode(nr,True))
files[part]=d.toxml(encoding='utf-8'); files[relpart]=sr.toxml(encoding='utf-8')
files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
changed=[n for n in original if files[n]!=original[n]]
assert {part,relpart}<=set(changed)<={part,relpart,'[Content_Types].xml'},changed
assert len(d.getElementsByTagName('m:m'))==2
assert '\\begin' not in d.toxml()
for r in sr.getElementsByTagName('Relationship'):
    if r.getAttribute('TargetMode')!='External':
        assert posixpath.normpath('ppt/slides/'+r.getAttribute('Target')) in files
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
    for n,v in files.items(): z.writestr(n,v)
print('Only slide 38 and its supporting package entries changed; all other original parts are byte-identical.')
