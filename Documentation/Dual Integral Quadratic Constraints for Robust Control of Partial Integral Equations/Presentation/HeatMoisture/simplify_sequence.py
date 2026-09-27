"""Restore the original strip style and add only a matching moisture layer."""
from pathlib import Path
from xml.dom import minidom
import importlib.util,zipfile,math

spec=importlib.util.spec_from_file_location('sequence',Path(__file__).with_name('build_sequence.py'))
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
original=b.SOURCE.parent/'Archive/Before heat-moisture sequence.pptx'

def strip(s,name,y,cold,warm):
    # Schematic sin(pi*s/2) profile: zero at the left, zero slope at the right.
    # Repeat the terminal colour over the last 5% to make the no-flux end visible.
    start=[int(cold[i:i+2],16) for i in (0,2,4)]
    end=[int(warm[i:i+2],16) for i in (0,2,4)]
    stops=''
    for p in [0,10000,20000,30000,40000,50000,60000,70000,80000,90000,95000,100000]:
        amount=math.sin(math.pi/2*min(p/95000,1))
        c=''.join(f'{round(a+(z-a)*amount):02X}' for a,z in zip(start,end))
        stops+=f'<a:gs pos="{p}"><a:srgbClr val="{c}"/></a:gs>'
    s.add(f'<p:sp>{b.nv(s.ident(),name)}<p:spPr>{b.xf(118,y,484,39.3)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:gradFill rotWithShape="1"><a:gsLst>{stops}</a:gsLst><a:lin ang="0" scaled="1"/></a:gradFill><a:ln w="{b.emu(1.15)}">{b.fill("332E29")}</a:ln></p:spPr></p:sp>')
    # The same light sans-serif label, dimensions and placement as the original.
    s.add(b.lib.tb(s.ident(),name+' title',(170,y+5,380,29.3),name,21,'FFFFFF','Calibri Light'))

def original_equations(n,s):
    # Retain every independent variable; abbreviate only the four coefficients.
    def state(m,i):
        color=('A8515A' if i==1 else '216F9C') if n==26 else b.INK
        return m.sub(m.r('v',color),m.r(str(i),color,True))+m.d(m.r('t,s'))
    def coefficient(m,c):
        color=b.UNC if n==27 else b.INK
        return m.r(c,color)+m.d(m.r('δ',color))
    def channel(m,c):
        color=b.PERF if n==28 else b.INK
        return m.sub(m.r(c,color),m.r('p',color,True))+m.d(m.r('t'))
    def heat(m):
        return m.partial('t')+state(m,1)+m.r('=')+m.partial('ss')+state(m,1)+m.r('+')+coefficient(m,'a')+state(m,1)+m.r('−3')+state(m,2)+m.r('+')+coefficient(m,'b')+m.r('s')+channel(m,'w')
    def moisture(m):
        return m.partial('t')+state(m,2)+m.r('=')+m.partial('ss')+state(m,2)+m.r('+')+state(m,1)+m.r('+')+m.d(m.r('1+')+m.pi2())+state(m,2)
    def output(m):
        return channel(m,'z')+m.r('=')+coefficient(m,'c')+m.integ(state(m,1)+m.r(' ds'))+m.r('+')+coefficient(m,'d')+channel(m,'w')
    for name,y,fn in [('Heat equation',250,heat),('Moisture equation',291,moisture),('Performance output equation',336,output)]:
        s.equation(name,360,y,fn,17,w=640)

