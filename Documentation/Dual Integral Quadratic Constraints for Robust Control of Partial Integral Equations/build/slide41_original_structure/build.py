from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import importlib.util,hashlib,json,posixpath,ast
B=Path(__file__).resolve().parent; ROOT=B.parents[1]
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
with ZipFile(B.parent/'slide41_mirror/source.pptx') as z: old={n:z.read(n) for n in z.namelist()}
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec); spec.loader.exec_module(v); b=v.b
# Reuse only the equation helpers, not the discarded slide design.
helpers=ast.parse((B.parent/'slide41_mirror/build.py').read_text(encoding='utf8'))
from xml.sax.saxutils import escape
for node in helpers.body:
 if isinstance(node,ast.FunctionDef): exec(compile(ast.Module(body=[node],type_ignores=[]),'<helpers>','exec'))
v.M.r=run
part='ppt/slides/slide41.xml'; rp='ppt/slides/_rels/slide41.xml.rels'
d=D.parseString(old[part]); tree=first(d,'p:spTree')
# Preserve the original title, both full-sized diagrams, headings and footer.
remove={206,208,19,21}
for n in list(tree.childNodes):
 if n.nodeType==1 and n.getElementsByTagName('p:cNvPr') and int(first(n,'p:cNvPr').getAttribute('id')) in remove: tree.removeChild(n)
s=v.Slide(); s.i=10000
for dual,cx in [(False,190),(True,530)]:
 prefix='Dual ' if dual else 'Primal '
 if dual:
  for nm,txt,y in [('Pick Theta','Pick Θ',211),('Energy heading','Energy loss through Θ',270)]:
   s.label(prefix+nm,cx,y,txt,13,'C81919',w=308,bold=True)
   s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
 s.equation(prefix+'filter matrix',cx,240,lambda m,q=dual:vec(m,[sig(m,'y',q,True,False),sig(m,'u',q,True,False)])+m.r('=')+mat(m,q)+vec(m,[sig(m,'y',q,False,False),sig(m,'u',q,False,False)]),17,w=310)
 s.equation(prefix+'energy inequality',cx,296,lambda m,q=dual:norm2(m,sig(m,'u',q)+m.r('−')+k(m,q)+sig(m,'y',q))+m.r('≤')+norm2(m,sig(m,'y',q)),16,w=310)
 s.equation(prefix+'controller relation',cx,324,lambda m,q=dual:sig(m,'u',q)+m.r('=')+k(m,q)+sig(m,'y',q),17,w=310)
 s.equation(prefix+'final inequality',cx,351,lambda m,q=dual:m.r('0≤')+norm2(m,sig(m,'y',q)),18,w=310)
for prefix,uri in b.NS.items(): d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:tree.appendChild(d.importNode(frag(xml),True))
for n in list(d.documentElement.childNodes):
 if n.nodeType==1 and n.tagName=='p:timing': d.documentElement.removeChild(n)
# Restore the original diagram resources under unique names in this working deck.
r=D.parseString(old[rp])
for rel in r.getElementsByTagName('Relationship'):
 if rel.getAttribute('TargetMode')=='External':continue
 target=posixpath.normpath('ppt/slides/'+rel.getAttribute('Target'))
 if target.startswith('ppt/media/'):
  new='ppt/media/restore41_'+Path(target).name
  files[new]=old[target]; rel.setAttribute('Target',posixpath.relpath(new,'ppt/slides'))
files[part]=d.toxml(encoding='utf-8'); files[rp]=r.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
print('Restored original diagram sizes, title, headings and sequence; mirrored only the four original equation rows.')
