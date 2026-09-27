"""Repair the actual master/layouts without round-tripping equations or media."""
from pathlib import Path
from copy import deepcopy
from io import BytesIO
from xml.sax.saxutils import escape
import hashlib, json, posixpath, re, zipfile
import xml.dom.minidom as M
import xml.etree.ElementTree as E
from PIL import Image

B = Path(__file__).parent / 'template_fix'
SOURCE = B / 'original.pptx'
OUT = B / 'Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx'
TEMPLATE = B / 'TUe - Clean White.potx'
NS = {'p':'http://schemas.openxmlformats.org/presentationml/2006/main', 'a':'http://schemas.openxmlformats.org/drawingml/2006/main', 'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
DECL = ' '.join(f'xmlns:{k}="{v}"' for k,v in NS.items())
REL = 'http://schemas.openxmlformats.org/package/2006/relationships'
TYPE = NS['r'] + '/'
BG = '<p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
GROUP = '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
with zipfile.ZipFile(SOURCE) as z:
    original = {n:z.read(n) for n in z.namelist()}
files = dict(original)

def xml(s): return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + s).encode()
def emu(x): return str(round(x * 12700))
def xfrm(box):
    x,y,w,h=map(emu,box)
    return f'<a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{w}" cy="{h}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
def runprops(size=18,color='252529',bold=False):
    return f'<a:defRPr sz="{round(size*100)}" b="{int(bold)}"><a:solidFill><a:srgbClr val="{color}"/></a:solidFill><a:latin typeface="Aptos"/><a:ea typeface="Aptos"/><a:cs typeface="Aptos"/></a:defRPr>'
def pprops(size=18,color='252529',bold=False,align='l',level=0):
    return f'<a:pPr marL="{emu(level*16)}" indent="0" algn="{align}"><a:lnSpc><a:spcPct val="112000"/></a:lnSpc><a:spcAft><a:spcPts val="{1000 if size>=17 and not bold else 0}"/></a:spcAft><a:buNone/>{runprops(size,color,bold)}</a:pPr>'
def shape(sid,kind,idx,box,text='',size=18,color='252529',bold=False,align='l'):
    ph=f'<p:ph type="{kind}" idx="{idx}"/>'
    pp=pprops(size,color,bold,align)
    styles=''.join(pprops(max(14,size-i),color,bold,align,i).replace('<a:pPr ',f'<a:lvl{i+1}pPr ').replace('</a:pPr>',f'</a:lvl{i+1}pPr>') for i in range(9))
    para=f'<a:r><a:t>{escape(text)}</a:t></a:r>' if text else '<a:endParaRPr lang="en-GB"/>'
    if kind=='sldNum':
        para='<a:fld id="{02D62CF7-B451-42A0-BFB3-67C7E3FB3001}" type="slidenum"><a:rPr lang="en-GB"/><a:t>1</a:t></a:fld>'
    return f'<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="Clean {kind} {idx}"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr>{ph}</p:nvPr></p:nvSpPr><p:spPr>{xfrm(box)}<a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square" lIns="0" tIns="0" rIns="0" bIns="0" anchor="t"><a:noAutofit/></a:bodyPr><a:lstStyle>{styles}</a:lstStyle><a:p>{pp}{para}</a:p></p:txBody></p:sp>'
def picture(sid,rid,box,name):
    return f'<p:pic><p:nvPicPr><p:cNvPr id="{sid}" name="{name}"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr>{xfrm(box)}</p:spPr></p:pic>'
def rels(rows):
    return xml(f'<Relationships xmlns="{REL}">'+''.join(f'<Relationship Id="{rid}" Type="{TYPE+kind}" Target="{target}"/>' for rid,kind,target in rows)+'</Relationships>')
def cslide(shapes,name=''):
    return f'<p:cSld name="{escape(name)}">{BG}<p:spTree>{GROUP}{shapes}</p:spTree></p:cSld>'

