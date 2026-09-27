from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
from collections import Counter
src=Path('build/slide33_cleanup/cleaned.pptx');out=src.with_name('latex_math.pptx')
font='Latin Modern Math';counts=Counter()
with ZipFile(src) as zin,ZipFile(out,'w') as zout:
 for info in zin.infolist():
  data=zin.read(info.filename)
  if info.filename.endswith('.xml') and info.filename.startswith('ppt/'):
   d=D.parseString(data);changed=False
   for e in d.getElementsByTagName('*'):
    if e.hasAttribute('typeface') and e.getAttribute('typeface')=='Cambria Math':
     e.setAttribute('typeface',font);changed=True;counts['font_references']+=1
   for math in d.getElementsByTagName('m:oMath'):
    for r in math.getElementsByTagName('a:rPr'):
     fs=r.getElementsByTagName('a:latin')
     if fs:fs[0].setAttribute('typeface',font)
     else:
      f=d.createElement('a:latin');f.setAttribute('typeface',font);r.appendChild(f)
     changed=True
    counts['equations']+=1
   # Default font within all existing equation-bearing text boxes.
   for s in d.getElementsByTagName('p:sp'):
    if not s.getElementsByTagName('m:oMath'):continue
    for name in ['a:defRPr','a:endParaRPr']:
     for r in s.getElementsByTagName(name):
      fs=r.getElementsByTagName('a:latin')
      if fs:fs[0].setAttribute('typeface',font)
      else:
       f=d.createElement('a:latin');f.setAttribute('typeface',font);r.appendChild(f)
      changed=True
   if changed:
    data=d.toxml(encoding='UTF-8');counts['changed_xml_parts']+=1
  zout.writestr(info,data)
print(dict(counts))


