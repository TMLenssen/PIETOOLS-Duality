"""Stage a deck with high-density source artwork and editable label overlays.

Raster-only illustrations use native PowerPoint cover shapes under native labels;
source PDFs have their text removed before rendering. No source deck is overwritten.
"""
from pathlib import Path
from xml.dom import minidom
import sys,zipfile,json,hashlib,copy,math,re
from collections import Counter
import numpy as np
import pymupdf as fitz
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Presentation/HeatMoisture'))
import build_sequence as b
OUT=ROOT/'build/deck_label_overlays';OUT.mkdir(exist_ok=True,parents=True)
SOURCE=b.SOURCE
PKG='http://schemas.openxmlformats.org/package/2006/relationships'
def els(n,tag):return list(n.getElementsByTagName(tag))
def first(n,tag):return els(n,tag)[0]
def xml(s):return b.lib.xml(s)

class Overlay:
    def __init__(self,doc,pic,W,H,start):
        self.doc,self.pic,self.W,self.H,self.i=doc,pic,W,H,start
        xf=first(pic,'a:xfrm');off=first(xf,'a:off');ext=first(xf,'a:ext')
        self.x,self.y=[int(off.getAttribute(k))/12700 for k in ['x','y']]
        self.w,self.h=[int(ext.getAttribute(k))/12700 for k in ['cx','cy']]
        crop=els(pic,'a:srcRect');c={k:(int(crop[0].getAttribute(k) or 0)/1e5 if crop else 0) for k in ['l','r','t','b']}
        self.sx=self.w/(W*(1-c['l']-c['r']));self.sy=self.h/(H*(1-c['t']-c['b']))
        self.ox=self.x-W*c['l']*self.sx;self.oy=self.y-H*c['t']*self.sy
        self.parts=[];self.count=0
    def id(self):self.i+=1;return self.i
    def point(self,x,y):return self.ox+x*self.sx,self.oy+y*self.sy
    def box(self,box):
        x0,y0,x1,y1=box;x,y=self.point(x0,y0);return x,y,(x1-x0)*self.sx,(y1-y0)*self.sy
    def rect(self,box,color='FFFFFF',right=None):
        f=b.fill(color)
        if right:f=f'<a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0">'+f'<a:srgbClr val="{color}"/></a:gs><a:gs pos="100000"><a:srgbClr val="{right}"/></a:gs></a:gsLst><a:lin ang="0" scaled="1"/></a:gradFill>'
        self.parts.append(f'<p:sp>{b.nv(self.id(),"Label background")}<p:spPr>{b.xf(*self.box(box))}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{f}<a:ln><a:noFill/></a:ln></p:spPr></p:sp>')
    def text(self,text,x,y,size=14,color='333333',mathmode=False,bold=False,angle=0,width=None,mask=None,name=None):
        if mask:self.rect(mask)
        xx,yy=self.point(x,y);fs=size*self.sy
        ww=(width or max(size*1.0,len(text)*size*.60))*self.sx;hh=fs*1.8
        shape=b.lib.tb(self.id(),name or ('Editable label '+text),(xx-ww/2,yy-hh/2,ww,hh),text,fs,color,'Arial',bold=bold)
        if mathmode:
            m=b.Math(fs,color)
            eq='<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+m.r(text,plain=mathmode=='plain' or text.replace('.','').replace('-','').isdigit())+'</m:oMath></m:oMathPara></a14:m>'
            shape=re.sub(r'<a:r>.*?</a:r>',lambda _:eq,shape)
        if angle:shape=shape.replace('<a:xfrm>',f'<a:xfrm rot="{round(angle*60000)%21600000}">',1)
        self.parts.append(shape);self.count+=1
    def equation(self,name,x,y,body,size=15,width=160,angle=0,color='333333'):
        xx,yy=self.point(x,y);fs=size*self.sy;m=b.Math(fs,color)
        shape=b.lib.tb(self.id(),name,(xx-width*self.sx/2,yy-fs*1.8,width*self.sx,fs*3.6),'',fs,color)
        eq='<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+body(m)+'</m:oMath></m:oMathPara></a14:m>'
        shape=re.sub(r'<a:r>.*?</a:r>',lambda _:eq,shape)
        if angle:shape=shape.replace('<a:xfrm>',f'<a:xfrm rot="{round(angle*60000)%21600000}">',1)
        self.parts.append(shape);self.count+=1
    def pdf_labels(self,spans):
        for s in spans:
            txt=s['text'];x0,y0,x1,y1=s['bbox'];dx,dy=s['dir']
            vertical=abs(dy)>.1;angle=math.degrees(math.atan2(dy,dx))
            ismath=not any(v in s['font'].lower() for v in ['arial','helvetica','cmss','lmsans'])
            if ismath and any(v in s['font'].lower() for v in ['cmr','lmroman']):ismath='plain'
            width=((y1-y0) if vertical else (x1-x0))+s['size']*.25
            self.text(txt,(x0+x1)/2,(y0+y1)/2,s['size'],f"{s['color']:06X}",ismath,'bold' in s['font'].lower(),angle,width)
    def finish(self):
        # Keep the original shape ID on the group, so existing animation targets survive.
        original=first(self.pic,'p:cNvPr');oldid=original.getAttribute('id');name=original.getAttribute('name')
        original.setAttribute('id',str(self.id()))
        group=f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{oldid}" name="Editable image and labels"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{b.emu(self.x)}" y="{b.emu(self.y)}"/><a:ext cx="{b.emu(self.w)}" cy="{b.emu(self.h)}"/><a:chOff x="{b.emu(self.x)}" y="{b.emu(self.y)}"/><a:chExt cx="{b.emu(self.w)}" cy="{b.emu(self.h)}"/></a:xfrm></p:grpSpPr>'+self.pic.toxml()+''.join(self.parts)+'</p:grpSp>'
        node=minidom.parseString(f'<root {b.DECL}>'+group+'</root>').documentElement.firstChild
        first(node,'p:cNvPr').setAttribute('name',name+' — editable labels')
        self.pic.parentNode.replaceChild(self.doc.importNode(node,True),self.pic)

