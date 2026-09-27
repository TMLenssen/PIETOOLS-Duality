from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import json,hashlib
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
d=D.parseString(files['ppt/slides/slide43.xml']);count=0
for n in d.getElementsByTagName('m:t'):
 if n.firstChild and n.firstChild.data in ['*','∗','⋆']:
  n.firstChild.data='⊤';count+=1
assert count>0
files['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
pack=(B.parent/'slide43_full_expression/package.py').read_text().replace('slide43full_','slide43top_')
# Keep the exact verified four-second animation XML after PowerPoint updates equation fallbacks.
pack=pack.replace("files[part]=d.toxml(encoding='utf-8');", "origdoc=D.parseString(original[part])\noldtiming=d.getElementsByTagName('p:timing')[0]\noldtiming.parentNode.replaceChild(d.importNode(origdoc.getElementsByTagName('p:timing')[0],True),oldtiming)\nfiles[part]=d.toxml(encoding='utf-8');")
(B/'package.py').write_text(pack)
(B/'install.ps1').write_text((B.parent/'slide43_continuous/install.ps1').read_text().replace('slide 43 continuous mirrored derivation','slide 43 transpose notation'))
print(f'Changed {count} adjoint symbols to superscript top; animation and Morph untouched.')
