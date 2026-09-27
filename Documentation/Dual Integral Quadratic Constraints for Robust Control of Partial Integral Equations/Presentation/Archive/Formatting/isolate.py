import zipfile,xml.dom.minidom as M
from pathlib import Path
b=Path(__file__).parent
z=zipfile.ZipFile(b/'transplant_one.pptx')
for name,tags in {'bg':['p:bg'],'transition':['mc:AlternateContent'],'ext':['p:extLst']}.items():
    d=M.parseString(z.read('ppt/slides/slide1.xml'))
    for tag in tags:
        for e in list(d.getElementsByTagName(tag)): e.parentNode.removeChild(e)
    with zipfile.ZipFile(b/('without_'+name+'.pptx'),'w',zipfile.ZIP_DEFLATED) as o:
        for n in z.namelist(): o.writestr(n,d.toxml(encoding='utf-8') if n=='ppt/slides/slide1.xml' else z.read(n))