def clean_pdf(path,page=0):
    doc=fitz.open(path);pg=doc[page];spans=[]
    for block in pg.get_text('dict')['blocks']:
        for line in block.get('lines',[]):
            for s in line['spans']:
                if not s['text'].strip():continue
                spans.append(dict(text=s['text'],bbox=s['bbox'],size=s['size'],font=s['font'],color=s['color'],dir=line['dir']))
                pg.add_redact_annot(s['bbox'],fill=False,cross_out=False)
    assert spans,(path,page,'No removable PDF text')
    pg.apply_redactions(images=0,graphics=0,text=0)
    assert not pg.get_text().strip(),(path,page,'Text remains')
    scale=4096/pg.rect.width
    return pg.get_pixmap(matrix=fitz.Matrix(scale,scale),alpha=True).tobytes('png'),pg.rect.width,pg.rect.height,spans

def raster_labels(o,key):
    if key=='image8.jpg':
        for txt,x,y,size,box in [('BASAL GANGLIA',800,251,89,(375,205,1228,298)),('FRONTAL LOBE',322,427,36,(178,407,468,447)),('BASAL GANGLIA',1251,427,36,(1099,407,1411,447)),('THALAMUS',1288,492,36,(1174,473,1400,513))]:
            o.text(txt,x,y,size,'30354D',bold=True,mask=box)
    elif key=='image9.png':
        o.rect((1218,63,1359,101),'FFFDF9');o.text('Drying air',1289,83,29,'ED492D')
        o.rect((1391,204,1557,244),'FFFEFA');o.text('Evaporation',1475,224,28,'1684F6')
        # Native gradient patches follow the layer colours beneath the two labels.
        o.rect((373,307,446,340),'FA6048','FA6B51');o.text('Heat',409,325,24,'FFFFFF')
        o.rect((356,341,476,373),'2482FD','4091FE');o.text('Moisture',416,358,24,'FFFFFF')
    elif key=='image3.png':
        labels=[]
        for cx,txt in [(700,'(a) Open-loop response'),(1300,'(b) Closed-loop response')]:
            o.text(txt,cx,54,27,mask=(cx-170,37,cx+180,76))
        # Labels lie outside the projected surfaces; masks preserve all plotted data.
        for shift in [0,602]:
            vals=[('0',446,318),('5',478,336),('10',503,355),('15',536,373),('t = 20',548,391),('25',602,409),('30',634,426),('35',666,444),('0',718,443),('0.25',794,412),('s = 0.5',869,380),('0.75',909,348),('(1,0)',970,302),('2',946,246),('-2',951,359)]
            for txt,x,y in vals:
                if shift and txt=='2':y-=25
                if shift and txt=='-2':y+=24
                labels.append((txt,x+shift,y))
        # Cover every original label before placing any replacement to avoid
        # an adjacent cover clipping a previously added native tick label.
        o.rect((934,225,1004,381));o.rect((1536,201,1610,400))
        for txt,x,y in labels:
            ww=len(txt)*14+12;o.rect((x-ww/2,y-17,x+ww/2,y+17))
        for txt,x,y in labels:o.text(txt,x,y,22,mathmode=True)
        for txt,x in [('-2',551),('x(t,s) = 0',701),('2',850),('-2',1091),('x(t,s) = 0',1302),('2',1507)]:
            ww=len(txt)*14+8;o.text(txt,x,603,25,mathmode=True,mask=(x-ww/2,584,x+ww/2,623))

