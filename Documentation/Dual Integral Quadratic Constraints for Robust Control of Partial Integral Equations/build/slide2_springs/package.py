from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import posixpath,json

B=Path(__file__).resolve().parent
def load(p):
    with ZipFile(p) as z: return {n:z.read(n) for n in z.namelist()}
files=load(B/'source.pptx'); original=files.copy(); edited=load(B/'animated.pptx')
part='ppt/slides/slide2.xml'; relpart='ppt/slides/_rels/slide2.xml.rels'
d=D.parseString(edited[part]); er=D.parseString(edited[relpart]); sr=D.parseString(files[relpart])
# The red spatial label must follow the same physical x(t) track as its black version.
highlight=next(h for h in json.loads((B/'highlights.json').read_text()) if h['original']=='Moving spatial coordinate')
track=next(a for a in d.getElementsByTagName('p:anim') if a.getElementsByTagName('p:spTgt')[0].getAttribute('spid')==highlight['original_id'])
clone=track.cloneNode(True)
newid=max(int(n.getAttribute('id')) for n in d.getElementsByTagName('p:cTn'))+1
for n in clone.getElementsByTagName('p:cTn'): n.setAttribute('id',str(newid)); newid+=1
for n in clone.getElementsByTagName('p:spTgt'): n.setAttribute('spid',highlight['new_id'])
track.parentNode.appendChild(clone)
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
        dst='ppt/media/slide2springs_'+Path(src).name
        files[dst]=edited[src]; nr.setAttribute('Target',posixpath.relpath(dst,'ppt/slides'))
        for ov in ect.getElementsByTagName('Override'):
            if ov.getAttribute('PartName')=='/'+src:
                nv=ov.cloneNode(True); nv.setAttribute('PartName','/'+dst); ct.documentElement.appendChild(ct.importNode(nv,True))
    rels.appendChild(sr.importNode(nr,True))
files[part]=d.toxml(encoding='utf-8'); files[relpart]=sr.toxml(encoding='utf-8')
files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
changed=[n for n in original if files[n]!=original[n]]
assert {part,relpart}<=set(changed)<={part,relpart,'[Content_Types].xml'},changed
main=next(n for n in d.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='mainSeq')
assert sum(n.getAttribute('nodeType')=='clickEffect' for n in main.getElementsByTagName('p:cTn'))==3
assert len(d.getElementsByTagName('p:anim'))==8
assert sum(n.getAttribute('cmd')=='playFrom(0.0)' for n in d.getElementsByTagName('p:cmd'))==2
for r in sr.getElementsByTagName('Relationship'):
    if r.getAttribute('TargetMode')!='External':
        assert posixpath.normpath('ppt/slides/'+r.getAttribute('Target')) in files
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
    for n,v in files.items(): z.writestr(n,v)
print('Only slide 2, its relationships, and content types changed. All other original parts are byte-identical; eight motion tracks preserved.')
