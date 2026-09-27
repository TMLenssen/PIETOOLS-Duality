from pathlib import Path
import zipfile,xml.dom.minidom as M,xml.etree.ElementTree as E,io
from PIL import Image,ImageChops

B=Path(__file__).parent
SOURCE=B.parent/'Dual IQC - Formatted.pptx'
OUT=B.parent/'Dual IQC - Structured.pptx'
z=zipfile.ZipFile(SOURCE);files={n:z.read(n) for n in z.namelist()}
def els(n,tag):return list(n.getElementsByTagName(tag))
def direct(n,tag):return next((c for c in n.childNodes if c.nodeType==c.ELEMENT_NODE and c.tagName==tag),None)
def add(n,tag,attrs):
    e=n.ownerDocument.createElement(tag)
    for k,v in attrs.items():e.setAttribute(k,str(v))
    n.appendChild(e);return e
def box(s,x,y,w,h):
    for xf in els(s,'a:xfrm'):
        off=direct(xf,'a:off');ext=direct(xf,'a:ext')
        if off is not None and ext is not None:
            for k,v in {'x':x,'y':y}.items():off.setAttribute(k,str(round(v*12700)))
            for k,v in {'cx':w,'cy':h}.items():ext.setAttribute(k,str(round(v*12700)))
def typography(s,size=None,line=112000,after=0,align='l'):
    if size:
        for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
            for r in els(s,tag):r.setAttribute('sz',str(round(size*100)))
    for p in els(s,'a:pPr'):
        p.setAttribute('algn',align);p.setAttribute('defTabSz','1')
        for tag in ['a:lnSpc','a:spcBef','a:spcAft','a:tabLst']:
            e=direct(p,tag)
            if e:p.removeChild(e)
        a=p.ownerDocument.createElement('a:lnSpc');add(a,'a:spcPct',{'val':line});p.insertBefore(a,p.firstChild)
        b=p.ownerDocument.createElement('a:spcAft');add(b,'a:spcPts',{'val':round(after*100)});p.insertBefore(b,a.nextSibling)
def crop_blank(s,media,area):
    im=Image.open(io.BytesIO(z.read('ppt/media/'+media))).convert('RGB')
    diff=ImageChops.difference(im,Image.new('RGB',im.size,'white')).convert('L').point(lambda x:255 if x>12 else 0)
    l,t,r,b=diff.getbbox();pad=24;l=max(0,l-pad);t=max(0,t-pad);r=min(im.width,r+pad);b=min(im.height,b+pad)
    bf=els(s,'p:blipFill')[0];old=direct(bf,'a:srcRect')
    if old:bf.removeChild(old)
    rect=bf.ownerDocument.createElement('a:srcRect')
    for k,v in {'l':l/im.width,'t':t/im.height,'r':1-r/im.width,'b':1-b/im.height}.items():rect.setAttribute(k,str(round(v*100000)))
    bf.insertBefore(rect,direct(bf,'a:stretch'))
    x,y,w,h=area;scale=min(w/(r-l),h/(b-t));nw=(r-l)*scale;nh=(b-t)*scale
    box(s,x+(w-nw)/2,y+(h-nh)/2,nw,nh)