def heat_art():
    # Exact modal propagation of the existing 99-interior-point finite difference model.
    N=99;v=np.arange(1,N+1);V=np.sqrt(2/(N+1))*np.sin(np.pi*np.outer(v,v)/(N+1));weights=(V.sum(axis=0)**2)/100
    eig=-4*10000*np.sin(np.pi*v/(2*(N+1)))**2
    t=np.linspace(0,30,601);ys=[]
    for delta in np.linspace(-.5,.5,11):
        lam=.01*eig+.25*(1+delta)-.2
        u=2*np.expm1(np.minimum(t,8)[:,None]*lam)/lam*np.exp(np.maximum(t-8,0)[:,None]*lam)
        ys.append(u@weights)
    ys=np.array(ys);assert 90<ys[-1,-1]<100
    doc=fitz.open();pg=doc.new_page(width=951,height=568)
    def p(a,v):return (50+a/30*809,529-v/100*524)
    for val in range(0,101,10):pg.draw_line(p(0,val),p(30,val),color=(.86,.86,.86),width=.6)
    for val in range(0,31,5):pg.draw_line(p(val,0),p(val,100),color=(.86,.86,.86),width=.6)
    pg.draw_polyline([(50,5),(50,529),(859,529)],color=(.2,.2,.2),width=.8)
    labels=[];endpoint=ys[:,-1];ly=endpoint.copy();ly[0]=max(ly[0],2)
    for j in range(1,11):ly[j]=max(ly[j],ly[j-1]+3.8)
    for j,delta in enumerate(np.linspace(-.5,.5,11)):
        col=(.9,.12,.12) if delta>.1948 else (.08,.36,.64)
        pg.draw_polyline([p(a,v) for a,v in zip(t,ys[j])],color=col,width=1.8)
        pg.draw_polyline([p(30,endpoint[j]),(891,p(30,ly[j])[1])],color=col,width=.7)
        labels.append((delta,p(30,ly[j])[1],''.join(f'{round(c*255):02X}' for c in col)))
    return pg.get_pixmap(matrix=fitz.Matrix(4096/951,4096/951),alpha=True).tobytes('png'),labels