wide = Image.open(BytesIO(files['ppt/media/image2.png'])).size
small = Image.open(BytesIO(files['ppt/media/image1.png'])).size
logo_h = 125 * wide[1] / wide[0]
# Keep its bottom edge and width; restore the source image's aspect ratio.
d = M.parseString(files['ppt/slides/slide1.xml'])
for pic in d.getElementsByTagName('p:pic'):
    if pic.getElementsByTagName('p:cNvPr')[0].getAttribute('name')=='Original university logo':
        x=pic.getElementsByTagName('a:xfrm')[0]
        off=x.getElementsByTagName('a:off')[0]; ext=x.getElementsByTagName('a:ext')[0]
        old_bottom=int(off.getAttribute('y'))+int(ext.getAttribute('cy'))
        height=round(int(ext.getAttribute('cx'))*wide[1]/wide[0])
        ext.setAttribute('cy',str(height));off.setAttribute('y',str(old_bottom-height))
files['ppt/slides/slide1.xml']=d.toxml(encoding='utf-8')
# These two existing slides already contain their own footer logo.
for n in ('ppt/slides/slide22.xml','ppt/slides/slide23.xml'):
    d=M.parseString(files[n]);d.documentElement.setAttribute('showMasterSp','0')
    files[n]=d.toxml(encoding='utf-8')

footer=shape(90,'ftr',11,(36,384,400,12),'Msc Defence T.M. Lenssen',8,'747B82')+shape(91,'sldNum',12,(620,384,28,12),'',8,'747B82',align='r')
title=lambda text='Click to add title': shape(2,'title',0,(36,30,648,40),text,25,bold=True)
content=lambda idx,box,text='Click to add content': shape(idx+10,'obj',idx,box,text)
picph=lambda idx,box: shape(idx+10,'pic',idx,box,'Click to add picture')
layouts={}
for i,name in [(1,'Clean White - Title'),(2,'Clean White - Section'),(3,'Clean White - Title with figure')]:
    y=35 if i!=2 else 135
    s=shape(2,'ctrTitle',0,(36,y,648,86),'Click to add title',28,bold=True)
    s+=shape(3,'subTitle',1,(36,y+96,648,32),'Click to add subtitle',16,'C81919')
    s+=shape(4,'body',13,(36,234,258,59),'Name and supervisor',13)
    s+=shape(5,'body',14,(36,302,258,29),'Department / date',11,'747B82')
    if i==2:
        s=shape(2,'ctrTitle',0,(36,135,648,86),'Click to add section title',28,bold=True)+shape(3,'subTitle',1,(36,240,648,40),'Click to add subtitle',16,'C81919')
    if i==3:s+=picph(15,(345,185,320,163))
    s+=picture(100,'rIdCleanLogo',(36,396.16-logo_h,125,logo_h),'TUe university logo')
    layouts[i]=(name,'title' if i!=2 else 'secHead',s)
layouts[4]=('Clean White - Title and Content','obj',title()+content(1,(36,96,648,260)))
layouts[5]=('Clean White - Comparison','twoObj',shape(2,'title',0,(36,35,308,68),'Left heading',20,bold=True)+shape(23,'body',13,(376,35,308,68),'Right heading',20,bold=True)+content(1,(36,121,308,230))+content(2,(376,121,308,230)))
layouts[6]=('Clean White - Text and Picture','objTx',title()+content(1,(36,96,308,260))+picph(13,(376,96,308,260)))
layouts[7]=('Clean White - Wide Text and Picture','objTx',title()+content(1,(36,96,420,260))+picph(13,(492,96,192,260)))
layouts[8]=('Clean White - Figure and Caption','obj',title()+content(13,(128,86,464,261),'Click to add figure or video')+shape(24,'body',14,(72,352,576,20),'Click to add caption',12,'747B82',align='ctr'))
layouts[9]=('Clean White - Three Panels','cust',title()+''.join(content(idx,(36+j*228,96,192,50),'Panel heading')+picph(15+j,(36+j*228,157,192,192)) for j,idx in enumerate([1,13,14])))
layouts[10]=('Clean White - Picture and Text','cust',title()+picph(13,(36,96,308,260))+content(1,(376,96,308,260)))
layouts[11]=('Clean White - Picture and Wide Text','cust',title()+picph(13,(36,96,192,260))+content(1,(264,96,420,260)))
layouts[12]=('Clean White - Title Only','titleOnly',title())
layouts[13]=('Clean White - Blank','blank','')
layouts[14]=('Clean White - Large Picture','picTx',title()+picph(13,(36,86,648,274)))
layouts[15]=('Clean White - Two Columns','twoObj',title()+content(1,(36,96,308,260))+content(2,(376,96,308,260)))
layouts[16]=('Clean White - Table and Notes','tbl',title()+shape(23,'tbl',13,(36,96,648,175),'Click to add table')+content(1,(36,293,648,65),'Click to add notes'))
layouts[17]=('Clean White - Chart','chart',title()+shape(23,'chart',13,(36,96,648,260),'Click to add chart'))
for i,(name,kind,shapes) in layouts.items():
    is_title=i<=3
    hf='<p:hf hdr="0" dt="0" ftr="0" sldNum="0"/>' if is_title else '<p:hf hdr="0" dt="0" ftr="1" sldNum="1"/>'
    files[f'ppt/slideLayouts/slideLayout{i}.xml']=xml(f'<p:sldLayout {DECL} type="{kind}" preserve="1" showMasterSp="{0 if is_title else 1}">{cslide(shapes+ ("" if is_title else footer),name)}<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>{hf}</p:sldLayout>')
    rows=[('rId1','slideMaster','../slideMasters/slideMaster1.xml')]
    if is_title:rows.append(('rIdCleanLogo','image','../media/image2.png'))
    files[f'ppt/slideLayouts/_rels/slideLayout{i}.xml.rels']=rels(rows)

