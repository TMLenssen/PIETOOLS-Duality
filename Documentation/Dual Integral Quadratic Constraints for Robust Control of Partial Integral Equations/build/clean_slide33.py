from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
import hashlib, json

out=Path(__file__).parent/'slide33_cleanup'
meta=json.loads((out/'source.json').read_text(encoding='utf-8-sig'))
source=Path(meta['source'])
assert hashlib.sha256(source.read_bytes()).hexdigest().upper()==meta['hash'], 'Source changed during editing'
slide='ppt/slides/slide33.xml'
with ZipFile(source) as z:
    doc=D.parseString(z.read(slide))
    def element(tag, **attrs):
        e=doc.createElement(tag)
        for k,v in attrs.items(): e.setAttribute(k,str(v))
        return e
    def child(e, tag):
        return next(x for x in e.childNodes if x.nodeType==x.ELEMENT_NODE and x.tagName==tag)
    def shape(sid):
        return next(x for x in doc.getElementsByTagName('p:cNvPr') if x.getAttribute('id')==str(sid)).parentNode.parentNode
    def unit(x): return round(x*12700)
    def translate(sid, dx=0,dy=0):
        # Update native equation and legacy fallback shapes together.
        for c in list(doc.getElementsByTagName('p:cNvPr')):
            if c.getAttribute('id')!=str(sid): continue
            s=c.parentNode.parentNode
            xf=child(child(s,'p:spPr'),'a:xfrm')
            p=child(xf,'a:off')
            p.setAttribute('x',str(int(p.getAttribute('x'))+unit(dx)))
            p.setAttribute('y',str(int(p.getAttribute('y'))+unit(dy)))
    def path(sid,points,group=False):
        s=shape(sid)
        # Preserve shape identity while making every route an editable freeform.
        if s.tagName=='p:cxnSp':
            new=element('p:sp')
            nv=element('p:nvSpPr')
            nv.appendChild(child(child(s,'p:nvCxnSpPr'),'p:cNvPr').cloneNode(True))
            nv.appendChild(element('p:cNvSpPr')); nv.appendChild(element('p:nvPr'))
            new.appendChild(nv); new.appendChild(element('p:spPr'))
            s.parentNode.replaceChild(new,s); s=new
        sp=child(s,'p:spPr')
        for c in list(sp.childNodes): sp.removeChild(c)
        # Retain the group's existing 1:1 coordinate transform.
        pts=[(unit(x)+(1538732 if group else 0),unit(y)+(1342136 if group else 0)) for x,y in points]
        left=min(x for x,y in pts)-12700; top=min(y for x,y in pts)-12700
        width=max(x for x,y in pts)-left+12700; height=max(y for x,y in pts)-top+12700
        xf=element('a:xfrm'); xf.appendChild(element('a:off',x=left,y=top)); xf.appendChild(element('a:ext',cx=width,cy=height));sp.appendChild(xf)
        geom=element('a:custGeom')
        for name in ['a:avLst','a:gdLst','a:ahLst','a:cxnLst']:geom.appendChild(element(name))
        geom.appendChild(element('a:rect',l=0,t=0,r='r',b='b'))
        paths=element('a:pathLst'); route=element('a:path',w=width,h=height,fill='none')
        for i,(x,y) in enumerate(pts):
            step=element('a:moveTo' if i==0 else 'a:lnTo'); step.appendChild(element('a:pt',x=x-left,y=y-top)); route.appendChild(step)
        paths.appendChild(route);geom.appendChild(paths);sp.appendChild(geom);sp.appendChild(element('a:noFill'))
        line=element('a:ln',w=12531);fill=element('a:solidFill');fill.appendChild(element('a:srgbClr',val='252529'));line.appendChild(fill)
        line.appendChild(element('a:round'));line.appendChild(element('a:tailEnd',type='triangle',w='sm',len='sm'));sp.appendChild(line)
    # Keep G, K and Theta in their original arrangement, with more breathing room.
    for sid in [17,18,113]: translate(sid,dy=10.6)
    translate(19,dy=155.155-160.214966)
    translate(114,dy=155.155-160.214966)
    translate(20,dy=155.155-154.294968)
    group=shape(5);xf=child(child(group,'p:grpSpPr'),'a:xfrm')
    for tag in ['a:ext','a:chExt']:
        e=child(xf,tag);e.setAttribute('cy',str(int(e.getAttribute('cy'))+unit(10.6)))
    path(14,[(132.2,210.96),(75.96,210.96),(75.96,129.32),(121.84,129.32)],True)
    path(15,[(195.84,129.32),(241.72,129.32),(241.72,210.96),(185.48,210.96)],True)
    path(55,[(195.84,210.96),(195.84,261.234955),(216.139374,261.234955)])
    path(61,[(98.73591,210.96),(98.73591,290.834961),(216.139374,290.834961)])
    path(34,[(290.139374,261.234955),(336.019374,261.234955)])
    path(36,[(290.139374,290.834961),(336.019374,290.834961)])
    # Explicit junction dots make the two taps unambiguous.
    tree=doc.getElementsByTagName('p:spTree')[0]
    for sid,x in [(200,195.84),(201,98.73591)]:
        s=element('p:sp');nv=element('p:nvSpPr');nv.appendChild(element('p:cNvPr',id=sid,name='Signal tap '+str(sid)));nv.appendChild(element('p:cNvSpPr'));nv.appendChild(element('p:nvPr'));s.appendChild(nv)
        sp=element('p:spPr');xf=element('a:xfrm');xf.appendChild(element('a:off',x=unit(x-1.4),y=unit(210.96-1.4)));xf.appendChild(element('a:ext',cx=unit(2.8),cy=unit(2.8)));sp.appendChild(xf)
        geom=element('a:prstGeom',prst='ellipse');geom.appendChild(element('a:avLst'));sp.appendChild(geom)
        fill=element('a:solidFill');fill.appendChild(element('a:srgbClr',val='252529'));sp.appendChild(fill);ln=element('a:ln');ln.appendChild(element('a:noFill'));sp.appendChild(ln);s.appendChild(sp);tree.appendChild(s)
    edited=doc.toxml(encoding='UTF-8')
    with ZipFile(out/'cleaned.pptx','w') as target:
        for item in z.infolist(): target.writestr(item,edited if item.filename==slide else z.read(item.filename))
with ZipFile(source) as a, ZipFile(out/'cleaned.pptx') as b:
    changed=[name for name in a.namelist() if a.read(name)!=b.read(name)]
assert changed==[slide],changed
print('Verified: only slide33.xml changed; all other slides and media are identical.')
