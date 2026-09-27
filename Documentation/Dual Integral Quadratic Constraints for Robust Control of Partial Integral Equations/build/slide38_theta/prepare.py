from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
import hashlib,json
B=Path(__file__).resolve().parent
source=next(Path('C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation').glob('Dual*.pptx'))
raw=source.read_bytes(); (B/'source.pptx').write_bytes(raw)
with ZipFile(B/'source.pptx') as z: count=len(D.parseString(z.read('ppt/presentation.xml')).getElementsByTagName('p:sldId'))
(B/'source.json').write_text(json.dumps({'source':str(source),'hash':hashlib.sha256(raw).hexdigest(),'slides':count}))
print('Snapshotted current deck:',count,'slides.')