# Retain master IDs and the original layout relationships, replacing its artwork and defaults.
d=M.parseString(original['ppt/slideMasters/slideMaster1.xml']);root=d.documentElement
shapes=title()+shape(3,'body',1,(36,96,648,260),'Click to add content')+footer+picture(100,'rId19',(666,379,36,36*small[1]/small[0]),'TUe logo')
node=M.parseString(f'<root {DECL}>{cslide(shapes,"TUe - Clean White")}</root>').documentElement.firstChild
root.replaceChild(d.importNode(node,True),d.getElementsByTagName('p:cSld')[0])
for c in list(root.childNodes):
    if c.nodeType==c.ELEMENT_NODE and c.tagName in ['mc:AlternateContent','p:transition','p:hf','p:txStyles','p:extLst']:root.removeChild(c)
styles=''
for tag,size,bold in [('titleStyle',25,True),('bodyStyle',18,False),('otherStyle',18,False)]:
    levels=''.join(pprops(max(14,size-i),bold=bold,level=i).replace('<a:pPr ',f'<a:lvl{i+1}pPr ').replace('</a:pPr>',f'</a:lvl{i+1}pPr>') for i in range(9))
    styles+=f'<p:{tag}>{levels}</p:{tag}>'
for fragment in ['<p:hf hdr="0" dt="0" ftr="1" sldNum="1"/>',f'<p:txStyles>{styles}</p:txStyles>']:
    node=M.parseString(f'<root {DECL}>{fragment}</root>').documentElement.firstChild
    root.appendChild(d.importNode(node,True))
files['ppt/slideMasters/slideMaster1.xml']=d.toxml(encoding='utf-8')

d=M.parseString(files['ppt/theme/theme1.xml']);d.documentElement.setAttribute('name','TUe - Clean White')
d.getElementsByTagName('a:fontScheme')[0].setAttribute('name','Clean White - Aptos')
for group in ['a:majorFont','a:minorFont']:
    d.getElementsByTagName(group)[0].getElementsByTagName('a:latin')[0].setAttribute('typeface','Aptos')
for n in d.getElementsByTagName('thm15:themeFamily'):n.setAttribute('name','TUe - Clean White')
files['ppt/theme/theme1.xml']=d.toxml(encoding='utf-8')

def write(path,parts):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in parts.items():z.writestr(name,data)
write(OUT,files)

# A small, reusable POTX: two empty editable starter slides, all clean layouts,
# and only reachable resources (no research videos or equations bundled).
template=dict(files)
for i,layout in [(1,1),(2,4)]:
    root=E.fromstring(files[f'ppt/slideLayouts/slideLayout{layout}.xml'])
    selected=[]
    for s in root.findall('p:cSld/p:spTree/p:sp',NS):
        ph=s.find('.//p:ph',NS)
        if ph.get('type') not in ['ftr','sldNum']:
            for t in s.findall('.//a:t',NS):t.text=''
        selected.append(E.tostring(s,encoding='unicode'))
    template[f'ppt/slides/slide{i}.xml']=xml(f'<p:sld {DECL}>{cslide("".join(selected))}<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')
    template[f'ppt/slides/_rels/slide{i}.xml.rels']=rels([('rId1','slideLayout',f'../slideLayouts/slideLayout{layout}.xml')])
