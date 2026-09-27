from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
import hashlib,json
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest()}))
with ZipFile(B/'source.pptx') as z:
    (B/'rigid.mp4').write_bytes(z.read('ppt/media/media1.mp4'))
    (B/'flexible.mp4').write_bytes(z.read('ppt/media/media2.mp4'))
    d=D.parseString(z.read('ppt/slides/slide2.xml'))
    (B/'slide2.xml').write_text(d.toprettyxml(),encoding='utf8')
print('Snapshot and both current cart videos extracted.')
