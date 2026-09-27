from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import hashlib,json,posixpath,unicodedata,re
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest()}))
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
original=files.copy()
def first(n,tag): return n.getElementsByTagName(tag)[0]
d36=D.parseString(files['ppt/slides/slide36.xml'])
rels={r.getAttribute('Id'):posixpath.normpath('ppt/slides/'+r.getAttribute('Target')) for r in D.parseString(files['ppt/slides/_rels/slide36.xml.rels']).getElementsByTagName('Relationship')}
pic=next(n for n in d36.getElementsByTagName('p:pic') if n.getElementsByTagName('a:videoFile'))
media=rels[first(pic,'a:videoFile').getAttribute('r:link')]
poster=rels[first(pic,'a:blip').getAttribute('r:embed')]
assert hashlib.sha256(files[media]).digest()==hashlib.sha256((B.parent/'slide36_product/gaps-60fps.mp4').read_bytes()).digest()
files[media]=(B/'gaps-60fps.mp4').read_bytes(); files[poster]=(B/'frame-0.png').read_bytes()
d=D.parseString(files['ppt/slides/slide37.xml']); count=0
for eq in d.getElementsByTagName('m:oMath'):
    runs=list(eq.getElementsByTagName('m:r')); chars=[]; owners=[]
    for run in runs:
        ts=run.getElementsByTagName('m:t')
        if not ts or not ts[0].firstChild: continue
        for idx,ch in enumerate(ts[0].firstChild.data):
            chars.append(unicodedata.normalize('NFKC',ch)); owners.append((run,idx))
    hit=set()
    for match in re.finditer('ab',''.join(chars)):
        count+=1
        hit.update(owners[match.start():match.end()])
    for run in runs:
        if not any(r is run for r,i in hit): continue
        text=first(run,'m:t').firstChild.data
        for idx,ch in enumerate(text):
            nr=run.cloneNode(True); first(nr,'m:t').firstChild.data=ch
            if (run,idx) in hit:
                pr=first(nr,'a:rPr')
                for fill in list(pr.getElementsByTagName('a:solidFill')): fill.parentNode.removeChild(fill)
                fill=d.createElement('a:solidFill'); color=d.createElement('a:srgbClr'); color.setAttribute('val','C81919'); fill.appendChild(color); pr.insertBefore(fill,pr.firstChild)
            run.parentNode.insertBefore(nr,run)
        run.parentNode.removeChild(run)
for ac in list(d.getElementsByTagName('mc:AlternateContent')):
    if any(c.getAttribute('val')=='C81919' for c in ac.getElementsByTagName('a:srgbClr')):
        for fallback in list(ac.getElementsByTagName('mc:Fallback')): fallback.parentNode.removeChild(fallback)
assert count==4,count
files['ppt/slides/slide37.xml']=d.toxml(encoding='utf-8')
changed=[n for n in files if files[n]!=original[n]]
assert set(changed)=={media,poster,'ppt/slides/slide37.xml'},changed
with ZipFile(B/'final.pptx','w',ZIP_DEFLATED) as z:
    for n,val in files.items(): z.writestr(n,val)
print('Changed the ab video readout and four ab products to theme red #C81919; all other package parts are byte-identical.')
