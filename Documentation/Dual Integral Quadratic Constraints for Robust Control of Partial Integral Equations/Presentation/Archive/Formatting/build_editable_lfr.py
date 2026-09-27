"""Convert the source TikZ paths and labels to native editable DrawingML."""
from pathlib import Path
from copy import deepcopy
from xml.sax.saxutils import escape,quoteattr
import fitz,zipfile,json,hashlib,math,xml.etree.ElementTree as E

B=Path(__file__).parent/'lfr_library'
ASSETS=B/'assets';ASSETS.mkdir(exist_ok=True)
NS={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
DECL=' '.join(f'xmlns:{k}="{v}"' for k,v in NS.items())
PKG='http://schemas.openxmlformats.org/package/2006/relationships'
EMU=12700
def emu(x):return str(round(x*EMU))
def xml(s):return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+s).encode()
def rgb(v):return ''.join(f'{max(0,min(255,round(c*255))):02X}' for c in v)
def xfrm(box):
    x,y,w,h=box
    return f'<a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(max(w,0.01))}" cy="{emu(max(h,0.01))}"/></a:xfrm>'
def solid(color):return f'<a:solidFill><a:srgbClr val="{color}"/></a:solidFill>'
def nv(sid,name,text=False):return f'<p:nvSpPr><p:cNvPr id="{sid}" name={quoteattr(name)}/><p:cNvSpPr'+(' txBox="1"' if text else '')+'/><p:nvPr/></p:nvSpPr>'
def textbox(sid,name,box,runs,size=18,color='252529',align='ctr',bold=False):
    # runs: (text, size, baseline percentage, italic, color, font)
    content=''
    for text,fs,base,italic,clr,font in runs:
        content+=f'<a:r><a:rPr lang="en-GB" sz="{round(fs*100)}" b="{int(bold)}" i="{int(italic)}" baseline="{round(base*1000)}">{solid(clr)}<a:latin typeface="{font}"/><a:ea typeface="{font}"/><a:cs typeface="{font}"/></a:rPr><a:t xml:space="preserve">{escape(text)}</a:t></a:r>'
    return f'<p:sp>{nv(sid,name,True)}<p:spPr>{xfrm(box)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="none" lIns="0" tIns="0" rIns="0" bIns="0" anchor="ctr"><a:noAutofit/></a:bodyPr><a:lstStyle/><a:p><a:pPr algn="{align}"><a:buNone/></a:pPr>{content}<a:endParaRPr lang="en-GB" sz="{round(size*100)}"/></a:p></p:txBody></p:sp>'
def plain(sid,name,box,text,size,color='252529',align='l',bold=False):return textbox(sid,name,box,[(text,size,0,False,color,'Aptos')],size,color,align,bold)

def label_lines(page):
    lines=[deepcopy(l) for b in page.get_text('dict')['blocks'] if b['type']==0 for l in b['lines']]
    # PDF sometimes reports a hat accent on its own line; attach to its base letter.
    for l in list(lines):
        if ''.join(s['text'] for s in l['spans'])=='ˆ':
            hat=l['spans'][0]
            candidates=[q for q in lines if q is not l and any(abs(s['origin'][0]-hat['origin'][0])<5 and abs(s['origin'][1]-hat['origin'][1])<1 for s in q['spans'])]
            if candidates:
                candidates[0]['spans'].insert(0,hat);lines.remove(l)
    return lines

