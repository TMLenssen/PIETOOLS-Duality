from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
p=Path('build/slide33_cleanup/latex_math.pptx');out=p.with_name('math_script_test.pptx')
with ZipFile(p) as zin, ZipFile(out,'w') as zout:
 for info in zin.infolist():
  data=zin.read(info.filename)
  if info.filename.startswith('ppt/') and info.filename.endswith('.xml'):
   d=D.parseString(data);changed=False
   for tag in ['m:sub','m:sup']:
    for sub in d.getElementsByTagName(tag):
     for r in sub.getElementsByTagName('m:r'):
      pr=next((e for e in r.childNodes if e.nodeType==e.ELEMENT_NODE and e.tagName=='m:rPr'),None)
      if pr is None:pr=d.createElement('m:rPr');r.insertBefore(pr,r.firstChild)
      if not pr.getElementsByTagName('m:nor'):
       pr.appendChild(d.createElement('m:nor'))
       for rp in r.getElementsByTagName('a:rPr'):
        if rp.hasAttribute('sz'):rp.setAttribute('sz',str(round(int(rp.getAttribute('sz'))*0.7)))
       changed=True
   if changed:data=d.toxml(encoding='UTF-8')
  zout.writestr(info,data)
