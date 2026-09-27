from pathlib import Path
import zipfile,xml.dom.minidom as M,xml.etree.ElementTree as E
B=Path(__file__).parent
SRC=B.parent/'Dual IQC - Refined.pptx'
OUT=B.parent/'Dual IQC - PIE focus.pptx'
with zipfile.ZipFile(SRC) as z:original={n:z.read(n) for n in z.namelist()}
files=dict(original)
with zipfile.ZipFile(B.parent/'Dual IQC - Structured.pptx') as z:template=M.parseString(z.read('ppt/slides/slide4.xml'))
def els(n,tag):return list(n.getElementsByTagName(tag))
def direct(n,tag):return next((c for c in n.childNodes if c.nodeType==c.ELEMENT_NODE and c.tagName==tag),None)
def shapes(d):
    tree=els(d,'p:spTree')[0]
    return {int(els(c,'p:cNvPr')[0].getAttribute('id')):c for c in tree.childNodes if c.nodeType==c.ELEMENT_NODE and els(c,'p:cNvPr')},tree
def box(s,x,y,w,h,size=None):
    for xf in els(s,'a:xfrm'):
        off=direct(xf,'a:off');ext=direct(xf,'a:ext')
        if off is not None and ext is not None:
            for k,v in {'x':x,'y':y}.items():off.setAttribute(k,str(round(v*12700)))
            for k,v in {'cx':w,'cy':h}.items():ext.setAttribute(k,str(round(v*12700)))
    if size:
        for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
            for r in els(s,tag):r.setAttribute('sz',str(round(size*100)))
list_template=shapes(template)[0][3]
for stage,i in enumerate(range(4,10)):
    part=f'ppt/slides/slide{i}.xml';d=M.parseString(files[part]);S,tree=shapes(d)
    full_list=d.importNode(list_template,True);tree.replaceChild(full_list,S[3]);S[3]=full_list
    box(full_list,36,96,224,262,16)
    for j,p in enumerate(els(full_list,'a:p')):
        active=j==stage
        for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
            for r in els(p,tag):
                r.setAttribute('b','1' if active else '0')
                for color in els(r,'a:srgbClr'):
                    color.setAttribute('val','252529')
                    for old in els(color,'a:alpha'):color.removeChild(old)
                    a=d.createElement('a:alpha');a.setAttribute('val','100000' if active else '30000');color.appendChild(a)
    for sid,x in [(11,299),(13,563)]:box(S[sid],x,94,121,46,20)
    box(S[14],469,110,46,14);box(S[15],453,145,78,24,13)
    if stage==1:
        box(S[17],284,177,400,105,16)
        box(S[18],284,292,400,60,15)
    if stage==2:box(S[21],284,198,400,151,21)
    if stage==3:box(S[22],284,234,400,90,13)
    if stage==4:box(S[23],284,210,400,112,16)
    files[part]=d.toxml(encoding='utf-8')

ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','m':'http://schemas.openxmlformats.org/officeDocument/2006/math'}
changed={f'ppt/slides/slide{i}.xml' for i in range(4,10)}
for n,b in files.items():
    if n not in changed:assert b==original[n],n
    else:
        before=E.fromstring(original[n]);after=E.fromstring(b)
        for tag in ['p:timing','p:transition','m:t']:
            assert [E.tostring(e) for e in before.findall('.//'+tag,ns)]==[E.tostring(e) for e in after.findall('.//'+tag,ns)],(n,tag)
        for stage,s in enumerate(after.findall('p:cSld/p:spTree/p:sp',ns)):
            if s.find('p:nvSpPr/p:cNvPr',ns).get('id')=='3':assert len(s.findall('p:txBody/a:p',ns))==6
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED) as out:
    for n,b in files.items():out.writestr(n,b)
print('Saved '+str(OUT))
print('Verified: complete list on all six PIE slides; only PIE slide formatting changed; equations, media and animation settings preserved.')
