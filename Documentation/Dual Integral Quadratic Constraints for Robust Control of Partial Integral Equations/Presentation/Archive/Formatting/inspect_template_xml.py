from pathlib import Path
from io import BytesIO
import zipfile, xml.etree.ElementTree as E, json
from PIL import Image

source=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx')
out=Path(__file__).parent/'template_fix'
out.mkdir(exist_ok=True)
ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
with zipfile.ZipFile(source) as z:
    (out/'original.pptx').write_bytes(source.read_bytes())
    for part in z.namelist():
        if part.startswith(('ppt/slides/slide','ppt/slideLayouts/slideLayout','ppt/slideMasters/slideMaster')) and part.endswith('.xml'):
            root=E.fromstring(z.read(part))
            print(part,root.attrib,root.find('p:cSld',ns).attrib)
            for s in root.findall('p:cSld/p:spTree/*',ns):
                nv=s.find('.//p:cNvPr',ns)
                if nv is None: continue
                ph=s.find('.//p:ph',ns)
                xf=s.find('.//a:xfrm',ns)
                print(' ',nv.attrib,'ph',None if ph is None else ph.attrib,'box',None if xf is None else [c.attrib for c in xf],'text','|'.join(t.text or '' for t in s.findall('.//a:t',ns))[:130])
    for part in z.namelist():
        if part.startswith('ppt/media/'):
            try:
                im=Image.open(BytesIO(z.read(part)))
                print('IMAGE',part,im.size)
                if im.width/im.height>2 and im.height<600:
                    im.save(out/Path(part).with_suffix('.png').name)
            except Exception: pass
    print('TITLE RELS',z.read('ppt/slides/_rels/slide1.xml.rels').decode())
    print('MASTER',z.read('ppt/slideMasters/slideMaster1.xml').decode())
