"""Native PowerPoint sector -> quadratic supply -> hard IQC visualization."""
from pathlib import Path
from xml.dom import minidom
import importlib.util,zipfile,math,json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/sector_iqc';OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('base',ROOT/'Presentation/HeatMoisture/build_sequence.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
INK=b.INK;RED='D61016';BLUE='216F9C';GREEN='147C60';GRAY=b.GRAY

class M(b.Math):
    def signal(self,t,args=True,color=None):
        return self.sub(self.r(t,color),self.r('Δ',color,True))+(self.d(self.r('t,s')) if args else '')
    def vector(self):return self.d(self.matrix([[self.signal('z')],[self.signal('w')]]),'[',']')
    def matrix(self,rows):
        cells=len(rows[0])
        return '<m:m><m:mPr><m:mcs><m:mc><m:mcPr><m:count m:val="'+str(cells)+'"/><m:mcJc m:val="center"/></m:mcPr></m:mc></m:mcs>'+self.ctrl()+'</m:mPr>'+''.join('<m:mr>'+''.join('<m:e>'+e+'</m:e>' for e in row)+'</m:mr>' for row in rows)+'</m:m>'
    def mult(self):return self.sub(self.r('𝒱'),self.r('Δ',plain=True))
    def x(self):return self.r('x')+self.d(self.r('t,s'))
    def q(self):return self.r('q',GREEN)+self.d(self.r('t,s'))
    def integral(self):
        def integ(lo,hi,e):return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+self.ctrl()+'</m:naryPr><m:sub>'+self.r(lo)+'</m:sub><m:sup>'+self.r(hi)+'</m:sup><m:e>'+e+'</m:e></m:nary>'
        return integ('0','T',integ('a','b',self.q()+self.r(' ds dt')))

class Slide(b.Slide):
    def equation(self,name,x,y,fn,size=18,w=640,color=INK):
        m=M(size,color);body=fn(m)
        shape=b.lib.tb(self.ident(),name,(x-w/2,y-size*1.4,w,size*2.8),'',size)
        eq='<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+body+'</m:oMath></m:oMathPara></a14:m>'
        self.add(b.re.sub(r'<a:r>.*?</a:r>',eq,shape))
    def poly(self,name,pts,color=INK,width=1,filled=None):
        x=min(p[0] for p in pts)-1;y=min(p[1] for p in pts)-1
        w=max(p[0] for p in pts)-x+1;h=max(p[1] for p in pts)-y+1
        cmds=''.join(f'<a:{"moveTo" if i==0 else "lnTo"}><a:pt x="{b.emu(px-x)}" y="{b.emu(py-y)}"/></a:{"moveTo" if i==0 else "lnTo"}>' for i,(px,py) in enumerate(pts))
        if filled:cmds+='<a:close/>'
        geom=f'<a:custGeom><a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/><a:rect l="0" t="0" r="r" b="b"/><a:pathLst><a:path w="{b.emu(w)}" h="{b.emu(h)}" fill="{"norm" if filled else "none"}">{cmds}</a:path></a:pathLst></a:custGeom>'
        self.add(f'<p:sp>{b.nv(self.ident(),name)}<p:spPr>{b.xf(x,y,w,h)}{geom}{b.fill(filled) if filled else "<a:noFill/>"}<a:ln w="{b.emu(width)}">{b.fill(color) if width else "<a:noFill/>"}</a:ln></p:spPr></p:sp>')
    def dot(self,x,y):
        self.add(f'<p:sp>{b.nv(self.ident(),"Sample point") }<p:spPr>{b.xf(x-2.5,y-2.5,5,5)}<a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>{b.fill(RED)}<a:ln><a:noFill/></a:ln></p:spPr></p:sp>')

