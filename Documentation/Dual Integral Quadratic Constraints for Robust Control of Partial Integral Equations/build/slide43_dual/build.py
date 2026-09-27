from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import ast, importlib.util, json, hashlib
B=Path(__file__).resolve().parent; ROOT=B.parents[1]
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);b=v.b
for node in ast.parse((B.parent/'slide41_mirror/build.py').read_text(encoding='utf8')).body:
 if isinstance(node,ast.FunctionDef):exec(compile(ast.Module(body=[node],type_ignores=[]),'<helper>','exec'))
v.M.r=run
RED='C81919'
d=D.parseString(files['ppt/slides/slide43.xml']);tree=first(d,'p:spTree')
for n in list(tree.childNodes):
 if n.nodeType!=1 or n.tagName in ['p:nvGrpSpPr','p:grpSpPr']:continue
 if first(n,'p:cNvPr').getAttribute('id') not in ['2','3','4']:tree.removeChild(n)
for n in list(d.getElementsByTagName('p:timing')):n.parentNode.removeChild(n)
s=v.Slide();s.i=11000
def matrix(m,transpose=False,dual=False,positive=False,red=False):
 r=lambda t:m.r(t,plain=True)
 kval=m.sup(m.r('K',RED if red else None),m.r('⊤',RED if red else None,True)) if dual or transpose else m.r('K')
 kval=('' if positive else m.r('−',RED if red else None))+kval
 rows=[[r('I'),kval],[r('0'),r('I')]] if transpose else [[r('I'),r('0')],[kval,r('I')]]
 return m.d(m.matrix(rows),'[',']')
def operation(m):return m.r('D',plain=True)+m.d(theta(m,False))
def definition(m):
 r=lambda t:m.r(t,plain=True)
 left=m.d(m.matrix([[r('0'),r('−I')],[r('I'),r('0')]]),'[',']')
 right=m.d(m.matrix([[r('0'),r('I')],[r('−I'),r('0')]]),'[',']')
 return theta(m,True)+m.r('=')+operation(m)+m.r('=')+m.sup(m.d(left+m.sup(theta(m,False),r('⊤'))+right),r('−1'))
s.label('Original filter heading',195,87,'Original filter',14,w=260)
s.label('Dual filter heading',525,87,'Required dual filter',14,w=260)
s.equation('Original filter',195,125,lambda m:theta(m,False)+m.r('=')+matrix(m),23,w=285)
s.equation('Required dual filter',525,125,lambda m:theta(m,True)+m.r('=')+matrix(m,dual=True,red=True),23,w=285)
s.equation('Transpose comparison',360,225,lambda m:m.sup(theta(m,False),m.r('⊤',plain=True))+m.r('=')+matrix(m,transpose=True,red=True)+m.r('≠')+matrix(m,dual=True,red=True)+m.r('=')+theta(m,True),24,w=640)
s.label('Transpose explanation',360,285,'Transposing moves the controller block to the wrong position.',17,w=650)
s.path('Dual operation arrow',[(292,125),(428,125)],color=RED,width=1.8)
s.equation('Dual operation arrow label',360,107,lambda m:m.r('D',RED,True),20,w=75)
s.label('Dual operation steps',360,176,'Transpose · exchange the blocks · invert',15,w=640)
s.outline('Dual operation result box',(60,196,600,78),RED,1.8)
s.equation('Dual operation definition',360,234,definition,24,w=585)
s.equation('Dual operation evaluation',360,323,lambda m:operation(m)+m.r('=')+m.sup(matrix(m,dual=True,positive=True,red=True),m.r('−1',plain=True))+m.r('=')+matrix(m,dual=True,red=True)+m.r('=')+theta(m,True),22,w=630)
for prefix,uri in b.NS.items():d.documentElement.setAttribute('xmlns:'+prefix,uri)
for xml in s.parts:tree.appendChild(d.importNode(frag(xml),True))
files['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
 for n,val in files.items():z.writestr(n,val)
pack=(B.parent/'slide38_theta/package.py').read_text().replace('slide38','slide43').replace('slide 38','slide 43').replace("==2","==8")
(B/'package.py').write_text(pack)
install=(B.parent/'slide41_boxes/install.ps1').read_text().replace('slide 41 red inequality boxes','slide 43 dual operation')
(B/'install.ps1').write_text(install)
print('Built slide 43 with two reveal stages and explicit dual-operation evaluation.')