for index in [1,4,5,12,17]:
    part=f'ppt/slides/slide{index}.xml';d=M.parseString(files[part]);tree=els(d,'p:spTree')[0]
    shapes={}
    for c in tree.childNodes:
        if c.nodeType==c.ELEMENT_NODE and els(c,'p:cNvPr'):
            nv=els(c,'p:cNvPr')[0];shapes[int(nv.getAttribute('id'))]=c
    if index==1:
        box(shapes[6],36,35,648,86);typography(shapes[6],28,line=112000)
        box(shapes[7],36,131,648,28);typography(shapes[7],16)
        box(shapes[8],36,234,258,59);typography(shapes[8],13,line=120000)
        box(shapes[9],36,302,258,29);typography(shapes[9],11)
        figure=next(s for s in shapes.values() if els(s,'p:cNvPr')[0].getAttribute('name')=='Original title response figure')
        crop_blank(figure,'image3.png',(327,185,357,163))
    if index==5:
        # Keep the exact leading tab; normalize its tab stop so it no longer indents the first line.
        box(shapes[22],452,263,232,61);typography(shapes[22],17,line=115000)
        for bp in els(shapes[22],'a:bodyPr'):bp.setAttribute('anchor','ctr')
    if index==4:
        box(shapes[3],36,96,223,256);typography(shapes[3],16,line=113000,after=13)
        # Reserve a stable right-hand column for every existing animation state.
        for sid,x in [(11,299),(13,563)]:box(shapes[sid],x,94,121,46)
        box(shapes[14],469,110,46,14);box(shapes[15],453,145,78,24)
        for sid,area,size in [
            (17,(286,191,176,119),14),
            (18,(474,182,210,139),13),
            (21,(284,185,400,156),21),
            (22,(284,222,400,90),13),
            (23,(284,207,400,112),16)]:
            box(shapes[sid],*area)
            for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
                for r in els(shapes[sid],tag):r.setAttribute('sz',str(round(size*100)))
    if index==12:
        box(shapes[58],157,19,406,203)
        box(shapes[44],102,221,516,108)
        for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
            for r in els(shapes[44],tag):r.setAttribute('sz','1800')
        box(shapes[81],62,331,596,22);typography(shapes[81],13,line=110000,align='ctr')
    if index==17:
        box(shapes[6],54,48,612,115);typography(shapes[6],25,line=120000)
        box(shapes[7],54,204,612,145);typography(shapes[7],21,line=120000,after=19)
        # Explicitly clear inherited paragraph spacing before each item.
        for pp in els(shapes[7],'a:pPr'):
            a=pp.ownerDocument.createElement('a:spcBef');add(a,'a:spcPts',{'val':0});pp.insertBefore(a,direct(pp,'a:spcAft'))
    files[part]=d.toxml(encoding='utf-8')

# Compare against the approved copy: slide content, order, animation XML, and media are unchanged.
ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','m':'http://schemas.openxmlformats.org/officeDocument/2006/math'}
for n,b in files.items():
    if n.startswith('ppt/slides/slide') and n.endswith('.xml'):
        original=E.fromstring(z.read(n));updated=E.fromstring(b)
        for tag in ['a:t','m:t','p:timing','p:transition']:
            assert [E.tostring(e) for e in original.findall('.//'+tag,ns)]==[E.tostring(e) for e in updated.findall('.//'+tag,ns)],(n,tag)
    elif n.startswith('ppt/media/') or n=='ppt/presentation.xml':assert b==z.read(n),n
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED) as out:
    for n,b in files.items():out.writestr(n,b)
print('Saved '+str(OUT))
print('PASS: all text, equations, media, slide order and animations match the approved copy.')

# Static previews of the PIE animation states, used only for layout inspection.
for stage,keep in enumerate([{17,18},{21},{22},{23}],1):
    d=M.parseString(files['ppt/slides/slide4.xml']);tree=els(d,'p:spTree')[0]
    for node in els(d,'p:timing'):node.parentNode.removeChild(node)
    for c in list(tree.childNodes):
        if c.nodeType==c.ELEMENT_NODE and els(c,'p:cNvPr'):
            sid=int(els(c,'p:cNvPr')[0].getAttribute('id'))
            if sid in {17,18,21,22,23} and sid not in keep:tree.removeChild(c)
    with zipfile.ZipFile(B/f'pie-check-{stage}.pptx','w',zipfile.ZIP_DEFLATED) as out:
        for n,b in files.items():out.writestr(n,d.toxml(encoding='utf-8') if n=='ppt/slides/slide4.xml' else b)
