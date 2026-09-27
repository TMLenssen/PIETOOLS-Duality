"""Increase native overlay text in the current deck without regenerating media."""
from pathlib import Path
from xml.dom import minidom as D
import zipfile,json,hashlib,re,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import SOURCE,els,first
OUT=ROOT/'build/larger_labels';OUT.mkdir(exist_ok=True)
def geometry(sp):
    xf=first(sp,'a:xfrm');off=first(xf,'a:off');ext=first(xf,'a:ext')
    return off,ext,*[int(off.getAttribute(k))/12700 for k in ['x','y']],*[int(ext.getAttribute(k))/12700 for k in ['cx','cy']]
def resize(sp,factor,cx=None,cy=None):
    off,ext,x,y,w,h=geometry(sp);cx=x+w/2 if cx is None else cx;cy=y+h/2 if cy is None else cy
    for tag in ['a:rPr','a:defRPr','a:endParaRPr']:
        for r in els(sp,tag):
            if r.hasAttribute('sz'):r.setAttribute('sz',str(round(int(r.getAttribute('sz'))*factor)))
    off.setAttribute('x',str(round((cx-w*factor/2)*12700)));off.setAttribute('y',str(round((cy-h*factor/2)*12700)))
    ext.setAttribute('cx',str(round(w*factor*12700)));ext.setAttribute('cy',str(round(h*factor*12700)))
def fontsize(sp):
    mathruns=els(sp,'m:r');runs=[r for m in mathruns for r in els(m,'a:rPr')] if mathruns else els(sp,'a:rPr')
    return max([int(r.getAttribute('sz'))/100 for r in runs if r.hasAttribute('sz')] or [0])
def main():
    with zipfile.ZipFile(SOURCE) as z:files={n:z.read(n) for n in z.namelist()}
    original=files.copy();report=[]
    special=('Moving ','Rigid cart','Rigid cart drive','Flexible beam','Clamped and free','Free shear','Flexible cart drive','Horizontal axis','Vertical axis','Response legend','Reaction uncertainty')
    for n,v in list(files.items()):
        if not re.match(r'ppt/slides/slide\d+\.xml$',n):continue
        num=int(re.search(r'slide(\d+)',n)[1]);d=D.parseString(v);candidates=[]
        for sp in els(d,'p:sp'):
            name=first(sp,'p:cNvPr').getAttribute('name');size=fontsize(sp)
            if size<=0 or not name.startswith(('Editable label',)+special):continue
            if name.startswith('Editable label') and size>=12:continue
            target=max(size*1.18,8.5)
            if num==1:target=max(size*1.18,7.3)
            elif num==3:target=max(size,7.5)
            elif num==4:target=max(size,7)
            elif num==2:target=max(size,9)
            elif num==39:target=max(size*1.2,10)
            if target<=size+.1:continue
            candidates.append(dict(sp=sp,name=name,size=size,target=target,geo=geometry(sp)[2:]))
        # Treat tightly spaced PDF fragments as one label, preserving subscripts.
        groups=[]
        for c in candidates:
            x,y,w,h=c['geo'];match=None
            for group in groups:
                for a in group:
                    xx,yy,ww,hh=a['geo']
                    gap=max(xx-x-w,x-xx-ww,0)
                    if a['sp'].parentNode is c['sp'].parentNode and gap<1.7 and abs(y+h/2-yy-hh/2)<max(c['size'],a['size'])*.8:
                        match=group;break
                if match is not None:break
            if match is None:groups.append([c])
            else:match.append(c)
        for group in groups:
            left=min(c['geo'][0] for c in group);right=max(c['geo'][0]+c['geo'][2] for c in group)
            cx=(left+right)/2;cy=sum(c['geo'][1]+c['geo'][3]/2 for c in group)/len(group)
            factor=max(c['target']/c['size'] for c in group)
            # Keep subscript fragments proportional to the main glyph.
            if len(group)>1:factor=max(c['target'] for c in group)/max(c['size'] for c in group)
            for c in group:
                x,y,w,h=c['geo'];nx=cx+(x+w/2-cx)*factor;ny=cy+(y+h/2-cy)*factor
                name=c['name']
                if num==39 and name.startswith('Response legend'):ny+=(-2 if name.endswith('S') else 2);nx+=8
                if num==4 and name=='Editable label Average temperature':nx-=8
                if num==4 and name.startswith('Reaction uncertainty'):nx+=8
                if num==3 and name=='Editable label Heat':ny-=4
                if num==3 and name=='Editable label Moisture':ny+=4
                resize(c['sp'],factor,nx,ny);report.append(dict(slide=num,name=name,before=c['size'],after=round(c['size']*factor,2)))
        if candidates:files[n]=d.toxml(encoding='utf-8')
    for n,v in original.items():
        if n.startswith(('ppt/notes','ppt/media/')):assert files[n]==v,n
    dest=OUT/SOURCE.name
    with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as z:
        for n,v in files.items():z.writestr(n,v)
    (OUT/'report.json').write_text(json.dumps(dict(source=str(SOURCE),source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),output=str(dest),changes=report),indent=2))
    print(f'Enlarged {len(report)} native label shapes; all notes and media preserved.')
if __name__=='__main__':main()
