"""Change only equation objects in the latest user-edited presentation."""
from pathlib import Path
from xml.dom import minidom
import importlib.util,zipfile,json,hashlib

spec=importlib.util.spec_from_file_location('simple',Path(__file__).with_name('simplify_sequence.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
b=s.b
with zipfile.ZipFile(b.SOURCE) as z:files={n:z.read(n) for n in z.namelist()}
before=dict(files);changed=[]
for i in range(1,50):
    name=f'ppt/slides/slide{i}.xml'
    if name not in files:continue
    d=minidom.parseString(files[name]);tree=d.getElementsByTagName('p:spTree')[0]
    candidates=[]
    for child in tree.childNodes:
        if child.nodeType!=1:continue
        props=child.getElementsByTagName('p:cNvPr')
        if any(e.getAttribute('name')=='Original model equations' for e in props):candidates.append(child)
    if not candidates:continue
    assert len(candidates)==1,(i,len(candidates))
    stage=26+len(changed)
    assert stage<=28
    content=b.Slide();content.i=max(int(e.getAttribute('id')) for e in d.getElementsByTagName('p:cNvPr'))+1
    s.original_equations(stage,content)
    wrapper=minidom.parseString(f'<wrap {b.DECL}>'+''.join(content.parts)+'</wrap>')
    for child in wrapper.documentElement.childNodes:
        tree.insertBefore(d.importNode(child,True),candidates[0])
    tree.removeChild(candidates[0])
    for k,v in b.NS.items():d.documentElement.setAttribute('xmlns:'+k,v)
    ignorable=d.documentElement.getAttribute('mc:Ignorable').split()
    if 'a14' not in ignorable:ignorable.append('a14')
    d.documentElement.setAttribute('mc:Ignorable',' '.join(ignorable))
    files[name]=d.toxml(encoding='utf-8');changed.append(i)
assert len(changed)==3,changed
for name,data in before.items():
    if name not in [f'ppt/slides/slide{i}.xml' for i in changed]:assert files[name]==data
with zipfile.ZipFile(b.OUT/'presentation.pptx','w',zipfile.ZIP_DEFLATED) as z:
    for name,data in files.items():z.writestr(name,data)
(b.OUT/'manifest.json').write_text(json.dumps(dict(source=str(b.SOURCE),source_sha256=hashlib.sha256(b.SOURCE.read_bytes()).hexdigest(),slides=changed),indent=2))
print('Updated equation objects only on slides',changed,'; every other package part preserved.')