def plot(s,stage):
    def p(z,w):return 192+67*z,172-34*w
    for sign in (-1,1):s.poly('Admissible sector', [p(0,0),p(sign*1.8,sign*1.8*.2),p(sign*1.8,sign*1.8*1.2)],filled='EDF2F5',width=0)
    s.path('Input axis',[p(-1.95,0),p(2.02,0)],color='A9ADB2',width=.65)
    s.path('Output axis',[p(0,-2.35),p(0,2.38)],color='A9ADB2',width=.65)
    for k in (.2,1.2):s.poly('Sector boundary',[p(-1.8,-1.8*k),p(1.8,1.8*k)],GRAY,.9)
    s.poly('Example sector nonlinearity',[p(z,.7*z+.3*math.tanh(z)) for z in [(-1.8+3.6*i/100) for i in range(101)]],RED,1.9)
    s.equation('Input graph label',322,190,lambda m:m.signal('z'),11,w=90)
    s.equation('Output graph label',192,83,lambda m:m.signal('w'),11,w=95)
    s.equation('Upper sector bound',323,96,lambda m:m.r('β')+m.signal('z'),11,w=105)
    s.equation('Lower sector bound',327,144,lambda m:m.r('α')+m.signal('z'),11,w=105)
    if stage>=2:
        z=1.12;w=.7*z+.3*math.tanh(z);x,y=p(z,w)
        s.path('Upper gap',[p(z,1.2*z),p(z,w)],arrow=False,color=BLUE,width=2.8)
        s.path('Lower gap',[p(z,w),p(z,.2*z)],arrow=False,color=GREEN,width=2.8)
        for value in (1.2*z,w,.2*z):
            yy=p(z,value)[1];s.path('Gap tick',[(x-3,yy),(x+3,yy)],arrow=False,color=INK,width=.65)
        s.dot(x,y)

def block(s):
    s.path('Delta input',[(410,146),(493,146)],color=INK,width=1)
    s.path('Delta output',[(547,146),(650,146)],color=INK,width=1)
    s.outline('Delta block',(493,122,54,48),RED,1)
    s.equation('Delta label',520,146,lambda m:m.r('Δ',RED,True),25,w=50)
    s.equation('Delta input label',446,128,lambda m:m.signal('z'),13,w=90)
    s.equation('Delta output label',603,128,lambda m:m.signal('w'),13,w=90)

NOTES=[
"A concrete static instance of Definition 5. Assume a real scalar memoryless pointwise operator w_Delta(t,s)=phi(z_Delta(t,s)), with phi(0)=0 and alpha<beta finite. The sector condition holds for every scalar input, time and spatial location. The graph is schematic: alpha=0.2, beta=1.2 and phi(z)=0.7*z+0.3*tanh(z). It illustrates the sector, not measured data. Both first and third quadrant wedges are shown. Sector membership is not the same as a bound on the derivative of phi.",
"The upper gap beta*z-w and the lower gap w-alpha*z have the same sign for a sector-bounded graph. At the positive input marked here both are nonnegative; for a negative input both are nonpositive. Their product q is nonnegative in both cases. q is a mathematical supply density, not necessarily physical heat or energy. The colours on the two factors match the two short gap segments in the diagram.",
"Expanding q gives -alpha*beta*z^2+(alpha+beta)*z*w-w^2. Thus the off-diagonal multiplier entries are (alpha+beta)/2. The matrix acts pointwise on the spatial channels; its entries represent scalar multiples of the identity operator on L2([a,b]). This multiplier is indefinite in general. x is defined here only to shorten the stacked input/output pair; all time and space arguments remain visible.",
"Because q(t,s)>=0 pointwise, integrating over the spatial domain and any finite time horizon gives a hard IQC. Choose Psi_Delta=I and the sector multiplier from the previous slide in Definition 5. Then the paper's truncated inner product is exactly this double integral. For this memoryless example choose nonnegative storage S identically zero, so S(T)-S(0)=0 <= integral q; hence Delta is dissipative with supply sigma(t)=integral_a^b q(t,s) ds. This does not assert that every dynamic IQC has zero storage or pointwise nonnegative supply. An IQC describing Delta alone is not a stability certificate for its feedback interconnection; a complementary plant condition is still needed. Reference: Megretski and Rantzer, System Analysis via Integral Quadratic Constraints, IEEE TAC 42(6), 1997, Section VI.I. https://services.montefiore.uliege.be/systems/grad04/megretski97.pdf"
]

