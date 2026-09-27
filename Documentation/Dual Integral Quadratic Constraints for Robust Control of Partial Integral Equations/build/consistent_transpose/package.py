from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import posixpath,json
B=Path(__file__).resolve().parent
def load(p):
 with ZipFile(p) as z:return {n:z.read(n) for n in z.namelist()}
files=load(B/'source.pptx');original=files.copy();edited=load(B/'animated.pptx');meta=json.loads((B/'source.json').read_text())
ct=D.parseString(files['[Content_Types].xml']);ect=D.parseString(edited['[Content_Types].xml']);extensions={n.getAttribute('Extension') for n in ct.getElementsByTagName('Default')}
for r in ect.getElementsByTagName('Default'):
 if r.getAttribute('Extension') not in extensions:ct.documentElement.appendChild(ct.importNode(r,True));extensions.add(r.getAttribute('Extension'))
allowed={'[Content_Types].xml'}
for part in meta['parts']:
 num=Path(part).stem;rp='ppt/slides/_rels/'+Path(part).name+'.rels';allowed.update([part,rp])
 d=D.parseString(edited[part]);old=D.parseString(original[part])
 for tag in ['p:timing']:
  oldnodes=old.getElementsByTagName(tag);newnodes=d.getElementsByTagName(tag)
  if oldnodes:
   assert len(newnodes)==1
   newnodes[0].parentNode.replaceChild(d.importNode(oldnodes[0],True),newnodes[0])
 er=D.parseString(edited[rp]);sr=D.parseString(original[rp]);rels=sr.documentElement;oldrels=list(rels.getElementsByTagName('Relationship'))
 for n in list(rels.childNodes):rels.removeChild(n)
 used={el.getAttribute(a) for el in d.getElementsByTagName('*') for a in ['r:id','r:embed','r:link'] if el.hasAttribute(a)}
 for r in er.getElementsByTagName('Relationship'):
  typ=r.getAttribute('Type').split('/')[-1]
  if typ not in ['slideLayout','notesSlide'] and r.getAttribute('Id') not in used:continue
  nr=r.cloneNode(True)
  if typ in ['slideLayout','notesSlide']:nr.setAttribute('Target',next(x.getAttribute('Target') for x in oldrels if x.getAttribute('Type').endswith('/'+typ)))
  elif r.getAttribute('TargetMode')!='External':
   src=posixpath.normpath('ppt/slides/'+r.getAttribute('Target'));dst='ppt/media/transpose_'+num+'_'+Path(src).name
   files[dst]=edited[src];nr.setAttribute('Target',posixpath.relpath(dst,'ppt/slides'))
   for ov in ect.getElementsByTagName('Override'):
    if ov.getAttribute('PartName')=='/'+src:
     nv=ov.cloneNode(True);nv.setAttribute('PartName','/'+dst);ct.documentElement.appendChild(ct.importNode(nv,True))
  rels.appendChild(sr.importNode(nr,True))
 files[part]=d.toxml(encoding='utf-8');files[rp]=sr.toxml(encoding='utf-8')
files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
assert {n for n in original if files[n]!=original[n]}<=allowed
for part in meta['parts']:
 d=D.parseString(files[part]);old=D.parseString(original[part])
 assert not any(n.firstChild and n.firstChild.data in ['*','∗','⋆'] for n in d.getElementsByTagName('m:t'))
 for tag in ['p:timing','p159:morph']:
  assert [n.toxml() for n in d.getElementsByTagName(tag)]==[n.toxml() for n in old.getElementsByTagName(tag)]
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
print('Only notation/alignment slides and their equation resources changed. All animation timelines and Morph settings preserved exactly.')
