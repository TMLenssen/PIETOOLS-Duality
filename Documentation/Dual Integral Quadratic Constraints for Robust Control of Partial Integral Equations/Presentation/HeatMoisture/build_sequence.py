"""Build a four-slide, editable heat/moisture explanation in the current deck."""
from pathlib import Path
from xml.sax.saxutils import escape,quoteattr
from xml.dom import minidom
import zipfile,hashlib,json,importlib.util,re,posixpath

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/heat_moisture'
SOURCE=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx')
spec=importlib.util.spec_from_file_location('lfr',ROOT/'Figures/LFR/Source/add_paper_figures.py')
lib=importlib.util.module_from_spec(spec);spec.loader.exec_module(lib)
NS=dict(lib.NS,m='http://schemas.openxmlformats.org/officeDocument/2006/math',a14='http://schemas.microsoft.com/office/drawing/2010/main',mc='http://schemas.openxmlformats.org/markup-compatibility/2006')
DECL=' '.join(f'xmlns:{k}="{v}"' for k,v in NS.items())
INK='252529';GRAY='747B82';HEAT='AE4C0D';WATER='186E9B';UNC='D61016';PERF='147C60'
emu=lib.emu;fill=lib.fill;xf=lib.xf;nv=lib.nv

class Math:
    def __init__(self,size=18,color=INK):self.size=size;self.color=color
    def pr(self,color=None):return f'<a:rPr sz="{round(self.size*100)}">{fill(color or self.color)}<a:latin typeface="Cambria Math"/></a:rPr>'
    def ctrl(self):return '<m:ctrlPr>'+self.pr()+'</m:ctrlPr>'
    def r(self,t,c=None,plain=False):
        italic=not plain and any(ch in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZαδγπ' for ch in t)
        return f'<m:r><m:rPr><m:sty m:val="{"i" if italic else "p"}"/></m:rPr>{self.pr(c)}<m:t xml:space="preserve">{escape(t)}</m:t></m:r>'
    def sub(self,b,s):return '<m:sSub><m:sSubPr>'+self.ctrl()+'</m:sSubPr><m:e>'+b+'</m:e><m:sub>'+s+'</m:sub></m:sSub>'
    def sup(self,b,s):return '<m:sSup><m:sSupPr>'+self.ctrl()+'</m:sSupPr><m:e>'+b+'</m:e><m:sup>'+s+'</m:sup></m:sSup>'
    def frac(self,a,b):return '<m:f><m:fPr>'+self.ctrl()+'</m:fPr><m:num>'+a+'</m:num><m:den>'+b+'</m:den></m:f>'
    def d(self,e,l='(',r=')'):
        return f'<m:d><m:dPr><m:begChr m:val="{l}"/><m:endChr m:val="{r}"/>{self.ctrl()}</m:dPr><m:e>'+e+'</m:e></m:d>'
    def integ(self,e):
        return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+self.ctrl()+'</m:naryPr><m:sub>'+self.r('0',plain=True)+'</m:sub><m:sup>'+self.r('1',plain=True)+'</m:sup><m:e>'+e+'</m:e></m:nary>'
    def v(self,i,args=False):
        c=HEAT if i==1 else WATER
        s=self.sub(self.r('v',c),self.r(str(i),c,True))
        return s+(self.d(self.r('t,s',c)) if args else '')
    def partial(self,s):return self.sub(self.r('∂',plain=True),self.r(s))
    def p(self,t):return self.sub(self.r(t,PERF),self.r('p',PERF,True))
    def coef(self,t):return self.r(t,UNC if t=='a' else PERF)+self.d(self.r('δ',UNC))
    def delta2(self):return self.sup(self.r('δ',UNC),self.r('2',plain=True))
    def pi2(self):return self.frac(self.sup(self.r('π'),self.r('2',plain=True)),self.r('2',plain=True))
    def nominal(self,i):
        if i==1:return self.partial('t')+self.v(1)+self.r('=')+self.partial('ss')+self.v(1)+self.r('+')+self.d(self.pi2()+self.r('−2'))+self.v(1)+self.r('−3')+self.v(2)
        return self.partial('t')+self.v(2)+self.r('=')+self.partial('ss')+self.v(2)+self.r('+')+self.v(1)+self.r('+')+self.d(self.r('1+')+self.pi2())+self.v(2)
    def uncertain(self,load=False):
        e=self.partial('t')+self.v(1)+self.r('=')+self.partial('ss')+self.v(1)+self.r('+')+self.coef('a')+self.v(1)+self.r('−3')+self.v(2)
        return e+(self.r('+')+self.coef('b')+self.r('s',PERF)+self.p('w') if load else '')
    def coefficient(self,c):
        den=self.r('1+')+self.delta2()
        if c=='a':value=self.pi2()+self.r('−2+')+self.frac(self.r('δ',UNC)+self.d(self.r('1+')+self.r('δ',UNC)),den)
        if c=='b':value=self.frac(self.r('1−')+self.delta2(),den)
        if c=='c':value=self.frac(self.r('1+3')+self.delta2(),den)
        if c=='d':value=self.frac(self.r('δ',UNC)+self.d(self.r('1−')+self.r('δ',UNC)),den)
        return self.coef(c)+self.r('=')+value

class Slide(lib.Diagram):
    def label(self,name,x,y,text,size=12,color=INK,w=180,bold=False):
        self.add(lib.tb(self.ident(),name,(x-w/2,y-size*.75,w,size*1.5),text,size,color,'Aptos',bold=bold))
    def equation(self,name,x,y,fn,size=18,w=640,color=INK):
        m=Math(size,color);body=fn(m)
        shape=lib.tb(self.ident(),name,(x-w/2,y-size*1.1,w,size*2.2),'',size)
        eq='<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+body+'</m:oMath></m:oMathPara></a14:m>'
        shape=re.sub(r'<a:r>.*?</a:r>',eq,shape)
        self.add(shape)
    def outline(self,name,box,color=GRAY,width=.8,dashed=False):
        self.add(f'<p:sp>{nv(self.ident(),name)}<p:spPr>{xf(*box)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln w="{emu(width)}">{fill(color)}'+('<a:prstDash val="dash"/>' if dashed else '')+'</a:ln></p:spPr></p:sp>')
    def layer(self,name,y,colors):
        stops=''.join(f'<a:gs pos="{pos}"><a:srgbClr val="{c}"/></a:gs>' for pos,c in zip([0,35000,80000,100000],colors))
        self.add(f'<p:sp>{nv(self.ident(),name)}<p:spPr>{xf(168,y,344,34)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:gradFill rotWithShape="1"><a:gsLst>{stops}</a:gsLst><a:lin ang="0" scaled="1"/></a:gradFill><a:ln w="{emu(.5)}">{fill(colors[-1])}</a:ln></p:spPr></p:sp>')
    def base(self,stage):
        # Exactly shared positions on each slide: both layers represent one domain.
        self.layer('Heat field layer',122,['FFF1D9','F5C47F','E88734','E88734'])
        self.layer('Moisture field layer',184,['ECF7FC','A1D6E9','439DC4','439DC4'])
        self.equation('Heat state label',230,132,lambda m:m.v(1,True),17,w=115)
        self.equation('Moisture state label',230,194,lambda m:m.v(2,True),17,w=115)
        self.label('Heat name',388,132,'Heat state',14,'6B330A',w=145)
        self.label('Moisture name',388,194,'Moisture state',14,'104D6A',w=145)
        self.path('Heat diffuses from hotter to cooler',[(430,150),(185,150)],color=HEAT,width=.85)
        self.path('Moisture diffuses from wetter to drier',[(430,212),(185,212)],color=WATER,width=.85)
        self.path('Heat to moisture coupling',[(296,158),(296,181)],color=HEAT,width=1)
        self.path('Moisture to heat coupling',[(396,182),(396,159)],color=WATER,width=1)
        self.equation('Positive heat coupling',267,170,lambda m:m.r('+')+m.v(1),12,w=50)
        self.equation('Negative moisture coupling',431,170,lambda m:m.r('−3')+m.v(2),12,w=64)
        self.label('Coupling meaning',346,170,'coupling',8,GRAY,w=64)
        for x in (168,512):
            self.path('Shared boundary',[(x,122),(x,218)],arrow=False,color='A1A6AA',width=.7)
        self.path('Common spatial axis left',[(168,225),(330,225)],arrow=False,color='A1A6AA',width=.7)
        self.path('Common spatial axis right',[(350,225),(512,225)],arrow=False,color='A1A6AA',width=.7)
        for x in (168,512):self.path('Spatial end tick',[(x,222),(x,228)],arrow=False,color=GRAY,width=.7)
        self.equation('Spatial coordinate',340,225,lambda m:m.r('s'),11,w=25,color=GRAY)
        self.label('Left end label',145,225,'0',10,GRAY,w=20)
        self.label('Right end label',534,225,'1',10,GRAY,w=20)
        self.equation('Reference boundary',209,245,lambda m:m.sub(m.r('v'),m.r('i'))+m.d(m.r('t,0'))+m.r('=0'),12,w=200)
        self.equation('No-flux boundary',469,245,lambda m:m.partial('s')+m.sub(m.r('v'),m.r('i'))+m.d(m.r('t,1'))+m.r('=0'),12,w=200)
        self.label('Reference boundary interpretation',209,262,'Reference value · both fields',9,GRAY,w=230)
        self.label('No-flux boundary interpretation',469,262,'No flux · both fields',9,GRAY,w=230)
        if stage>=2:
            self.outline('Uncertain heat reaction',(163,117,354,43),UNC,1,True)
            self.equation('Shared uncertain parameter',504,108,lambda m:m.r('δ',UNC),15,w=28)
        if stage>=3:
            self.equation('Heat-load disturbance',106,100,lambda m:m.p('w')+m.d(m.r('t')),16,w=86)
            self.label('Disturbance interpretation',98,119,'Heat-load fluctuation',9,PERF,w=123)
            self.path('Distributed heat load',[(145,100),(445,100)],arrow=False,color=PERF,width=1)
            for x in (205,325,445):self.path('Distributed spatial forcing',[(x,100),(x,120)],color=PERF,width=1)
            self.label('Spatial load weight',334,88,'load weighted by s',9,PERF,w=160)
            self.path('Mean heat performance output',[(518,136),(565,136)],color=PERF,width=1.2)
            self.equation('Performance output label',604,136,lambda m:m.p('z')+m.d(m.r('t')),16,w=85)
            self.label('Mean heat interpretation',601,157,'Weighted mean heat',10,PERF,w=152)
            self.label('Output feedthrough interpretation',601,172,'+ direct load effect',9,PERF,w=152)
            if stage==3:
                self.equation('Performance requirement',603,202,lambda m:m.sub(m.d(m.p('z'),'‖','‖'),m.sub(m.r('L'),m.r('2')))+m.r('≤γ')+m.sub(m.d(m.p('w'),'‖','‖'),m.sub(m.r('L'),m.r('2'))),13,w=165)
                self.label('Performance goal interpretation',603,222,'Small gain · zero initial state',9,PERF,w=165)
            if stage==4:
                self.equation('All admissible uncertainty',606,103,lambda m:m.r('∀')+m.r('δ',UNC)+m.r(':')+m.d(m.r('δ',UNC),'|','|')+m.r('≤')+m.r('α',UNC),14,w=150)
        else:
            self.label('Spatial fields caption',340,100,'Two fields in the same material',11,GRAY,w=300)

def build_slide(n):
    s=Slide();stage=n-25
    s.label('Slide title',360,49,'Robust Stability and Performance',25,w=648,bold=True)
    # Consistent left alignment with the clean white template.
    s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
    subtitles={26:'1  States: heat and moisture',27:'2  Uncertainty: one unknown material parameter',28:'3  Performance: limit the response to heat-load fluctuations',29:'4  Robust requirements: for every admissible material parameter'}
    s.label('Progressive introduction',360,77,subtitles[n],12,GRAY,w=648)
    s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
    s.base(stage)
    if n==26:
        s.equation('Nominal heat PDE',360,300,lambda m:m.nominal(1),19)
        s.equation('Nominal moisture PDE',360,343,lambda m:m.nominal(2),19)
        s.label('Nominal scope',360,370,'Nominal view: δ = 0, no disturbance. States are deviations from a reference.',10,GRAY,w=650)
    elif n==27:
        s.equation('Uncertain heat PDE',360,291,lambda m:m.uncertain(),18)
        s.equation('Uncertain reaction coefficient',304,324,lambda m:m.coefficient('a'),16,w=468)
        s.equation('Uncertainty bound',602,324,lambda m:m.d(m.r('δ',UNC),'|','|')+m.r('≤')+m.r('α',UNC),16,w=110)
        s.equation('Unchanged moisture PDE',360,360,lambda m:m.nominal(2),16)
    elif n==28:
        s.equation('Heat equation with disturbance',360,289,lambda m:m.uncertain(True),17)
        s.equation('Physical performance output',360,323,lambda m:m.p('z')+m.r('=')+m.coef('c')+m.integ(m.v(1)+m.r('ds'))+m.r('+')+m.coef('d')+m.p('w'),17)
        for c,x in [('b',148),('c',359),('d',571)]:s.equation('Performance coefficient '+c,x,361,lambda m,c=c:m.coefficient(c),13,w=205)
    else:
        s.label('Robust stability heading',191,290,'Robust stability',14,w=300,bold=True)
        s.label('Robust performance heading',521,290,'Robust performance',14,w=300,bold=True)
        s.equation('State decay objective',191,319,lambda m:m.sub(m.d(m.r('v')+m.d(m.r('t,·')),'‖','‖'),m.sub(m.r('L'),m.r('2')))+m.r('→0'),19,w=300)
        s.equation('Induced gain objective',521,319,lambda m:m.sub(m.d(m.p('z'),'‖','‖'),m.sub(m.r('L'),m.r('2')))+m.r('≤γ')+m.sub(m.d(m.p('w'),'‖','‖'),m.sub(m.r('L'),m.r('2'))),19,w=300)
        s.label('Stability meaning',191,346,'Both fields settle when the load is removed.',10,GRAY,w=308)
        s.label('Performance meaning',521,346,'Bound the energy amplification of the load.',10,GRAY,w=318)
        s.equation('Zero load condition',191,368,lambda m:m.p('w')+m.r('=0'),11,w=200)
        s.equation('Zero initial state condition',521,368,lambda m:m.r('v')+m.d(m.r('0,·'))+m.r('=0'),11,w=200)
    s.label('Footer',236,390,'Msc Defence T.M. Lenssen',8,GRAY,w=400)
    s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
    s.label('Slide number',634,390,str(n),8,GRAY,w=28)
    tree='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+''.join(s.parts)
    return lib.xml(f'<p:sld {DECL} mc:Ignorable="a14"><p:cSld><p:spTree>{tree}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')

NOTES={
26:'Introduce two distributed states on the same normalized material domain: v1 is heat/temperature deviation and v2 is moisture deviation. These are an illustrative physical interpretation of the coupled PDE benchmark, not calibrated dimensional temperatures or moisture concentrations. Warm and blue gradients are schematic, not simulation results; the identical layer positions persist across all four slides. Show the nominal zero-input case delta=0, wp=0 first. Coupling is exactly +v1 in the moisture dynamics and -3v2 in the heat dynamics. At s=0 both deviations are zero; at s=1 both spatial derivatives are zero (no flux). The previous picture incorrectly displayed a zero value at the right boundary.',
27:'Introduce one fixed real scalar delta, shared by every location and all uncertainty-dependent coefficients, with |delta| <= alpha. At this stage wp=0. a(delta)=pi^2/2-2+delta(1+delta)/(1+delta^2). The moisture equation is unchanged. The red dashed outline marks the uncertain heat reaction, not an additional state or boundary input. Later the same delta also changes the disturbance and output coefficients.',
28:'Introduce wp(t) as a heat-load fluctuation. This is a distributed forcing b(delta)*s*wp(t), not a boundary disturbance; the arrows enter the interior of the heat layer. zp(t)=c(delta)*integral_0^1 v1(t,s) ds+d(delta)*wp(t). Physically interpret this as a weighted mean heat response with a direct contribution from the load. It is not a bound on the pointwise peak temperature or on moisture directly. Moisture affects the output through the heat-moisture coupling. b=(1-delta^2)/(1+delta^2), c=(1+3delta^2)/(1+delta^2), d=delta(1-delta)/(1+delta^2). The full PDE and boundary conditions remain those shown on slide 25.',
29:'Combine the two questions for every fixed admissible delta with |delta| <= alpha. Robust stability: in the absence of load, both distributed state deviations decay to zero (spatial L2 norm). Robust performance: from zero initial state, the temporal L2 norm of zp is at most gamma times the temporal L2 norm of wp, uniformly over the uncertainty set. These are requirements to certify, not a claim that a certificate has already been found for the displayed coefficients. Smaller gamma means less amplification of heat-load fluctuations. No pointwise temperature or moisture limit is claimed.'}

def add_notes(files,i,text):
    key=f'ppt/slides/_rels/slide{i}.xml.rels';rels=minidom.parseString(files[key]);note=None
    for r in rels.getElementsByTagName('Relationship'):
        if r.getAttribute('Type').endswith('/notesSlide'):note=posixpath.normpath('ppt/slides/'+r.getAttribute('Target'))
    if note is None:
        nums=[int(re.search(r'notesSlide(\d+)\.xml$',p).group(1)) for p in files if re.search(r'^ppt/notesSlides/notesSlide\d+\.xml$',p)]
        num=max(nums,default=0)+1;note=f'ppt/notesSlides/notesSlide{num}.xml'
        r=rels.createElement('Relationship');r.setAttribute('Id','rIdHeatNotes');r.setAttribute('Type',NS['r']+'/notesSlide');r.setAttribute('Target',f'../notesSlides/notesSlide{num}.xml');rels.documentElement.appendChild(r);files[key]=rels.toxml(encoding='utf-8')
        ct=minidom.parseString(files['[Content_Types].xml']);el=ct.createElement('Override');el.setAttribute('PartName','/'+note);el.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml');ct.documentElement.appendChild(el);files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
        files[f'ppt/notesSlides/_rels/notesSlide{num}.xml.rels']=lib.xml(f'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="{NS["r"]}/notesMaster" Target="../notesMasters/notesMaster1.xml"/><Relationship Id="rId2" Type="{NS["r"]}/slide" Target="../slides/slide{i}.xml"/></Relationships>')
    # Retain existing notes as a separate paragraph if the slide had any.
    old=''
    if note in files:
        d=minidom.parseString(files[note]);old=' '.join(e.firstChild.data for e in d.getElementsByTagName('a:t') if e.firstChild)
    body=text+ ('\n\nPrevious notes: '+old if old.strip() and old.strip()!=str(i) else '')
    shp=lib.tb(2,'Speaker notes',(36,80,600,400),body,12,font='Aptos').replace('<p:nvPr/>','<p:nvPr><p:ph type="body" idx="1"/></p:nvPr>').replace('wrap="none"','wrap="square"')
    files[note]=lib.xml(f'<p:notes {DECL}><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>{shp}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>')

def main():
    OUT.mkdir(exist_ok=True,parents=True)
    with zipfile.ZipFile(SOURCE) as z:files={n:z.read(n) for n in z.namelist()}
    before=dict(files)
    for i in range(26,30):
        files[f'ppt/slides/slide{i}.xml']=build_slide(i)
        # Speaker notes belong to the user. Visual rebuilds preserve every
        # notes part and relationship exactly; suggested narration stays local.
    for i in list(range(1,26))+[30]:assert files[f'ppt/slides/slide{i}.xml']==before[f'ppt/slides/slide{i}.xml']
    assert all(files[n]==b for n,b in before.items() if n.startswith('ppt/media/'))
    assert all(files[n]==b for n,b in before.items() if n.startswith('ppt/notesSlides/'))
    with zipfile.ZipFile(OUT/'presentation.pptx','w',zipfile.ZIP_DEFLATED) as z:
        for n,b in files.items():z.writestr(n,b)
    (OUT/'manifest.json').write_text(json.dumps(dict(source=str(SOURCE),source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),slides=[26,27,28,29]),indent=2))
    (Path(__file__).parent/'Speaker notes.md').write_text('\n\n'.join(f'Slide {i}\n\n{NOTES[i]}' for i in NOTES),encoding='utf-8')
    print('Staged slides 26–29. Other slides, template, media and videos preserved byte-for-byte.')

if __name__=='__main__':main()
