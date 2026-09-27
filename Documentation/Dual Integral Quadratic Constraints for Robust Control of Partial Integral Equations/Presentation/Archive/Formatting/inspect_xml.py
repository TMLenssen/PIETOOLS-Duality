from pathlib import Path
import zipfile, xml.etree.ElementTree as E, json

SOURCE = Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations.pptx')
NS = {'a':'http://schemas.openxmlformats.org/drawingml/2006/main', 'p':'http://schemas.openxmlformats.org/presentationml/2006/main', 'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
OUT = Path(__file__).parent
z = zipfile.ZipFile(SOURCE)
rows=[]
for i in range(1,12):
    root=E.fromstring(z.read(f'ppt/slides/slide{i}.xml'))
    shapes=[]
    for s in root.find('p:cSld/p:spTree',NS):
        nv=s.find('.//p:cNvPr',NS)
        if nv is None: continue
        x=s.find('.//a:xfrm',NS)
        shapes.append({'type':s.tag.rsplit('}',1)[-1], 'id':nv.get('id'),'name':nv.get('name'),'text':' | '.join(t.text or '' for t in s.findall('.//a:t',NS)), 'pos':None if x is None else E.tostring(x,encoding='unicode'), 'xml':E.tostring(s,encoding='unicode')})
    rows.append({'slide':i,'shapes':shapes,'timing':E.tostring(root.find('p:timing',NS),encoding='unicode') if root.find('p:timing',NS) is not None else ''})
(OUT/'xml_inspection.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False),encoding='utf-8')
for name in z.namelist():
    if name.startswith('ppt/media/') and not name.endswith('/'):
        dest=OUT/'media'/name.rsplit('/',1)[-1]
        dest.parent.mkdir(exist_ok=True)
        dest.write_bytes(z.read(name))
print('Saved slide structure and media.')
