from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from xml.dom import minidom as D
import json,hashlib,re
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes();(B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z:files={n:z.read(n) for n in z.namelist()}
original=files.copy()
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':len(D.parseString(files['ppt/presentation.xml']).getElementsByTagName('p:sldId'))}))
def first(n,tag):return n.getElementsByTagName(tag)[0]
def child(n,tag):return next(x for x in n.childNodes if getattr(x,'tagName','')==tag)
d=D.parseString(files['ppt/slides/slide43.xml']);timing=first(d,'p:timing');tree=first(d,'p:spTree')
shapes={first(n,'p:cNvPr').getAttribute('name'):n for n in tree.childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr')}
ids={name:first(n,'p:cNvPr').getAttribute('id') for name,n in shapes.items()}
main=next(n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='mainSeq')
groups=child(main,'p:childTnLst');groupnodes=[n for n in groups.childNodes if n.nodeType==1]
assert len(groupnodes) in [2,7], f'Unexpected animation structure: {len(groupnodes)}'
def inner(g):return child(first(child(first(g,'p:cTn'),'p:childTnLst'),'p:cTn'),'p:childTnLst')
target=inner(groupnodes[1])
diagonal={ids['Full D 1 cell0'],ids['Full D 1 cell3']}
offdiagonal={ids['Full D 1 cell1']:(-52,26),ids['Full D 1 cell2']:(52,-26)}
effectnodes=[n.parentNode for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType') in ['clickEffect','withEffect','afterEffect']]
for e in effectnodes:
 motions=e.getElementsByTagName('p:animMotion')
 if not motions:continue
 motion=motions[0];target=first(motion,'p:spTgt').getAttribute('spid')
 if target in diagonal:e.parentNode.removeChild(e)
 elif target in offdiagonal:
  dx,dy=offdiagonal[target]
  motion.setAttribute('path',f'M 0 0 L {dx/720:.9f} {dy/405:.9f} E')
  if motion.hasAttribute('ptsTypes'):motion.removeAttribute('ptsTypes')
if 'Full D 2 caption' in shapes:
 texts=shapes['Full D 2 caption'].getElementsByTagName('a:t')
 texts[0].firstChild.data='Transpose: mirror across the main diagonal'
 for n in texts[1:]:
  if n.firstChild:n.firstChild.data=''
# The second click shows the complete expression, then plays every operation in order.
target=inner(groupnodes[1]);offsets={1:1600,2:3200,3:5100,4:7000,5:8900}
names={ident:name for name,ident in ids.items()}
for g in groupnodes[1:]:
 for e in list(inner(g).childNodes):
  if e.nodeType!=1:continue
  ct=first(e,'p:cTn');spid=first(e,'p:spTgt').getAttribute('spid');name=names[spid]
  match=re.match(r'Full D (\d+) ',name)
  if match:
   stage=int(match.group(1));enter=ct.getAttribute('presetClass')=='entr'
   operation=stage if enter else stage+1
   if operation:
    cond=first(child(ct,'p:stCondLst'),'p:cond')
    cond.setAttribute('delay',str(int(cond.getAttribute('delay'))+offsets[operation]))
   ct.setAttribute('nodeType','withEffect')
  if g is not groupnodes[1]:target.appendChild(e)
 if g is not groupnodes[1]:groups.removeChild(g)
# Fit the complete second-click playback into exactly four seconds.
speed_factor=4000/9650
for n in target.getElementsByTagName('p:cTn'):
 if n.hasAttribute('dur') and n.getAttribute('dur').isdigit():
  duration=int(n.getAttribute('dur'))
  if duration>1:n.setAttribute('dur',str(max(1,round(duration*speed_factor))))
for n in target.getElementsByTagName('p:cond'):
 if n.getAttribute('delay').isdigit():n.setAttribute('delay',str(round(int(n.getAttribute('delay'))*speed_factor)))
assert len([n for n in timing.getElementsByTagName('p:cTn') if n.getAttribute('nodeType')=='clickEffect'])==2
for n in timing.getElementsByTagName('p:animMotion'):
 targetid=first(n,'p:spTgt').getAttribute('spid')
 assert targetid not in diagonal
 if targetid in offdiagonal:assert ' C ' not in n.getAttribute('path')
files['ppt/slides/slide43.xml']=d.toxml(encoding='utf-8')
assert [n for n in files if files[n]!=original[n]]==['ppt/slides/slide43.xml']
assert first(d,'p159:morph').toxml()==first(D.parseString(original['ppt/slides/slide43.xml']),'p159:morph').toxml()
def write(path,data):
 with ZipFile(path,'w',ZIP_DEFLATED) as z:
  for n,val in data.items():z.writestr(n,val)
write(B/'final.pptx',files)
preview=files.copy();p=D.parseString(files['ppt/presentation.xml'])
for i,n in enumerate(list(p.getElementsByTagName('p:sldId')),1):
 if i!=43:n.parentNode.removeChild(n)
preview['ppt/presentation.xml']=p.toxml(encoding='utf-8');write(B/'movie.pptx',preview)
(B/'install.ps1').write_text((B.parent/'slide43_full_expression/install.ps1').read_text().replace('slide 43 full dual expression','slide 43 continuous mirrored derivation'))
print('One continuous derivation playback after revealing the full expression; diagonal entries fixed during transpose.')
