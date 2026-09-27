import zipfile,xml.dom.minidom as M
from pathlib import Path
b=Path(__file__).parent
z=zipfile.ZipFile(b/'source.pptx')
with zipfile.ZipFile(b/'original_nobg.pptx','w',zipfile.ZIP_DEFLATED) as o:
    for n in z.namelist():
        data=z.read(n)
        if n.endswith('.xml') and n.startswith(('ppt/slides/','ppt/slideLayouts/','ppt/slideMasters/')):
            d=M.parseString(data)
            for e in list(d.getElementsByTagName('p:bg')): e.parentNode.removeChild(e)
            data=d.toxml(encoding='utf-8')
        o.writestr(n,data)
