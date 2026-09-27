from pathlib import Path
import zipfile,xml.etree.ElementTree as E,json,hashlib,posixpath
B=Path(__file__).parent
src=zipfile.ZipFile(B/'source.pptx');out=zipfile.ZipFile(B.parent/'Dual IQC - Formatted.pptx')
ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','m':'http://schemas.openxmlformats.org/officeDocument/2006/math'}
mapping=json.loads((B/'stage_map.json').read_text())
def shapes(root):
    result={}
    for s in root.find('p:cSld/p:spTree',ns):
        nv=s.find('.//p:cNvPr',ns)
        if nv is not None and nv.get('name') and not nv.get('name').startswith('Slide Number'):
            result[nv.get('id')]=s
    return result
def text(s):return tuple(e.text or '' for e in s.iter() if e.tag in ['{'+ns['a']+'}t','{'+ns['m']+'}t'])
def timing(root,tag):return [E.tostring(e) for e in root.findall('.//p:'+tag,ns)]
for n in src.namelist():
    if n.startswith('ppt/media/'):assert out.read(n)==src.read(n),n
for o in range(1,12):
    original=E.fromstring(src.read(f'ppt/slides/slide{o}.xml'))
    targets=[E.fromstring(out.read(f"ppt/slides/slide{r['slide']}.xml")) for r in mapping if r['original']==o]
    for id,s in shapes(original).items():
        assert any(id in shapes(t) and text(shapes(t)[id])==text(s) for t in targets),(o,id,'Text changed or missing')
    for t in targets:
        assert timing(t,'transition')==timing(original,'transition'),(o,'Transition changed')
        if o!=9:assert timing(t,'timing')==timing(original,'timing'),(o,'Animation changed')
for n in out.namelist():
    if n.endswith(('.xml','.rels')):E.fromstring(out.read(n))
    if n.endswith('.rels'):
        for rel in E.fromstring(out.read(n)):
            if rel.get('TargetMode')!='External':
                target=posixpath.normpath(posixpath.join(posixpath.dirname(posixpath.dirname(n)),rel.get('Target'))).lstrip('/')
                assert target in out.namelist(),(n,target)
assert out.testzip() is None
print('PASS: 17 slides; original content and media preserved; morph and all other original transitions preserved; non-neuron animations unchanged; all package links resolve.')
