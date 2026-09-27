from zipfile import ZipFile
from pathlib import Path
from xml.dom import minidom as D
p=Path('build/slide33_cleanup/math_script_test.pptx');out=p.with_name('final_math.pptx')
with ZipFile(p) as zin,ZipFile(out,'w') as zout:
 for info in zin.infolist():
  data=zin.read(info.filename)
  if info.filename.startswith('ppt/') and info.filename.endswith('.xml'):
   d=D.parseString(data);changed=False
   for ctrl in d.getElementsByTagName('m:ctrlPr'):
    for f in ctrl.getElementsByTagName('a:latin'):f.setAttribute('typeface','Cambria Math');changed=True
   if info.filename=='ppt/slides/slide33.xml':
    # Optical centering of the original equation labels with the new font.
    offsets={'27':6,'122':6,'18':6,'113':6,'53':5}
    for c in d.getElementsByTagName('p:cNvPr'):
     sid=c.getAttribute('id')
     if sid in offsets:
      s=c.parentNode.parentNode
      for o in s.getElementsByTagName('a:off'):
       o.setAttribute('y',str(int(o.getAttribute('y'))+12700*offsets[sid]));changed=True
   if changed:data=d.toxml(encoding='UTF-8')
  zout.writestr(info,data)
print('Final math styling uses Latin Modern lettering and compatible structural glyphs.')
