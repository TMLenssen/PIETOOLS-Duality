from pathlib import Path
import zipfile,xml.dom.minidom as M,json

B=Path(__file__).parent
Z=zipfile.ZipFile(B/'expanded.pptx')
FILES={n:Z.read(n) for n in Z.namelist()}
MAP=json.loads((B/'stage_map.json').read_text())
INS=json.loads((B/'inspection.json').read_text(encoding='utf-8-sig'))
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
POS={r['Index']:{s['Id']:(s['Left'],s['Top'],s['Width'],s['Height']) for s in r['Shapes']} for r in INS}
DARK='252529';GRAY='747B82';RED='C71919'
def els(n,tag):return list(n.getElementsByTagName(tag))
def direct(n,tag):return next((c for c in n.childNodes if c.nodeType==c.ELEMENT_NODE and c.tagName==tag),None)
def add(n,tag,attrs=None):
    e=n.ownerDocument.createElement(tag)
    for k,v in (attrs or {}).items():e.setAttribute(k,str(v))
    n.appendChild(e);return e
def ensure(n,tag):return direct(n,tag) or add(n,tag)
def remove(n,tags):
    for tag in tags:
        for e in els(n,tag):
            if e.parentNode:e.parentNode.removeChild(e)
def shape_id(n):
    a=els(n,'p:cNvPr');return int(a[0].getAttribute('id')) if a else None
def box(s,x,y,w,h):
    # Native math and its legacy image fallback both retain the same geometry.
    for sp in els(s,'p:spPr'):
        xf=direct(sp,'a:xfrm')
        if xf is None:xf=sp.ownerDocument.createElement('a:xfrm');sp.insertBefore(xf,sp.firstChild)
        for tag,attrs in [('a:off',{'x':round(x*12700),'y':round(y*12700)}),('a:ext',{'cx':round(w*12700),'cy':round(h*12700)})]:
            e=ensure(xf,tag)
            for k,v in attrs.items():e.setAttribute(k,str(v))
def fit(s,orig,id,x,y,w,h):
    _,_,ow,oh=POS[orig][id];scale=min(w/ow,h/oh);nw=ow*scale;nh=oh*scale
    box(s,x+(w-nw)/2,y+(h-nh)/2,nw,nh)
def fill(n,color):
    for tag in ['a:noFill','a:solidFill','a:gradFill','a:blipFill','a:pattFill','a:grpFill']:
        e=direct(n,tag)
        if e:n.removeChild(e)
    if color:add(add(n,'a:solidFill'),'a:srgbClr',{'val':color})
    else:add(n,'a:noFill')
def font(r,size,bold,color,name='Aptos'):
    r.setAttribute('sz',str(round(size*100)));r.setAttribute('b','1' if bold else '0');r.setAttribute('u','none');r.setAttribute('cap','none')
    fill(r,color)
    for tag in ['a:latin','a:ea','a:cs']:
        e=ensure(r,tag);e.setAttribute('typeface',name)
def txt(s,size,bold=False,color=DARK,align='l',spacing=0,math=False):
    for sp in els(s,'p:spPr'):
        fill(sp,None);ln=ensure(sp,'a:ln');fill(ln,None)
    for tb in els(s,'p:txBody'):
        bp=ensure(tb,'a:bodyPr')
        for k,v in {'lIns':0,'rIns':0,'tIns':0,'bIns':0,'anchor':'t','wrap':'none' if math else 'square'}.items():bp.setAttribute(k,str(v))
        for tag in ['a:spAutoFit','a:normAutofit','a:noAutofit']:
            e=direct(bp,tag)
            if e:bp.removeChild(e)
        add(bp,'a:noAutofit')
        for p in els(tb,'a:p'):
            pp=direct(p,'a:pPr')
            if pp is None:pp=p.ownerDocument.createElement('a:pPr');p.insertBefore(pp,p.firstChild)
            pp.setAttribute('algn',align)
            if not math:
                pp.setAttribute('marL','0');pp.setAttribute('indent','0')
                for tag in ['a:buChar','a:buAutoNum','a:buNone']:
                    e=direct(pp,tag)
                    if e:pp.removeChild(e)
                add(pp,'a:buNone')
            for tag in ['a:spcBef','a:spcAft']:
                e=direct(pp,tag)
                if e:pp.removeChild(e)
            add(add(pp,'a:spcAft'),'a:spcPts',{'val':round(spacing*100)})
            dr=ensure(pp,'a:defRPr');font(dr,size,bold,color,'Cambria Math' if math else 'Aptos')
        for r in els(tb,'a:r')+els(tb,'a:fld'):
            rp=direct(r,'a:rPr')
            if rp is None:rp=r.ownerDocument.createElement('a:rPr');r.insertBefore(rp,r.firstChild)
            if not math:font(rp,size,bold,color)
        for rp in els(tb,'a:rPr')+els(tb,'a:endParaRPr'):
            if math:rp.setAttribute('sz',str(round(size*100)))
            else:font(rp,size,bold,color)
