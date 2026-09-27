from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.dom import minidom as D
import json, importlib.util, unicodedata

B=Path(__file__).resolve().parent; ROOT=B.parents[1]
with ZipFile(B/'source.pptx') as z: files={n:z.read(n) for n in z.namelist()}
spec=importlib.util.spec_from_file_location('visual',ROOT/'Presentation/SectorIQC/build_visualization.py')
v=importlib.util.module_from_spec(spec); spec.loader.exec_module(v); b=v.b
d=D.parseString(files['ppt/slides/slide2.xml']); tree=d.getElementsByTagName('p:spTree')[0]
for prefix,uri in b.NS.items(): d.documentElement.setAttribute('xmlns:'+prefix,uri)
def first(n,tag): return n.getElementsByTagName(tag)[0]
def name(n): return first(n,'p:cNvPr').getAttribute('name')
def frag(xml): return D.parseString('<root '+b.DECL+'>'+xml+'</root>').documentElement.firstChild
shapes={name(n):n for n in tree.childNodes if n.nodeType==1 and n.getElementsByTagName('p:cNvPr')}
ids=[int(n.getAttribute('id')) for n in d.getElementsByTagName('p:cNvPr')]
ident=max(ids)+100
def red(pr):
    for c in list(pr.childNodes):
        if c.nodeType==1 and c.tagName in ['a:solidFill','a:gradFill','a:noFill']: pr.removeChild(c)
    fill=frag('<a:solidFill><a:srgbClr val="C8102E"/></a:solidFill>')
    pr.insertBefore(pr.ownerDocument.importNode(fill,True),pr.firstChild)
manifest=[]
for nm in ['Moving spatial coordinate','Flexible beam PDE','Clamped and free boundary','Free shear boundary']:
    original=shapes[nm]; clone=original.cloneNode(True)
    for f in list(clone.getElementsByTagName('mc:Fallback')): f.parentNode.removeChild(f)
    ident+=1; newname='Red '+nm
    nv=first(clone,'p:cNvPr'); nv.setAttribute('id',str(ident)); nv.setAttribute('name',newname)
    if nm!='Flexible beam PDE':
        for pr in clone.getElementsByTagName('a:rPr'): red(pr)
    else:
        # Color the spatial argument and spatial derivative indices, retaining t in black.
        for run in list(clone.getElementsByTagName('m:r')):
            ts=run.getElementsByTagName('m:t')
            if not ts or not ts[0].firstChild: continue
            text=ts[0].firstChild.data
            if 's' not in unicodedata.normalize('NFKC',text): continue
            for ch in text:
                nr=run.cloneNode(True); first(nr,'m:t').firstChild.data=ch
                if unicodedata.normalize('NFKC',ch)=='s': red(first(nr,'a:rPr'))
                run.parentNode.insertBefore(nr,run)
            run.parentNode.removeChild(run)
    tree.appendChild(d.importNode(clone,True))
    manifest.append({'original':nm,'new':newname,'original_id':first(original,'p:cNvPr').getAttribute('id'),'new_id':str(ident)})

# Place a spring network on the cart's actual final body position.
pic=shapes['cart_rigid']; xf=first(pic,'a:xfrm'); off=first(xf,'a:off'); ext=first(xf,'a:ext')
x,y=[int(off.getAttribute(k))/12700 for k in ['x','y']]
w,h=[int(ext.getAttribute(k))/12700 for k in ['cx','cy']]
base=json.loads((ROOT/'build/deck_label_overlays/cart_label_positions.json').read_text())['rigid']['base'][-1]
def p(px,py): return (x+px*w/960,y+py*h/540)
s=v.Slide(); s.i=ident+100
def rect(nm,x1,y1,x2,y2,c):
    s.poly(nm,[p(x1,y1),p(x2,y1),p(x2,y2),p(x1,y2)],width=0,filled=c)
def path(nm,pts): s.poly(nm,[p(px,py) for px,py in pts],color='C8102E',width=.72)
# Small masks turn the red material into discrete, spring-connected body segments.
rect('Upright spring openings',base-12,158,base+12,343,'FFFFFF')
for i in range(10):
    top=158+i*18.5; end=top+18.5
    pts=[(base,top),(base,top+2.5)]
    pts += [(base+(9 if k%2==0 else -9),top+4+k*1.8) for k in range(7)]
    pts += [(base,end-2.5),(base,end)]
    path('Upright spring '+str(i+1),pts)
rect('Cart body spring openings',base-106,347,base+106,373,'FFFFFF')
for i in range(10):
    left=base-106+i*21.2; right=left+21.2
    pts=[(left,360),(left+3,360)]
    pts += [(left+4+k*2.1,360+(7 if k%2==0 else -7)) for k in range(7)]
    pts += [(right-3,360),(right,360)]
    path('Cart body spring '+str(i+1),pts)
groupid=s.i+1
group=frag(f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{groupid}" name="Additional flexible modes - body springs"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="9144000" cy="5143500"/><a:chOff x="0" y="0"/><a:chExt cx="9144000" cy="5143500"/></a:xfrm></p:grpSpPr>'+''.join(s.parts)+'</p:grpSp>')
tree.appendChild(d.importNode(group,True))
cap=v.Slide(); cap.i=groupid+10
cap.label('Flexible modes caption',190,133,'Approximate with more flexible modes',11,'C8102E',w=308)
tree.appendChild(d.importNode(frag(cap.parts[0]),True))
files['ppt/slides/slide2.xml']=d.toxml(encoding='utf-8')
with ZipFile(B/'staged.pptx','w',ZIP_DEFLATED) as z:
    for n,val in files.items(): z.writestr(n,val)
(B/'highlights.json').write_text(json.dumps(manifest))
print('Added 20 body-mounted springs and red spatial/boundary equation variants.')
