import zipfile, xml.dom.minidom as M
from pathlib import Path
src=zipfile.ZipFile(Path(__file__).parent/'source.pptx')
for mode in ['no_timing','no_extensions','no_math']:
    out=zipfile.ZipFile(Path(__file__).parent/(mode+'.pptx'),'w',zipfile.ZIP_DEFLATED)
    for n in src.namelist():
        data=src.read(n)
        if n.endswith('.xml'):
            d=M.parseString(data)
            for e in list(d.getElementsByTagName('*')):
                remove=(e.localName in ['timing','transition'])
                if mode in ['no_extensions','no_math']: remove |= e.localName=='extLst'
                if remove and e.parentNode: e.parentNode.removeChild(e)
            if mode=='no_math':
                for e in list(d.getElementsByTagName('mc:AlternateContent')):
                    fb=e.getElementsByTagName('mc:Fallback')
                    if fb:
                        for c in list(fb[0].childNodes): e.parentNode.insertBefore(c.cloneNode(True),e)
                        e.parentNode.removeChild(e)
            data=d.toxml(encoding='utf-8')
        out.writestr(n,data)
    out.close()