def build_slide(n):
    s=b.Slide()
    s.label('Slide title',360,49,'Robust Stability and Performance',25,w=648,bold=True)
    s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
    strip(s,'Heat in paper',88,'8580F5','DF8E93')
    strip(s,'Moisture in paper',136,'CDE7F3','438BB5')
    # Two small arrows connect the layers without adding a separate callout.
    s.path('Heat to moisture coupling',[(258,121),(258,143)],color='A8515A',width=1.2)
    s.path('Moisture to heat coupling',[(462,143),(462,121)],color='216F9C',width=1.2)
    # One pair of boundary labels for the two aligned fields.
    s.equation('Left boundary',118,76,lambda m:m.sub(m.r('v'),m.r('i'))+m.d(m.r('t,0'))+m.r('=0'),13,w=150,color='332E29')
    s.equation('Right boundary',602,76,lambda m:m.partial('s')+m.sub(m.r('v'),m.r('i'))+m.d(m.r('t,1'))+m.r('=0'),13,w=190,color='332E29')
    s.path('Original dimension line',[(118,189),(602,189)],arrow=False,color='786D5E',width=.85)
    for x in (118,602):s.path('End tick',[(x,184),(x,194)],arrow=False,color='786D5E',width=.85)
    for x,t in [(118,'s=0'),(360,'s'),(602,'s=1')]:s.equation('Spatial coordinate',x,207,lambda m,t=t:m.r(t),17,w=80,color='786D5E')
    # State names sit outside the strips, preserving the heat panel verbatim.
    for i,y in [(1,107.65),(2,155.65)]:s.equation('State label '+str(i),89,y,lambda m,i=i:m.sub(m.r('v'),m.r(str(i),plain=True)),17,w=38)
    if n in (27,28,29):s.equation('Admissible uncertainty',660,107,lambda m:m.d(m.r('δ',b.UNC),'|','|')+m.r('≤α'),14,w=100)
    if n<29:
        original_equations(n,s)
        if n==28:
            s.label('Performance interpretation',360,366,'Heat-load disturbance → weighted mean heat response',12,w=600)
    else:
        s.label('Stability interpretation',360,244,'No disturbance: both fields settle to the reference.',14,w=620)
        s.equation('State convergence',360,279,lambda m:m.r('v')+m.d(m.r('t,·'))+m.r('→0'),22,w=600)
        s.label('Performance interpretation',360,317,'With a disturbance: limit the mean heat response.',14,w=620)
        s.equation('Performance bound',360,353,lambda m:m.sub(m.d(m.p('z'),'‖','‖'),m.sub(m.r('L'),m.r('2')))+m.r('≤γ')+m.sub(m.d(m.p('w'),'‖','‖'),m.sub(m.r('L'),m.r('2'))),22,w=600)
    s.label('Footer',236,390,'Msc Defence T.M. Lenssen',8,b.GRAY,w=400)
    s.parts[-1]=s.parts[-1].replace('algn="ctr"','algn="l"')
    s.label('Slide number',634,390,str(n),8,b.GRAY,w=28)
    tree='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+''.join(s.parts)
    return b.lib.xml(f'<p:sld {b.DECL} mc:Ignorable="a14"><p:cSld><p:spTree>{tree}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')

b.build_slide=build_slide
# Keep speaker notes consistent with the simplified artwork.
def simple_notes(files,i,text):
    rel=minidom.parseString(files[f'ppt/slides/_rels/slide{i}.xml.rels'])
    for r in rel.getElementsByTagName('Relationship'):
        if not r.getAttribute('Type').endswith('/notesSlide'):continue
        key=b.posixpath.normpath('ppt/slides/'+r.getAttribute('Target'))
        d=minidom.parseString(files[key])
        body=d.getElementsByTagName('p:txBody')[0]
        for child in list(body.childNodes):
            if getattr(child,'tagName','')=='a:p':body.removeChild(child)
        notes={26:'Two fields on the same spatial domain: v1 is heat deviation and v2 is moisture deviation. Full model is unchanged; introduce the states first. Boundary conditions apply to both fields. The heat strip deliberately retains the original schematic artwork and colours, as requested. Gradients are conceptual illustrations, not computed state or flux profiles.',27:'Introduce the same real parameter delta everywhere in the model, with |delta| <= alpha. Red terms identify its influence. The boundary conditions remain fixed-reference on the left and zero flux on the right.',28:'wp is a heat-load disturbance distributed with spatial weight s. zp is a weighted spatial mean heat response plus a direct load term. It does not measure moisture directly, nor bound peak temperature. The green signal names and single caption introduce the physical performance channels.',29:'Requirements hold for every admissible delta. Without disturbance, both state deviations must decay. With zero initial state, temporal L2 energy gain from wp to zp must be bounded by gamma. These are objectives to certify.'}
        notes[26]='Two fields on the same spatial domain: v1 is heat deviation and v2 is moisture deviation. Full model is unchanged; introduce the states first. Both schematic profiles start at zero on the left and flatten at the no-flux right boundary, using a sin(pi*s/2)-shaped colour progression. The two simple arrows show the +v1 coupling from heat to moisture and the -3v2 coupling from moisture to heat. They indicate reaction coupling, not spatial transport. Gradients illustrate a boundary-compatible profile, not a simulation result.'
        p=d.createElement('a:p');r=d.createElement('a:r');t=d.createElement('a:t');t.appendChild(d.createTextNode(notes[i]));r.appendChild(t);p.appendChild(r);body.appendChild(p)
        files[key]=d.toxml(encoding='utf-8')
b.add_notes=simple_notes
if __name__=='__main__':b.main()