d=M.parseString(files['ppt/presentation.xml'])
for n in list(d.documentElement.childNodes):
    if n.nodeType==n.ELEMENT_NODE and n.tagName in ['p:notesMasterIdLst','p:custShowLst','p:extLst']:d.documentElement.removeChild(n)
lst=d.getElementsByTagName('p:sldIdLst')[0]
for c in list(lst.childNodes):lst.removeChild(c)
for i in [1,2]:
    node=d.createElementNS(NS['p'],'p:sldId');node.setAttribute('id',str(255+i));node.setAttributeNS(NS['r'],'r:id',f'rIdSlide{i}');lst.appendChild(node)
template['ppt/presentation.xml']=d.toxml(encoding='utf-8')
template['ppt/_rels/presentation.xml.rels']=rels([('rId1','slideMaster','slideMasters/slideMaster1.xml'),('rIdSlide1','slide','slides/slide1.xml'),('rIdSlide2','slide','slides/slide2.xml'),('rIdTheme','theme','theme/theme1.xml')])
# Minimal root relationships omit the old deck's thumbnail and metadata.
template['_rels/.rels']=rels([('rId1','officeDocument','ppt/presentation.xml')])
keep={'[Content_Types].xml','_rels/.rels'}
def visit(part):
    if part in keep:return
    keep.add(part)
    rp=posixpath.join(posixpath.dirname(part),'_rels',posixpath.basename(part)+'.rels')
    if rp in template:
        keep.add(rp)
        for r in E.fromstring(template[rp]):
            if r.get('TargetMode')!='External':visit(posixpath.normpath(posixpath.join(posixpath.dirname(part),r.get('Target'))))
visit('ppt/presentation.xml')
template={n:b for n,b in template.items() if n in keep}
d=M.parseString(template['[Content_Types].xml'])
for n in list(d.getElementsByTagName('Override')):
    part=n.getAttribute('PartName').lstrip('/')
    if part not in template:n.parentNode.removeChild(n)
    elif part=='ppt/presentation.xml':n.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.template.main+xml')
template['[Content_Types].xml']=d.toxml(encoding='utf-8')
write(TEMPLATE,template)

# Validate package links and preserved content, including Office Math and timelines.
for path,parts in [(OUT,files),(TEMPLATE,template)]:
    for n,b in parts.items():
        if n.endswith(('.xml','.rels')):E.fromstring(b)
        if n.endswith('.rels'):
            base=posixpath.dirname(posixpath.dirname(n))
            if n=='_rels/.rels':base=''
            for r in E.fromstring(b):
                if r.get('TargetMode')=='External':continue
                target=posixpath.normpath(posixpath.join(base,r.get('Target')))
                assert target in parts,(n,target)
    with zipfile.ZipFile(path) as z:assert z.testzip() is None
for n,b in original.items():
    if n.startswith(('ppt/media/','ppt/embeddings/','ppt/notesSlides/')):assert files[n]==b,n
    if re.fullmatch(r'ppt/slides/slide\d+.xml',n):
        before=E.fromstring(b);after=E.fromstring(files[n])
        for tag in ['a:t','p:timing','p:transition']:
            assert [E.tostring(x) for x in before.findall('.//'+tag,NS)]==[E.tostring(x) for x in after.findall('.//'+tag,NS)],(n,tag)
        if n not in ['ppt/slides/slide1.xml','ppt/slides/slide22.xml','ppt/slides/slide23.xml']:assert files[n]==b,n
report={'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'slides':24,'layouts':[v[0] for v in layouts.values()], 'title_logo_source_pixels':wide,'title_logo_points':[125,logo_h], 'deck':str(OUT.resolve()),'template':str(TEMPLATE.resolve()),'checks':'XML, ZIP CRC, every internal relationship, unchanged slide text/timelines/media/embedded objects/notes; 21 slide XML parts byte-identical'}
(B/'validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