def diagram_group(page,gid,box):
    drawings=page.get_drawings();lines=label_lines(page)
    # Reconstruct stretchy matrix brackets as paths, since their PDF text boxes
    # describe font metrics rather than the tall bracket visible on the page.
    bracket_lines=[l for l in lines if ''.join(s['text'] for s in l['spans']) in ['[',']']]
    matrix_lines=[l for l in lines if ''.join(s['text'] for s in l['spans']).startswith('δ')]
    if bracket_lines and matrix_lines:
        mr=fitz.Rect()
        for l in matrix_lines:mr|=fitz.Rect(l['bbox'])
        for l in bracket_lines:
            is_left=l['spans'][0]['text']=='['
            xx=mr.x0-4 if is_left else mr.x1+4
            inward=2.5 if is_left else -2.5
            points=[fitz.Point(xx+inward,mr.y0-1),fitz.Point(xx,mr.y0-1),fitz.Point(xx,mr.y1+1),fitz.Point(xx+inward,mr.y1+1)]
            drawings.append({'items':[('l',points[j],points[j+1]) for j in range(3)],'rect':fitz.Rect(xx if is_left else xx+inward,mr.y0-1,xx+inward if is_left else xx,mr.y1+1),'color':(0.7843,0.098,0.098),'width':0.4,'fill':None})
            lines.remove(l)
    bounds=fitz.Rect()
    for d in drawings:bounds|=d['rect']
    for l in lines:bounds|=fitz.Rect(l['bbox'])
    bx,by,bw,bh=box
    scale=min(bw/bounds.width,bh/bounds.height,1.9)
    ox=bx+(bw-bounds.width*scale)/2-bounds.x0*scale
    oy=by+(bh-bounds.height*scale)/2-bounds.y0*scale
    def point(p):return (ox+p.x*scale,oy+p.y*scale)
    sid=gid*1000;pieces=[]
    for d in drawings:
        sid+=1
        r=d['rect'];x,y=point(r.tl);w=max(r.width*scale,0.01);h=max(r.height*scale,0.01)
        def pt(p):return f'<a:pt x="{emu((p.x-r.x0)*scale)}" y="{emu((p.y-r.y0)*scale)}"/>'
        commands='';last=None
        for item in d['items']:
            kind=item[0]
            if kind in ['l','c']:
                start=item[1]
                if last is None or abs(last-start)>0.001:commands+='<a:moveTo>'+pt(start)+'</a:moveTo>'
                if kind=='l':commands+='<a:lnTo>'+pt(item[2])+'</a:lnTo>';last=item[2]
                else:commands+='<a:cubicBezTo>'+''.join(pt(p) for p in item[2:])+'</a:cubicBezTo>';last=item[-1]
            elif kind=='re':
                rr=item[1];commands+='<a:moveTo>'+pt(rr.tl)+'</a:moveTo>'+''.join('<a:lnTo>'+pt(p)+'</a:lnTo>' for p in [rr.tr,rr.br,rr.bl])+'<a:close/>';last=None
        if d.get('closePath'):commands+='<a:close/>'
        fill=solid(rgb(d['fill'])) if d.get('fill') else '<a:noFill/>'
        stroke=solid(rgb(d['color'])) if d.get('color') else '<a:noFill/>'
        width=max(0.2,(d.get('width') or 0)*scale)
        geom=f'<a:custGeom><a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/><a:rect l="0" t="0" r="r" b="b"/><a:pathLst><a:path w="{emu(w)}" h="{emu(h)}" fill="norm" stroke="1">{commands}</a:path></a:pathLst></a:custGeom>'
        pieces.append(f'<p:sp>{nv(sid,"Diagram block or connection "+str(sid))}<p:spPr>{xfrm((x,y,w,h))}{geom}{fill}<a:ln w="{emu(width)}">{stroke}<a:round/></a:ln></p:spPr></p:sp>')
    for l in lines:
        sid+=1;spans=l['spans'];text=''.join(s['text'] for s in spans)
        main=max(s['size'] for s in spans);base_y=min(s['origin'][1] for s in spans if s['size']>=main*.95)
        runs=[];hat=any('ˆ' in s['text'] for s in spans)
        for s in spans:
            t=s['text'].replace('ˆ','').replace('∆','Δ').replace('P IE','PIE')
            if not t:continue
            if hat and t in ['z','w']:t={'z':'ẑ','w':'ŵ'}[t];hat=False
            offset=s['origin'][1]-base_y
            baseline=-offset/main*100
            ismath=s['font'].startswith(('CM','MS'))
            runs.append((t,s['size']*scale,baseline,'CMMI' in s['font'],f'{s["color"]:06X}','Cambria Math' if ismath else 'Aptos'))
        r=fitz.Rect(l['bbox']);center=point((r.tl+r.br)*.5)
        fs=main*scale;w=max(r.width*scale*1.18,fs*.85)+4;h=max(r.height*scale,fs*1.35)+3
        pieces.append(textbox(sid,'Editable label: '+text.replace('∆','Δ').replace('ˆ','hat '),(center[0]-w/2,center[1]-h/2,w,h),runs,fs))
    gx=bx+(bw-bounds.width*scale)/2;gy=by+(bh-bounds.height*scale)/2;gw=bounds.width*scale;gh=bounds.height*scale
    return f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{gid}" name="Editable LFR diagram"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{emu(gx)}" y="{emu(gy)}"/><a:ext cx="{emu(gw)}" cy="{emu(gh)}"/><a:chOff x="{emu(gx)}" y="{emu(gy)}"/><a:chExt cx="{emu(gw)}" cy="{emu(gh)}"/></a:xfrm></p:grpSpPr>'+''.join(pieces)+'</p:grpSp>',bounds

rows=json.loads((B/'diagrams.json').read_text());pdf=fitz.open(B/'diagrams.pdf')
assert len(pdf)==len(rows)
unique=[];seen={}
for row,p in zip(rows,pdf):
    sig=hashlib.sha256(p.get_pixmap(matrix=fitz.Matrix(2,2),alpha=True).samples).hexdigest()
    if sig in seen:
        prev=seen[sig];prev['pdf_pages']=sorted(set(prev['pdf_pages']+row['pdf_pages']));prev['source_calls'].append(row['id']);continue
    row['source_calls']=[row['id']];row['page_index']=p.number;seen[sig]=row;unique.append(row)
    slug=f'{len(unique):02d}-'+row['name'].lower().replace(' - ','-').replace(' ','-')
    row['asset']=slug
    _,bounds=diagram_group(p,10,(72,94,576,252))
    crop=fitz.Rect(bounds.x0-5,bounds.y0-5,bounds.x1+5,bounds.y1+5)&p.rect
    one=fitz.open();one.insert_pdf(pdf,from_page=p.number,to_page=p.number)
    one[0].set_cropbox(crop)
    one.save(ASSETS/(slug+'.pdf'))
    (ASSETS/(slug+'.svg')).write_text(one[0].get_svg_image(text_as_path=True),encoding='utf-8')
    one[0].get_pixmap(matrix=fitz.Matrix(5,5),alpha=True).save(ASSETS/(slug+'.png'))