def main():
    with zipfile.ZipFile(SOURCE) as z:files={n:z.read(n) for n in z.namelist()}
    originals=files.copy();report=[]
    pdfmap={'image12.png':(ROOT/'Figures/HeatedRod/build/uncertain_heated_rod.pdf',0), 'image26.png':(ROOT/'Figures/STN_GPe/stn_healthy_input_spikes.pdf',0),'image27.png':(ROOT/'Figures/STN_GPe/stn_parkinsonian_stimulation.pdf',0)}
    for img,page in [(16,6),(18,3),(20,1),(22,2),(24,4),(25,7),(28,8)]:pdfmap[f'image{img}.png']=(OUT/'stn_proto_overlay_set.pdf',page)
    sources={}
    for name,(path,page) in pdfmap.items():
        png,W,H,spans=clean_pdf(path,page);files['ppt/media/'+name]=png;sources[name]=(W,H,spans)
        (OUT/('clean_'+name)).write_bytes(png)
    png,heatlabels=heat_art();files['ppt/media/image11.png']=png
    for n in list(files):
        if not re.match(r'ppt/slides/slide\d+\.xml$',n):continue
        doc=minidom.parseString(files[n]);snum=int(re.search(r'slide(\d+)',n)[1]);rels=minidom.parseString(files[n.replace('/slides/','/slides/_rels/')+'.rels'])
        rmap={r.getAttribute('Id'):b.posixpath.normpath('ppt/slides/'+r.getAttribute('Target')) for r in els(rels,'Relationship')}
        ident=max(int(x.getAttribute('id')) for x in els(doc,'p:cNvPr'))+100
        changed=False
        for pic in list(els(doc,'p:pic')):
            if els(pic,'a:videoFile'):continue
            blips=els(pic,'a:blip')
            if not blips:continue
            key=Path(rmap.get(blips[0].getAttribute('r:embed'),'')).name
            if key in sources:
                W,H,spans=sources[key];o=Overlay(doc,pic,W,H,ident);o.pdf_labels(spans)
            elif key in ['image8.jpg','image9.png','image3.png']:
                W,H={'image8.jpg':(1600,1600),'image9.png':(1600,535),'image3.png':(2048,1152)}[key]
                o=Overlay(doc,pic,W,H,ident);raster_labels(o,key)
            elif key=='image11.png':
                o=Overlay(doc,pic,951,568,ident)
                for v in range(0,101,10):o.text(str(v),32,529-v/100*524,12)
                for v in range(0,31,5):o.text(str(v),50+v/30*809,545,12)
                o.text('t',454,562,14,mathmode=True);o.text('Average temperature',9,267,14,angle=-90)
                for delta,y,col in heatlabels:o.equation('Reaction uncertainty',922,y,lambda m,d=delta:m.r('δ=')+m.r(f'{d:.1f}',plain=True),13,width=64,color=col)
            else:continue
            count=o.count;o.finish();ident=o.i+10;changed=True;report.append(dict(slide=snum,image=key,labels=count))
        if changed:
            root=doc.documentElement
            for prefix,uri in b.NS.items():root.setAttribute('xmlns:'+prefix,uri)
            ignore=set(root.getAttribute('mc:Ignorable').split());ignore.add('a14');root.setAttribute('mc:Ignorable',' '.join(sorted(ignore)))
            files[n]=doc.toxml(encoding='utf-8')
    # Lossless source checks: notes, animation timing, transitions, and every video.
    for n,v in originals.items():
        if n.startswith('ppt/notes') or n.endswith(('.mp4','.wmv','.gif')):assert files[n]==v,n
        if re.match(r'ppt/slides/slide\d+\.xml$',n):
            old=minidom.parseString(v);new=minidom.parseString(files[n])
            for tag in ['p:timing','p:transition']:assert [x.toxml() for x in els(old,tag)]==[x.toxml() for x in els(new,tag)],(n,tag)
            before=Counter(x.getAttribute('id') for x in els(old,'p:cNvPr'))
            after=Counter(x.getAttribute('id') for x in els(new,'p:cNvPr'))
            assert all(count<=max(1,before[ident]) for ident,count in after.items()),n
    dest=OUT/SOURCE.name
    with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as z:
        for n,v in files.items():z.writestr(n,v)
    manifest=dict(source=str(SOURCE),source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),output=str(dest),changes=report,total_labels=sum(r['labels'] for r in report))
    (OUT/'report.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
