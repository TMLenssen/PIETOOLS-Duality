from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import hashlib,json,importlib.util,ast,re
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);b=v.b
for node in ast.parse((B.parent/'slide41_mirror/build.py').read_text(encoding='utf8')).body:
 if isinstance(node,ast.FunctionDef):exec(compile(ast.Module(body=[node],type_ignores=[]),'<helper>','exec'))
v.M.r=run
d=D.parseString(files['ppt/slides/slide48.xml']);tree=first(d,'p:spTree');s=v.Slide();s.i=61000
for tag,x1,x2,c,dashed in [('Control',400,414,'7461A5',False),('STN disturbance',490,504,'D68B22',False),('GPe disturbance',589,603,'D68B22',True)]:
 s.path('Input plot legend '+tag,[(x1,355),(x2,355)],color=c,width=1.5,arrow=False)
 if dashed:
  s.parts[-1]=re.sub(r'<a:prstDash[^>]*/>','',s.parts[-1]).replace('</a:solidFill><a:round/>','</a:solidFill><a:prstDash val="dash"/><a:round/>')
s.equation('Input plot legend control text',449,355,lambda m:m.r('u')+m.r(': control',plain=True),9.5,w=64,color='7461A5')
for sig,cx in [('S',547),('G',646)]:
 s.equation('Input plot legend disturbance '+sig,cx,355,lambda m,q=sig:m.sub(m.r('d'),m.r(q,plain=True))+m.r(': disturbance',plain=True),9.5,w=84,color='D68B22')
for prefix,uri in b.NS.items():d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:tree.appendChild(d.importNode(frag(xml),True))
# A single PNG frame of slide 14's hand GIF, retaining its crop and position.
d14=D.parseString(files['ppt/slides/slide14.xml']);hand=next(n for n in d14.getElementsByTagName('p:pic') if first(n,'p:cNvPr').getAttribute('id')=='4')
hand=d.importNode(hand,True);nv=first(hand,'p:cNvPr');nv.setAttribute('id','62000');nv.setAttribute('name','Still hand from slide 14')
for ext in list(nv.getElementsByTagName('a:extLst')):nv.removeChild(ext)
first(hand,'a:blip').setAttribute('r:embed','rIdHandStill48');tree.appendChild(hand)
rp='ppt/slides/_rels/slide48.xml.rels';rels=D.parseString(files[rp]);r=rels.createElement('Relationship');r.setAttribute('Id','rIdHandStill48');r.setAttribute('Type','http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');r.setAttribute('Target','../media/slide48_hand_still.png');rels.documentElement.appendChild(r)
files['ppt/media/slide48_hand_still.png']=(B/'hand-still.png').read_bytes()
files[rp]=rels.toxml(encoding='utf-8');files['ppt/slides/slide48.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
pack=(B.parent/'slide43_top/package.py').read_text().replace('slide43','slide48').replace('slide 43','slide 48').replace("assert len(d.getElementsByTagName('m:m'))==11",'')
(B/'package.py').write_text(pack)
(B/'render.ps1').write_text((B.parent/'slide43_top/render.ps1').read_text())
(B/'install.ps1').write_text((B.parent/'slide47_contributions/install.ps1').read_text().replace('slide 47 contributions','slide 48 input legend and hand still'))
print('Added a three-signal legend below the input plot and a still PNG of the slide 14 hand.')