def picture(doc,tree,rels,image,x,y,w,h,name):
    sid=max(shape_id(c) or 0 for c in tree.childNodes if c.nodeType==c.ELEMENT_NODE)+1
    rid='rIdClean'+str(sid)
    rel=add(rels.documentElement,'Relationship',{'Id':rid,'Type':R+'/image','Target':'../media/'+image})
    sp=add(tree,'p:pic');nv=add(sp,'p:nvPicPr');add(nv,'p:cNvPr',{'id':sid,'name':name});add(add(nv,'p:cNvPicPr'),'a:picLocks',{'noChangeAspect':1});add(nv,'p:nvPr')
    bf=add(sp,'p:blipFill');bl=add(bf,'a:blip');bl.setAttributeNS(R,'r:embed',rid);add(add(bf,'a:stretch'),'a:fillRect')
    prop=add(sp,'p:spPr');geom=add(prop,'a:prstGeom',{'prst':'rect'});add(geom,'a:avLst');box(sp,x,y,w,h)
    return sp

for row in MAP:
    i,o,k=row['slide'],row['original'],row['stage']
    part=f'ppt/slides/slide{i}.xml';relpart=f'ppt/slides/_rels/slide{i}.xml.rels'
    d=M.parseString(FILES[part]);rel=M.parseString(FILES[relpart]);root=d.documentElement
    root.setAttribute('showMasterSp','0')
    cs=els(d,'p:cSld')[0];tree=direct(cs,'p:spTree')
    bg=direct(cs,'p:bg')
    if bg:cs.removeChild(bg)
    bg=d.createElement('p:bg');cs.insertBefore(bg,tree);fill(add(bg,'p:bgPr'),'FFFFFF')
    # Only the neuron sequence becomes pages; all other original timing and morph XML is untouched.
    if o==9:remove(d,['p:timing'])
    keep=None
    if o==9:keep={5,6,68}|[{56,38},{62,40},{60,42},{58,44,81},{54,46},{70,76},{80,78}][k]
    if keep is not None:
        for s in list(tree.childNodes):
            if s.nodeType==s.ELEMENT_NODE and s.tagName not in ['p:nvGrpSpPr','p:grpSpPr'] and shape_id(s) not in keep:tree.removeChild(s)
    S={shape_id(s):s for s in tree.childNodes if s.nodeType==s.ELEMENT_NODE and s.tagName not in ['p:nvGrpSpPr','p:grpSpPr']}
    def T(id,x,y,w,h,size,bold=False,color=DARK,align='l',spacing=0):box(S[id],x,y,w,h);txt(S[id],size,bold,color,align,spacing)
    def F(id,x,y,w,h):fit(S[id],o,id,x,y,w,h)
    def Q(id,x,y,w,h,size):box(S[id],x,y,w,h);txt(S[id],size,math=True,align='ctr')
    for id,s in S.items():
        text=''.join(t.firstChild.data if t.firstChild else '' for t in els(s,'a:t'))
        name=els(s,'p:cNvPr')[0].getAttribute('name')
        if text=='Msc Defence T.M. Lenssen':T(id,36,384,400,12,8,color=GRAY)
        elif 'Slide Number' in name:
            T(id,620,384,28,12,8,color=GRAY,align='r')
            for t in els(s,'a:t'):
                for c in list(t.childNodes):t.removeChild(c)
                t.appendChild(d.createTextNode(str(i)))
    if o!=1:picture(d,tree,rel,'image1.png',666,379,36,20,'Original TUe logo')
    if o==1:
        T(6,36,35,648,108,28,True);T(7,36,148,400,30,16,color=RED)
        T(8,36,262,225,58,12);T(9,36,332,225,32,10,color=GRAY)
        picture(d,tree,rel,'image3.png',278,171,414,232.875,'Original title response figure')
        picture(d,tree,rel,'image2.png',36,365,125,31.16,'Original university logo')
    if o==2:
        T(2,36,35,308,80,18);T(7,376,35,308,80,18)
        for id in [2,7]:
            p=els(S[id],'a:p')[0]
            # Preserve original first-line emphasis without changing text runs.
            for r in els(p,'a:r'):
                rp=direct(r,'a:rPr');rp.setAttribute('b','1')
                if direct(p,'a:br'):break
        F(20,36,121,308,222);F(21,376,121,308,222)
    if o==3:
        for title,caption,x in [(16,27,36),(18,25,264),(23,26,492)]:
            T(title,x,34,192,49,16,True,align='ctr')
            T(caption,x,306,192,56,13,align='ctr')
        F(7,36,103,192,150);F(19,264,96,192,126);F(29,264,223,192,65)
        F(24,492,96,192,192);F(31,492,96,192,192)
    if o==4:
        T(2,36,27,648,40,25,True);T(3,42,100,228,254,16,spacing=14)
        for id,x in [(11,312),(13,566)]:
            T(id,x,91,118,48,20,True,align='ctr')
            for bp in els(S[id],'a:bodyPr'):bp.setAttribute('anchor','ctr')
            for prop in els(S[id],'p:spPr'):fill(prop,'F2F3F5')
        box(S[14],475,108,46,14)
        for prop in els(S[14],'p:spPr'):fill(prop,DARK)
        T(15,459,143,78,24,13,color=RED,align='ctr')
        Q(17,302,202,166,88,14);Q(18,480,195,214,122,14)
        Q(21,299,191,393,150,23);Q(22,293,231,401,82,14);Q(23,298,211,396,107,17)
    if o==5:
        F(20,36,26,648,115);Q(14,60,146,600,57,18);F(18,64,211,364,156);T(22,457,264,219,55,18,True)
    if o==6:F(8,185,20,350,350)
    if o==7:F(8,36,20,648,350)
    if o==8:
        for id in [13,15,17,18]:
            if id in S:
                x,y,w,h=POS[o][id];box(S[id],x+14.5,y+15,w,h)
        T(14,130,350,460,20,12,color=GRAY,align='ctr')
        for id in [15,17]:
            if id in S:
                for ln in els(S[id],'a:ln'):ln.setAttribute('w','19050')
    if o==9:
        T(68,36,352,420,20,11,color=GRAY)
        diagram=[56,62,60,58,54,70,80][k]
        if k<5:
            F(diagram,148,19,424,212);Q([38,40,42,44,46][k],102,229 if k>=3 else 243,516,102,17 if k>=3 else 18)
            if k==3:T(81,120,330,540,20,12,True)
        else:F(diagram,33,59,337,220);F(76 if k==5 else 78,392,59,297,255)
    if o==10:T(2,36,30,648,40,25,True);T(5,36,105,630,240,17,spacing=26)
    if o==11:T(6,54,48,612,122,25,True);T(7,80,209,566,140,21,spacing=20)
    # Keep DrawingML property order valid after applying explicit formatting.
    orders={
        'p:spPr':'a:xfrm a:custGeom a:prstGeom a:noFill a:solidFill a:gradFill a:blipFill a:pattFill a:grpFill a:ln a:effectLst a:effectDag a:scene3d a:sp3d a:extLst',
        'a:rPr':'a:ln a:noFill a:solidFill a:gradFill a:blipFill a:pattFill a:grpFill a:effectLst a:effectDag a:highlight a:uLnTx a:uLn a:uFillTx a:uFill a:latin a:ea a:cs a:sym a:hlinkClick a:hlinkMouseOver a:rtl a:extLst',
        'a:pPr':'a:lnSpc a:spcBef a:spcAft a:buClrTx a:buClr a:buSzTx a:buSzPct a:buSzPts a:buFontTx a:buFont a:buNone a:buAutoNum a:buChar a:buBlip a:tabLst a:defRPr a:extLst'}
    orders['a:defRPr']=orders['a:rPr'];orders['a:endParaRPr']=orders['a:rPr']
    for tag,order in orders.items():
        ranks={t:j for j,t in enumerate(order.split())}
        for e in els(d,tag):
            children=[c for c in e.childNodes if c.nodeType==c.ELEMENT_NODE]
            for c in sorted(children,key=lambda c:ranks.get(c.tagName,999)):e.appendChild(c)
    FILES[part]=d.toxml(encoding='utf-8');FILES[relpart]=rel.toxml(encoding='utf-8')

OUT=B.parent/'Dual IQC - Formatted.pptx'
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED) as out:
    for n,data in FILES.items():out.writestr(n,data)
print(OUT)
