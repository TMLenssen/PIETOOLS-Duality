"""Append paper Figures 2, 3 and 5 as editable PowerPoint shapes.

Run from the paper workspace. The external master is read only; output is staged
in build/paper_lfr for validation and visual inspection before installation.
"""
from pathlib import Path
from xml.sax.saxutils import escape, quoteattr
from xml.dom import minidom
import zipfile, hashlib, json

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'build/paper_lfr'
MASTER = Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\LFR - Editable.pptx')
NS = {'p':'http://schemas.openxmlformats.org/presentationml/2006/main',
      'a':'http://schemas.openxmlformats.org/drawingml/2006/main',
      'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
DECL = ' '.join(f'xmlns:{k}="{v}"' for k,v in NS.items())
INK, RED, GRAY = '252529', 'D61016', '747B82'
def emu(x): return str(round(x * 12700))
def xml(s): return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+s).encode()
def fill(c): return f'<a:solidFill><a:srgbClr val="{c}"/></a:solidFill>'
def xf(x,y,w,h): return f'<a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(w)}" cy="{emu(h)}"/></a:xfrm>'
def nv(i,n): return f'<p:nvSpPr><p:cNvPr id="{i}" name={quoteattr(n)}/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
def run(t,base=0,under=False,bold=False,italic=None):
    if italic is None:italic=any(c in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZερℐ' for c in t)
    return dict(t=t,base=base,under=under,bold=bold,italic=italic)
def sym(t,sub=None,top=False,under=False):
    r=[run(t,under=under)]
    if sub:r.append(run(sub,-25,italic=sub!='G'))
    if top:r.append(run('⊤',35,italic=False))
    return r
def tb(i,n,box,runs,size=18,color=INK,font='Cambria Math',bold=False,white=False):
    if isinstance(runs,str):runs=[run(runs,italic=None if font=='Cambria Math' else False)]
    rs=''
    for r in runs:
        fs=size*(.70 if r['base'] else 1)
        rs+=f'<a:r><a:rPr lang="en-GB" sz="{round(fs*100)}" baseline="{r["base"]*1000}" b="{int(bold or r["bold"])}" i="{int(r["italic"])}" u="{"sng" if r["under"] else "none"}">{fill(color)}<a:latin typeface="{font}"/><a:ea typeface="{font}"/><a:cs typeface="{font}"/></a:rPr><a:t xml:space="preserve">{escape(r["t"])}</a:t></a:r>'
    return f'<p:sp>{nv(i,n)}<p:spPr>{xf(*box)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{fill("FFFFFF") if white else "<a:noFill/>"}<a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="none" lIns="0" tIns="0" rIns="0" bIns="0" anchor="ctr"><a:noAutofit/></a:bodyPr><a:lstStyle/><a:p><a:pPr algn="ctr"><a:buNone/></a:pPr>{rs}<a:endParaRPr sz="{round(size*100)}"/></a:p></p:txBody></p:sp>'

class Diagram:
    def __init__(self): self.parts=[]; self.i=100
    def add(self,s): self.parts.append(s)
    def ident(self): self.i+=1;return self.i
    def text(self,n,x,y,r,size=18,w=60,color=INK,font='Cambria Math',white=False):
        self.add(tb(self.ident(),n,(x-w/2,y-size*.75,w,size*1.5),r,size,color,font,white=white))
    def path(self,n,pts,arrow=True,color=INK,width=1):
        assert all(x==xx or y==yy for (x,y),(xx,yy) in zip(pts,pts[1:])), n
        # Real padding prevents PowerPoint stretching a near-zero bounding box.
        x=min(p[0] for p in pts)-1;y=min(p[1] for p in pts)-1
        w=max(p[0] for p in pts)-x+1;h=max(p[1] for p in pts)-y+1
        commands=''.join(f'<a:{"moveTo" if j==0 else "lnTo"}><a:pt x="{emu(px-x)}" y="{emu(py-y)}"/></a:{"moveTo" if j==0 else "lnTo"}>' for j,(px,py) in enumerate(pts))
        geom=f'<a:custGeom><a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/><a:rect l="0" t="0" r="r" b="b"/><a:pathLst><a:path w="{emu(w)}" h="{emu(h)}" fill="none">{commands}</a:path></a:pathLst></a:custGeom>'
        self.add(f'<p:sp>{nv(self.ident(),n)}<p:spPr>{xf(x,y,w,h)}{geom}<a:noFill/><a:ln w="{emu(width)}">{fill(color)}<a:round/>{"<a:tailEnd type=\"triangle\" w=\"sm\" len=\"sm\"/>" if arrow else ""}</a:ln></p:spPr></p:sp>')
    def block(self,n,x,y,w,h,label,size=23,red=False,dashed=False):
        c=RED if red else INK
        self.add(f'<p:sp>{nv(self.ident(),n)}<p:spPr>{xf(x-w/2,y-h/2,w,h)}<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 5000"/></a:avLst></a:prstGeom>{fill("FFFFFF")}<a:ln w="{emu(.85)}">{fill(c)}{"<a:prstDash val=\"dash\"/>" if dashed else ""}</a:ln></p:spPr></p:sp>')
        self.text(n+' label',x,y,label,size,w=w,color=c)
    def group(self):
        return f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="10" name="Editable paper diagram"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{emu(36)}" y="{emu(85)}"/><a:ext cx="{emu(648)}" cy="{emu(264)}"/><a:chOff x="{emu(36)}" y="{emu(85)}"/><a:chExt cx="{emu(648)}" cy="{emu(264)}"/></a:xfrm></p:grpSpPr>'+''.join(self.parts)+'</p:grpSp>'

def filtered(d,ox,oy,s,dual=False,controller=False):
    # Coordinates follow primal_dual_controller_interconnections.tex exactly.
    mirror=-1 if dual else 1
    def p(x,y):return ox+mirror*x*s,oy-y*s
    def path(n,coords,reverse=False):
        pp=[p(*v) for v in coords];d.path(n,pp[::-1] if reverse else pp,width=max(.75,s/75))
    def label(n,x,y,r,w=.6):d.text(n,*p(x,y),r,size=s*.27,w=w*s)
    def block(n,x,y,a,b,r,red=False):d.block(n,*p(x,y),a*s,b*s,r,size=s*.35,red=red,dashed=red)
    plant='G' if controller else 'P';flt='Ψ' if controller and not dual else 'Θ'
    path('Plant to uncertainty',[(-.5,0),(-1.12,0),(-1.12,.94),(-.3,.94)])
    path('Uncertainty to plant',[(.3,.94),(1.12,.94),(1.12,0),(.5,0)])
    path('z filter input',[(-.82,.94),(-.82,1.52),(1.4,1.52)])
    path('w filter input',[(.82,.94),(.82,1.12),(1.4,1.12)])
    for yy,t in [(1.52,'z'),(1.12,'w')]:
        path(t+' filtered output',[(2.4,yy),(3.02,yy)])
        label('Filtered '+t,3.27,yy,sym(t+'\u0303',under=dual),.45)
    if controller:
        path('Controller plant channel',[(-.36,-.96),(-1.12,-.96),(-1.12,-.25),(-.5,-.25)],reverse=dual)
        path('Plant controller channel',[(.5,-.25),(1.12,-.25),(1.12,-.83),(.36,-.83)],reverse=dual)
        path('Filter controller channel',[(1.9,.82),(1.9,-1.09),(.36,-1.09)],reverse=dual)
        # In the dual drawing the single y channel joins the controller centre,
        # while the u_G branch joins the upper controller input (mirrored).
        if dual:
            d.parts=d.parts[:-3]
            path('Dual plant output',[(-.5,-.25),(-1.12,-.25),(-1.12,-.96),(-.36,-.96)])
            path('Dual plant input',[(.36,-.83),(1.12,-.83),(1.12,-.25),(.5,-.25)])
            path('Dual filter input',[(.36,-1.09),(1.9,-1.09),(1.9,.82)])
        block('Controller',0,-.96,.72,.72,sym('K',top=dual))
        label('Controller external channel',-1.36,-.62,sym('y' if dual else 'u',under=dual))
        label('Plant measured channel',1.38,-.54,sym('u' if dual else 'y','G',under=dual))
        label('Filter measured channel',2.23,-.28,sym('u' if dual else 'y','Θ' if dual else 'Ψ',under=dual))
    label('Uncertainty output channel',-1.35,.46,sym('z',under=dual))
    label('Uncertainty input channel',1.35,.46,sym('w',under=dual))
    block('Uncertainty',0,.94,.6,.6,sym('Δ',under=dual),True)
    block('Plant',0,0,1,1,sym(plant,top=dual))
    fr=[run('D',bold=True,italic=False),run('(Θ)',italic=False)] if dual else sym(flt)
    block('Dynamic filter',1.9,1.32,1,1,fr)

def condition(dual=False,pg=False):
    w=sym('w\u0303' if pg else 'w',under=dual)
    p=sym('p','T')
    if pg:
        return [run('‖')]+p+sym('G','0',top=dual)+w+[run('‖'),run('2',35),run(' ≤ '),run('ρ'),run('‖')]+p+w+[run('‖'),run('2',35)]
    return [run('ℐ',under=dual),run(' ≤ −'),run('ε',under=dual),run('‖')]+p+w+[run('‖'),run('2',35)]

def equivalence():
    d=Diagram()
    filtered(d,145,160,37)
    filtered(d,263,294,37,dual=True)
    for y,dual in [(142,False),(277,True)]:
        d.path('Gain input',[(481,y),(517,y)])
        d.path('Gain output',[(563,y),(599,y)])
        d.block('Dual gain block' if dual else 'Primal gain block',540,y,46,46,sym('G','0',top=dual),20)
        d.text('Gain input label',467,y,sym('w\u0303',under=dual),14,w=24,white=True)
        d.text('Gain output label',613,y,sym('z\u0303',under=dual),14,w=24,white=True)
        d.text('Filter condition',205,y+53,condition(dual),14,w=270)
        d.text('Gain condition',540,y+53,condition(dual,True),14,w=270)
        d.text('Filtering equivalence',374,y,'⇔',30,w=55)
        d.text('Filtering theorem',374,y-24,'Theorem 3',10,w=75,font='Aptos',color=GRAY)
    d.text('Gain duality',540,228,'⇕',23,w=40)
    d.text('Gain duality theorem',598,218,'Theorem 2',10,w=67,font='Aptos',color=GRAY)
    d.text('Common strict bound',601,234,'∃ ρ < 1',12,w=67)
    return d

def slide(title,diagram,n,figure):
    shapes=tb(2,'Slide title',(36,30,648,40),title,25,font='Aptos',bold=True)
    # Keep titles left-aligned, matching the existing library.
    shapes=shapes.replace('algn="ctr"','algn="l"')+diagram.group()
    shapes+=tb(3,'Source',(36,356,600,15),f'Source paper: Figure {figure}',9,GRAY,'Aptos').replace('algn="ctr"','algn="l"')
    shapes+=tb(4,'Footer',(36,384,400,12),'Msc Defence T.M. Lenssen',8,GRAY,'Aptos').replace('algn="ctr"','algn="l"')
    shapes+=tb(5,'Slide number',(620,384,28,12),str(n),8,GRAY,'Aptos')
    return xml(f'<p:sld {DECL}><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>{shapes}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(MASTER) as z:files={n:z.read(n) for n in z.namelist()}
    before=dict(files)
    primal=Diagram();filtered(primal,280,235,74,controller=True)
    dual=Diagram();filtered(dual,440,235,74,dual=True,controller=True)
    rows=[(17,2,'Primal controller interconnection',primal),
          (18,3,'Primal and dual dynamic filtering',equivalence()),
          (19,5,'Dual controller interconnection',dual)]
    pres=minidom.parseString(files['ppt/presentation.xml'])
    lst=pres.getElementsByTagNameNS(NS['p'],'sldIdLst')[0]
    assert len(lst.getElementsByTagNameNS(NS['p'],'sldId'))==16, 'Expected original 16-slide master'
    rel=minidom.parseString(files['ppt/_rels/presentation.xml.rels'])
    ct=minidom.parseString(files['[Content_Types].xml'])
    ids=[int(n.getAttribute('id')) for n in lst.getElementsByTagNameNS(NS['p'],'sldId')]
    for n,fig,title,d in rows:
        files[f'ppt/slides/slide{n}.xml']=slide(title,d,n,fig)
        files[f'ppt/slides/_rels/slide{n}.xml.rels']=files['ppt/slides/_rels/slide16.xml.rels']
        rid=f'rIdPaper{n}'
        node=pres.createElementNS(NS['p'],'p:sldId');node.setAttribute('id',str(max(ids)+n-16));node.setAttributeNS(NS['r'],'r:id',rid);lst.appendChild(node)
        node=rel.createElement('Relationship');node.setAttribute('Id',rid);node.setAttribute('Type',NS['r']+'/slide');node.setAttribute('Target',f'slides/slide{n}.xml');rel.documentElement.appendChild(node)
        node=ct.createElement('Override');node.setAttribute('PartName',f'/ppt/slides/slide{n}.xml');node.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');ct.documentElement.appendChild(node)
    for path,doc in [('ppt/presentation.xml',pres),('ppt/_rels/presentation.xml.rels',rel),('[Content_Types].xml',ct)]:files[path]=doc.toxml(encoding='utf-8')
    with zipfile.ZipFile(OUT/'LFR - Editable.pptx','w',zipfile.ZIP_DEFLATED) as z:
        for n,b in files.items():z.writestr(n,b)
    assert all(files[n]==b for n,b in before.items() if n.startswith('ppt/slides/'))
    manifest=[dict(slide=n,figure=f,name=t,asset=f'{n:02d}-paper-figure-{f}') for n,f,t,d in rows]
    (OUT/'manifest.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256(MASTER.read_bytes()).hexdigest(),diagrams=manifest),indent=2))
    print('Staged 19-slide library; all original slide parts preserved byte-for-byte.')

if __name__=='__main__':main()