def make(n):
    s=Slide()
    titles=['Sector bounds describe Δ','Sector bounds give a nonnegative supply','Write the supply as a quadratic form','Definition 5: a hard IQC for Δ']
    s.label('Title',360,48,titles[n-1],25,w=648,bold=True);s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
    plot(s,n);block(s)
    if n==1:
        s.equation('Memoryless map',522,205,lambda m:m.signal('w')+m.r('=')+m.r('φ')+m.d(m.signal('z')),15,w=300)
        s.label('Map description',522,233,'Memoryless, acting at each spatial point',11,GRAY,w=325)
        s.equation('Sector inequality',360,296,lambda m:m.r('α')+m.sup(m.signal('z'),m.r('2'))+m.r('≤')+m.signal('z')+m.signal('w')+m.r('≤β')+m.sup(m.signal('z'),m.r('2')),19)
        s.label('Sector interpretation',360,347,'Every point of the nonlinear graph stays inside the sector.',14,w=650)
    elif n==2:
        s.label('Gap interpretation',522,207,'The two gaps have the same sign.',14,w=330)
        s.label('Supply interpretation',522,234,'Their product is nonnegative.',14,GREEN,w=330)
        def supply(m):
            return m.q()+m.r('=')+m.d(m.r('β',BLUE)+m.signal('z',color=BLUE)+m.r('−',BLUE)+m.signal('w',color=BLUE))+m.d(m.signal('w',color=GREEN)+m.r('−α',GREEN)+m.signal('z',color=GREEN))+m.r('≥0',GREEN)
        s.equation('Sector supply',360,299,supply,17)
        s.label('Pointwise quantifiers',360,347,'For every input, at every time and spatial point.',14,w=650)
    elif n==3:
        s.equation('Stacked signal',521,219,lambda m:m.x()+m.r('=')+m.vector(),16,w=330)
        s.equation('Quadratic supply',360,281,lambda m:m.q()+m.r('=')+m.sup(m.x(),m.r('⊤',plain=True))+m.mult()+m.x()+m.r('≥0',GREEN),19)
        def matrix(m):
            half=m.frac(m.r('α+β'),m.r('2'))
            return m.mult()+m.r('=')+m.d(m.matrix([[m.r('−αβ'),half],[half,m.r('−1')]]),'[',']')
        s.equation('Sector multiplier',360,341,matrix,16)
    else:
        s.equation('Identity filter',521,202,lambda m:m.sub(m.r('Ψ'),m.r('Δ',plain=True))+m.r('=I'),21,w=260)
        s.label('Definition connection',521,233,'Use the sector multiplier in Definition 5.',12,GRAY,w=325)
        s.equation('Hard IQC integral',360,281,lambda m:m.integral()+m.r('≥0',GREEN)+m.r('    ∀T≥0'),21)
        s.equation('Dissipativity storage inequality',360,334,lambda m:m.r('S')+m.d(m.r('T'))+m.r('−S')+m.d(m.r('0'))+m.r('=0≤')+m.integral(),18)
        s.label('Dissipativity result',360,374,'Δ is dissipative with this supply and zero storage.',11,GREEN,w=650)
    s.label('Footer',236,390,'Msc Defence T.M. Lenssen',8,GRAY,w=400);s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
    s.label('Slide number',634,390,str(n),8,GRAY,w=28)
    tree='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+''.join(s.parts)
    return b.lib.xml(f'<p:sld {b.DECL} mc:Ignorable="a14"><p:cSld><p:spTree>{tree}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')