template=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\TUe - Clean White.potx')
with zipfile.ZipFile(template) as z:files={n:z.read(n) for n in z.namelist()}
files={n:b for n,b in files.items() if not n.startswith('ppt/slides/')}
groupbase='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
def slide(title,content,number,pages):
    shapes=plain(2,'Slide title',(36,30,648,40),title,25,bold=True)+content
    shapes+=plain(3,'Source PDF pages',(36,356,600,15),'Source PDF: '+pages,9,'747B82')
    shapes+=plain(4,'Footer',(36,384,400,12),'Msc Defence T.M. Lenssen',8,'747B82')+plain(5,'Slide number',(620,384,28,12),str(number),8,'747B82','r')
    return xml(f'<p:sld {DECL}><p:cSld><p:spTree>{groupbase}{shapes}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')
for i,row in enumerate(unique,1):
    group,_=diagram_group(pdf[row['page_index']],10,(72,94,576,252))
    files[f'ppt/slides/slide{i}.xml']=slide(row['name'],group,i,', '.join(map(str,row['pdf_pages'])))
    row['slide']=i
# Preserve the paired conversion composition from PDF page 44 as an extra slide.
i=len(unique)+1
left,_=diagram_group(pdf[8],10,(36,104,280,226));right,_=diagram_group(pdf[9],20,(404,104,280,226))
arrow=plain(6,'Conversion arrow',(326,183,68,48),'→',35)+plain(7,'Conversion label',(323,227,74,24),'convert',12,'747B82','ctr')
pair=f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="30" name="Editable PDE-to-PIE conversion"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{emu(36)}" y="{emu(104)}"/><a:ext cx="{emu(648)}" cy="{emu(226)}"/><a:chOff x="{emu(36)}" y="{emu(104)}"/><a:chExt cx="{emu(648)}" cy="{emu(226)}"/></a:xfrm></p:grpSpPr>{left}{arrow}{right}</p:grpSp>'
files[f'ppt/slides/slide{i}.xml']=slide('PDE-to-PIE conversion',pair,i,'44')
for n in range(1,i+1):files[f'ppt/slides/_rels/slide{n}.xml.rels']=xml(f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{NS["r"]}/slideLayout" Target="../slideLayouts/slideLayout12.xml"/></Relationships>')
for k,v in NS.items():E.register_namespace(k,v)
root=E.fromstring(files['ppt/presentation.xml']);lst=root.find('p:sldIdLst',NS);lst.clear()
for n in range(1,i+1):E.SubElement(lst,'{'+NS['p']+'}sldId',{'id':str(255+n),'{'+NS['r']+'}id':f'rIdSlide{n}'})
files['ppt/presentation.xml']=E.tostring(root,encoding='utf-8',xml_declaration=True)
files['ppt/_rels/presentation.xml.rels']=xml(f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{NS["r"]}/slideMaster" Target="slideMasters/slideMaster1.xml"/><Relationship Id="rIdTheme" Type="{NS["r"]}/theme" Target="theme/theme1.xml"/>'+''.join(f'<Relationship Id="rIdSlide{n}" Type="{NS["r"]}/slide" Target="slides/slide{n}.xml"/>' for n in range(1,i+1))+'</Relationships>')
ct=E.fromstring(files['[Content_Types].xml']);CT='http://schemas.openxmlformats.org/package/2006/content-types'
for child in list(ct):
    part=child.get('PartName','')
    if part.startswith('/ppt/slides/'):ct.remove(child)
    elif part=='/ppt/presentation.xml':child.set('ContentType','application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml')
for n in range(1,i+1):E.SubElement(ct,'{'+CT+'}Override',{'PartName':f'/ppt/slides/slide{n}.xml','ContentType':'application/vnd.openxmlformats-officedocument.presentationml.slide+xml'})
E.register_namespace('',CT)
files['[Content_Types].xml']=E.tostring(ct,encoding='utf-8',xml_declaration=True)
out=B/'LFR - Editable.pptx'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for n,b in files.items():z.writestr(n,b)
(B/'index.json').write_text(json.dumps(unique,indent=2),encoding='utf-8')
print('Created',out,'with',i,'slides;',len(unique),'individual diagrams.')
print('Distinct source calls:',[r['source_calls'] for r in unique])
