from pathlib import Path
import zipfile,xml.dom.minidom as M,xml.etree.ElementTree as E

B=Path(__file__).parent
SOURCE=B.parent/'Dual IQC - PIE focus.pptx'
OUT=B.parent/'Dual IQC - TUe accents.pptx'
# Dominant red sampled from the existing TU/e logo; preserve the established palette.
RED='C81919'
with zipfile.ZipFile(SOURCE) as z:original={n:z.read(n) for n in z.namelist()}
files=dict(original)
def els(n,tag):return list(n.getElementsByTagName(tag))
def direct(n,tag):return next((c for c in n.childNodes if c.nodeType==c.ELEMENT_NODE and c.tagName==tag),None)
def shapes(d):
    tree=els(d,'p:spTree')[0]
    return {int(els(c,'p:cNvPr')[0].getAttribute('id')):c for c in tree.childNodes if c.nodeType==c.ELEMENT_NODE and els(c,'p:cNvPr')}
def red(n):
    for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
        for r in els(n,tag):
            for c in els(r,'a:srgbClr'):
                c.setAttribute('val',RED)
def span(s,phrase):
    runs=[r for r in els(s,'a:r') if direct(r,'a:t') is not None]
    values=[''.join(c.data for c in direct(r,'a:t').childNodes if c.nodeType==c.TEXT_NODE) for r in runs]
    full=''.join(values);start=full.index(phrase);end=start+len(phrase);offset=0
    for r,text in zip(runs,values):
        left=max(start-offset,0);right=min(end-offset,len(text))
        if left<right:
            for chunk,accent in [(text[:left],False),(text[left:right],True),(text[right:],False)]:
                if not chunk:continue
                copy=r.cloneNode(True);t=direct(copy,'a:t')
                for c in list(t.childNodes):t.removeChild(c)
                t.appendChild(t.ownerDocument.createTextNode(chunk))
                if chunk[0].isspace() or chunk[-1].isspace():t.setAttribute('xml:space','preserve')
                if accent:red(copy)
                r.parentNode.insertBefore(copy,r)
            r.parentNode.removeChild(r)
        offset+=len(text)

selected=[1,2,3,*range(4,10),10,17,22]
for i in selected:
    part=f'ppt/slides/slide{i}.xml';d=M.parseString(files[part]);S=shapes(d)
    if i==1:red(S[7])
    if i==2:
        span(S[2],'Rigid body representation');span(S[7],'Flexible body representation')
    if i==3:
        for sid in [16,18,23]:red(S[sid])
    if 4<=i<=9:
        red(els(S[3],'a:p')[i-4]);red(S[15])
    if i==10:red(S[22])
    if i==17:red(S[81])
    if i==22:span(S[6],'unified framework')
    files[part]=d.toxml(encoding='utf-8')

ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','m':'http://schemas.openxmlformats.org/officeDocument/2006/math'}
for n,b in files.items():
    if n.startswith('ppt/slides/slide') and n.endswith('.xml'):
        before=E.fromstring(original[n]);after=E.fromstring(b)
        for tag in ['a:t','m:t']:
            assert ''.join(e.text or '' for e in before.findall('.//'+tag,ns))==''.join(e.text or '' for e in after.findall('.//'+tag,ns)),(n,tag)
        for tag in ['a:xfrm','p:timing','p:transition']:
            assert [E.tostring(e) for e in before.findall('.//'+tag,ns)]==[E.tostring(e) for e in after.findall('.//'+tag,ns)],(n,tag)
    else:assert b==original[n],n
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED) as out:
    for n,b in files.items():out.writestr(n,b)
print('Saved '+str(OUT))
print('Verified: text, equations, layout, media, slide order, transitions and animations preserved. Only selected text colours changed.')