def main():
    template=b.SOURCE.parent/'TUe - Clean White.potx'
    with zipfile.ZipFile(template) as z:files={n:z.read(n) for n in z.namelist() if not n.startswith(('ppt/slides/','ppt/notesSlides/'))}
    pkg='http://schemas.openxmlformats.org/package/2006/relationships'
    for i in range(1,5):
        files[f'ppt/slides/slide{i}.xml']=make(i)
        files[f'ppt/slides/_rels/slide{i}.xml.rels']=b.lib.xml(f'<Relationships xmlns="{pkg}"><Relationship Id="rId1" Type="{b.NS["r"]}/slideLayout" Target="../slideLayouts/slideLayout12.xml"/></Relationships>')
    pres=minidom.parseString(files['ppt/presentation.xml']);lst=pres.getElementsByTagName('p:sldIdLst')[0]
    for node in list(lst.childNodes):lst.removeChild(node)
    rel=minidom.parseString(files['ppt/_rels/presentation.xml.rels'])
    for node in list(rel.documentElement.childNodes):
        if getattr(node,'tagName','')=='Relationship' and node.getAttribute('Type').endswith('/slide'):rel.documentElement.removeChild(node)
    ct=minidom.parseString(files['[Content_Types].xml'])
    for el in list(ct.documentElement.childNodes):
        if getattr(el,'tagName','')!='Override':continue
        part=el.getAttribute('PartName')
        if part.startswith(('/ppt/slides/','/ppt/notesSlides/')):ct.documentElement.removeChild(el)
        elif part=='/ppt/presentation.xml':el.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml')
    # The white slide template has no notes master; copy one for the new notes.
    with zipfile.ZipFile(b.SOURCE) as source:
        master='ppt/notesMasters/notesMaster1.xml'
        files[master]=source.read(master)
        masterrel='ppt/notesMasters/_rels/notesMaster1.xml.rels'
        md=minidom.parseString(source.read(masterrel))
        for rr in md.getElementsByTagName('Relationship'):
            if rr.getAttribute('Type').endswith('/theme'):
                old=b.posixpath.normpath('ppt/notesMasters/'+rr.getAttribute('Target'))
                files['ppt/theme/sectorNotesTheme.xml']=source.read(old)
                rr.setAttribute('Target','../theme/sectorNotesTheme.xml')
        files[masterrel]=md.toxml(encoding='utf-8')
    for path,ctype in [('/'+master,'application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml'),('/ppt/theme/sectorNotesTheme.xml','application/vnd.openxmlformats-officedocument.theme+xml')]:
        el=ct.createElement('Override');el.setAttribute('PartName',path);el.setAttribute('ContentType',ctype);ct.documentElement.appendChild(el)
    nlist=pres.createElementNS(b.NS['p'],'p:notesMasterIdLst')
    ni=pres.createElementNS(b.NS['p'],'p:notesMasterId');ni.setAttributeNS(b.NS['r'],'r:id','rIdSectorNotes');nlist.appendChild(ni)
    pres.documentElement.insertBefore(nlist,lst)
    rr=rel.createElement('Relationship');rr.setAttribute('Id','rIdSectorNotes');rr.setAttribute('Type',b.NS['r']+'/notesMaster');rr.setAttribute('Target','notesMasters/notesMaster1.xml');rel.documentElement.appendChild(rr)
    for i in range(1,5):
        sid=pres.createElementNS(b.NS['p'],'p:sldId');sid.setAttribute('id',str(255+i));sid.setAttributeNS(b.NS['r'],'r:id',f'rIdSector{i}');lst.appendChild(sid)
        r=rel.createElement('Relationship');r.setAttribute('Id',f'rIdSector{i}');r.setAttribute('Type',b.NS['r']+'/slide');r.setAttribute('Target',f'slides/slide{i}.xml');rel.documentElement.appendChild(r)
        e=ct.createElement('Override');e.setAttribute('PartName',f'/ppt/slides/slide{i}.xml');e.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');ct.documentElement.appendChild(e)
    for k,d in [('ppt/presentation.xml',pres),('ppt/_rels/presentation.xml.rels',rel),('[Content_Types].xml',ct)]:files[k]=d.toxml(encoding='utf-8')
    for i,text in enumerate(NOTES,1):b.add_notes(files,i,text)
    with zipfile.ZipFile(OUT/'Sector IQC - Editable.pptx','w',zipfile.ZIP_DEFLATED) as z:
        for n,v in files.items():z.writestr(n,v)
    (Path(__file__).parent/'README.md').write_text('Four-step visualization of the static sector IQC in Definition 5.\n\n'+ '\n\n'.join(f'{i}. {t}' for i,t in enumerate(NOTES,1)),encoding='utf-8')
    print('Created four editable slides with equations, sector graph, supply, multiplier and dissipativity; original deck untouched.')

if __name__=='__main__':main()
