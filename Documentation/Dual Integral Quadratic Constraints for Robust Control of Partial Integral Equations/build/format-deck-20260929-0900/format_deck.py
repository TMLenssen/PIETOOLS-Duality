from pathlib import Path
from xml.dom import minidom as M
import zipfile, json, posixpath, hashlib, copy

ROOT=Path(__file__).resolve().parent
NS={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
def tags(n,q):
    p,t=q.split(':'); return list(n.getElementsByTagNameNS(NS[p],t))
def first(n,q): return tags(n,q)[0]
def top_shapes(d):
    return [n for n in first(d,'p:spTree').childNodes if n.nodeType==n.ELEMENT_NODE and tags(n,'p:cNvPr')]
def sid(s): return int(first(s,'p:cNvPr').getAttribute('id'))
def name(s): return first(s,'p:cNvPr').getAttribute('name')
def shape(d,i): return next(s for s in top_shapes(d) if sid(s)==i)
def font(s,size):
    for q in ('a:rPr','a:defRPr','a:endParaRPr'):
        for r in tags(s,q): r.setAttribute('sz',str(round(size*100)))
def geom(s,**kw):
    # Targeted text shapes have one transform per native/fallback representation.
    for x in tags(s,'a:xfrm'):
        for k,v in kw.items():
            child,attr=('a:off',k) if k in ('x','y') else ('a:ext',{'w':'cx','h':'cy'}[k])
            first(x,child).setAttribute(attr,str(round(v*12700)))
def dy(s,value):
    for x in tags(s,'a:xfrm'):
        o=first(x,'a:off');o.setAttribute('y',str(int(o.getAttribute('y'))+round(value*12700)))
def plain(s):
    return tuple(n.toxml() for q in ('a:t',) for n in tags(s,q))

zin=zipfile.ZipFile(ROOT/'source.pptx')
parts={n:zin.read(n) for n in zin.namelist()}
pres=M.parseString(parts['ppt/presentation.xml'])
rels=M.parseString(parts['ppt/_rels/presentation.xml.rels'])
targets={r.getAttribute('Id'):posixpath.normpath('ppt/'+r.getAttribute('Target')) for r in rels.documentElement.childNodes if r.nodeType==r.ELEMENT_NODE}
paths=[targets[n.getAttribute('r:id')] for n in tags(pres,'p:sldId')]
docs=[M.parseString(parts[p]) for p in paths]
inventory=json.loads((ROOT/'inventory.json').read_text(encoding='utf-8-sig'))
skip={1,16,17,19,25,39,40,41}
template=next(s for s in top_shapes(docs[1]) if name(s)=='Logical slide number').cloneNode(True)
changes=[]; count=0
for idx,d in enumerate(docs,1):
    original={sid(s):plain(s) for s in top_shapes(d) if name(s)!='Logical slide number'}
    for sh in inventory[idx-1]['shapes']:
        s=shape(d,sh['id'])
        nm=sh['name'].lower()
        if idx!=1 and (nm in ('title','title 1','title 20','slide title','closing title','appendix title')) and 24<=sh['size']<=26:
            font(s,24)
            # Keep staged and mathematical title colours exactly as authored.
            if nm!='appendix title': geom(s,x=36,y=27)
        if 'footer' in nm and sh['text']:
            font(s,8); geom(s,y=384,h=12)
    numbers=[s for s in top_shapes(d) if name(s)=='Logical slide number']
    if idx in skip:
        for s in numbers: s.parentNode.removeChild(s)
    else:
        count+=1
        if not numbers:
            s=d.importNode(template,True)
            newid=max(int(n.getAttribute('id')) for n in tags(d,'p:cNvPr'))+1
            first(s,'p:cNvPr').setAttribute('id',str(newid))
            first(d,'p:spTree').appendChild(s); numbers=[s]
        for s in numbers:
            tt=tags(s,'a:t'); tt[0].firstChild.nodeValue=str(count)
            for t in tt[1:]:
                if t.firstChild: t.firstChild.nodeValue=''
            geom(s,x=620,y=384,w=32,h=12);font(s,8)
            for p in tags(s,'a:pPr'):p.setAttribute('algn','r')
    # Explicitly bounded adjustments to text layout only.
    if idx==6:
        for i in (11,17): geom(shape(d,i),x=466,w=218,h=26);font(shape(d,i),12)
    if idx==13:
        s=shape(d,900126);geom(s,x=308,w=376,h=64);font(s,18)
    if idx==15:
        s=shape(d,900192);geom(s,x=290,w=394,h=34);font(s,16)
    if idx==18:
        s=shape(d,2);geom(s,y=342,h=25);font(s,20)
    if idx==21:
        for i in (62,8):dy(shape(d,i),-20)
        s=shape(d,9);dy(s,-25);font(s,12);geom(s,h=18)
        dy(shape(d,900222),-10)
        for i in (900218,900221):geom(shape(d,i),w=350)
    if idx in (22,23,24):
        geom(shape(d,107),h=58)
        for i in (115,118,6):geom(shape(d,i),h=48)
    if idx==34:
        for i in (3,4,11,12):dy(shape(d,i),-10)
        for i in (5,6):dy(shape(d,i),-8)
        for i in (8,10):dy(shape(d,i),-11);font(shape(d,i),12)
    if idx in (43,45):
        i=1006 if idx==43 else 8
        s=shape(d,i);geom(s,w=250,h=29);font(s,10)
        i=1010 if idx==43 else 1009
        s=shape(d,i);geom(s,w=240,h=20);font(s,10)
    assert original=={sid(s):plain(s) for s in top_shapes(d) if name(s)!='Logical slide number'},f'Content changed on {idx}'
    out=d.toxml(encoding='UTF-8')
    before=M.parseString(parts[paths[idx-1]])
    for q in ('p:timing','p:transition'):
        assert [n.toxml() for n in tags(before,q)]==[n.toxml() for n in tags(d,q)],(idx,q)
    if out!=parts[paths[idx-1]]:changes.append(idx)
    parts[paths[idx-1]]=out

with zipfile.ZipFile(ROOT/'formatted.pptx','w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as zout:
    for info in zin.infolist():zout.writestr(copy.copy(info),parts[info.filename])
with zipfile.ZipFile(ROOT/'formatted.pptx') as z:
    assert z.testzip() is None
    for n in zin.namelist():
        if n not in paths:assert z.read(n)==zin.read(n),n
report={'slides':len(docs),'numbered_slides':count,'unnumbered_positions':sorted(skip),'changed_positions':changes,'verified':'All non-number text, timing, transitions, and every non-slide package part unchanged.'}
(ROOT/'validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
