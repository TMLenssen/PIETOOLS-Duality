"""Embed clean 4K videos and add editable math/text labels to the staged deck."""
from pathlib import Path
from xml.dom import minidom
import json,zipfile,re,copy
import numpy as np
from build_image_overlays import ROOT,OUT,Overlay,b,els,first,xml,PKG

def insert_parts(doc,parts):
    tree=first(doc,'p:spTree')
    for part in parts:
        node=minidom.parseString(f'<root {b.DECL}>'+part+'</root>').documentElement.firstChild
        tree.appendChild(doc.importNode(node,True))
def namespaces(doc):
    for prefix,uri in b.NS.items():doc.documentElement.setAttribute('xmlns:'+prefix,uri)
    old=doc.documentElement.getAttribute('mc:Ignorable').split()
    doc.documentElement.setAttribute('mc:Ignorable',' '.join(sorted(set(old+['a14']))))
def acc(m,s,char):return '<m:acc><m:accPr><m:chr m:val="'+char+'"/>'+m.ctrl()+'</m:accPr><m:e>'+s+'</m:e></m:acc>'
def qt(m,dot=0):return (acc(m,m.r('q'),'̈' if dot==2 else '̇') if dot else m.r('q'))+m.d(m.r('t'))
def omega(m):return m.sub(m.r('ω'),m.r('c'))+m.d(m.r('t'))
def signal(m,s):return m.r(s)+m.d(m.r('t'))

def carts(files):
    doc=minidom.parseString(files['ppt/slides/slide2.xml']);namespaces(doc)
    poses=json.loads((OUT/'cart_label_positions.json').read_text());tracks=[];ident=10000
    for pic in list(els(doc,'p:pic')):
        nv=first(pic,'p:cNvPr');name=nv.getAttribute('name')
        if name not in ['cart_rigid','cart_flexible']:continue
        flexible=name.endswith('flexible');kind='flexible' if flexible else 'rigid';o=Overlay(doc,pic,960,540,ident)
        pos=poses[kind];mediaid=nv.getAttribute('id')
        def eqtrack(name,y,xs,fn,size=22,width=100,color='192B3C'):
            o.equation(name,float(xs[0]),y,fn,size,width,color=color)
            sid=str(o.i);tracks.append((mediaid,sid,[(o.point(float(x),y)[0]/720) for x in xs]))
        xs=np.array(pos['target'])
        eqtrack('Moving target label',55,xs,lambda m:m.r('Target ',plain=True)+signal(m,'r'),22,140,'B87916')
        tip=np.array(pos['tip']);width=205 if flexible else 60
        eqtrack('Moving tip displacement',145,tip+52+width/2,lambda m:qt(m)+(m.r('+w')+m.d(m.r('t,L')) if flexible else ''),22,width)
        base=np.array(pos['base'])
        eqtrack('Moving cart displacement',397,base,lambda m:qt(m),22,70)
        if flexible:eqtrack('Moving spatial coordinate',101,base+16,lambda m:m.r('s'),22,30)
        if not flexible:
            o.equation('Rigid cart equation',480,449,lambda m:m.r('M')+qt(m,2)+m.r('=')+signal(m,'F'),20,820)
            o.equation('Rigid cart drive',480,487,lambda m:signal(m,'F')+m.r('=M')+m.d(m.sup(omega(m),m.r('2',plain=True))+m.d(signal(m,'r')+m.r('−')+qt(m))+m.r('−2')+omega(m)+qt(m,1),'[',']'),18,900)
        else:
            def w(m,sub,args='t,s'):return m.sub(m.r('w'),m.r(sub))+m.d(m.r(args))
            o.equation('Flexible beam PDE',480,442,lambda m:m.r('ρA')+m.d(w(m,'tt')+m.r('+')+qt(m,2),'[',']')+m.r('+EI')+w(m,'ssss')+m.r('+η')+w(m,'tssss')+m.r('=0,   0<s<L'),14,940)
            o.equation('Clamped and free boundary',480,462,lambda m:m.r('w')+m.d(m.r('t,0'))+m.r('=')+w(m,'s','t,0')+m.r('=0,    EI')+w(m,'ss','t,L')+m.r('+η')+w(m,'tss','t,L')+m.r('=0'),14,940)
            o.equation('Free shear boundary',480,483,lambda m:m.r('EI')+w(m,'sss','t,L')+m.r('+η')+w(m,'tsss','t,L')+m.r('=0'),14,940)
            o.equation('Flexible cart drive',480,505,lambda m:qt(m,2)+m.r('+2')+omega(m)+qt(m,1)+m.r('+')+m.sup(omega(m),m.r('2',plain=True))+m.d(qt(m)+m.r('−')+signal(m,'r'),'[',']')+m.r('=0'),14,940)
        insert_parts(doc,o.parts);ident=o.i+20
        media='media2.mp4' if flexible else 'media1.mp4';poster='image5.png' if flexible else 'image4.png'
        files['ppt/media/'+media]=(OUT/(name+'_clean.mp4')).read_bytes()
        files['ppt/media/'+poster]=(OUT/(name+'_clean.png')).read_bytes()
    # Property keyframes preserve the nonuniform physical time of the source simulation.
    # They start in the same timing container as each video play command.
    tid=max(int(n.getAttribute('id')) for n in els(doc,'p:cTn'))+1
    for mediaid,sid,xs in tracks:
        cmd=next(c for c in els(doc,'p:cmd') if c.getAttribute('cmd').startswith('playFrom') and first(c,'p:spTgt').getAttribute('spid')==mediaid)
        vals=''.join(f'<p:tav tm="{round(i*100000/300)}"><p:val><p:fltVal val="{x:.10f}"/></p:val></p:tav>' for i,x in enumerate(xs))
        vals+=f'<p:tav tm="100000"><p:val><p:fltVal val="{xs[-1]:.10f}"/></p:val></p:tav>'
        anim=f'<p:anim calcmode="lin" valueType="num"><p:cBhvr additive="base"><p:cTn id="{tid}" dur="10000" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="{sid}"/></p:tgtEl><p:attrNameLst><p:attrName>ppt_x</p:attrName></p:attrNameLst></p:cBhvr><p:tavLst>{vals}</p:tavLst></p:anim>'
        node=minidom.parseString(f'<root {b.DECL}>'+anim+'</root>').documentElement.firstChild
        cmd.parentNode.appendChild(doc.importNode(node,True));tid+=1
    files['ppt/slides/slide2.xml']=doc.toxml(encoding='utf-8')
    return len(tracks)

def sector_slide(files):
    # Reuse PowerPoint's own media shape and playback tree for robust embedding.
    with zipfile.ZipFile(b.SOURCE) as z:source=minidom.parseString(z.read('ppt/slides/slide2.xml'))
    pic=next(p for p in els(source,'p:pic') if first(p,'p:cNvPr').getAttribute('id')=='20').cloneNode(True)
    first(pic,'p:cNvPr').setAttribute('name','Sector simulation — clean 4K video')
    xf=first(pic,'a:xfrm');first(xf,'a:off').setAttribute('x','0');first(xf,'a:off').setAttribute('y','0')
    first(xf,'a:ext').setAttribute('cx',b.emu(720));first(xf,'a:ext').setAttribute('cy',b.emu(405))
    first(pic,'a:blip').setAttribute('r:embed','rIdPoster');first(pic,'a:videoFile').setAttribute('r:link','rIdVideo');first(pic,'p14:media').setAttribute('r:embed','rIdMedia')
    timing=first(source,'p:timing').cloneNode(True)
    for node in list(els(timing,'p:video')):
        if first(node,'p:spTgt').getAttribute('spid')=='21':node.parentNode.removeChild(node)
    for node in list(els(timing,'p:seq')):
        if any(c.getAttribute('nodeType')=='interactiveSeq' for c in els(node,'p:cTn')) and any(s.getAttribute('spid')=='21' for s in els(node,'p:spTgt')):node.parentNode.removeChild(node)
    mainseq=next(n for n in els(timing,'p:cTn') if n.getAttribute('nodeType')=='mainSeq')
    mainchildren=first(mainseq,'p:childTnLst')
    for n in list(mainchildren.childNodes):
        if n.nodeType==n.ELEMENT_NODE and any(s.getAttribute('spid')=='21' for s in els(n,'p:spTgt')):mainchildren.removeChild(n)
    for n in els(timing,'p:cTn'):
        if n.getAttribute('dur')=='10000':n.setAttribute('dur','14042')
    doc=minidom.parseString(xml(f'<p:sld {b.DECL} xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" showMasterSp="0" mc:Ignorable="a14"><p:cSld><p:bg><p:bgPr>{b.fill("FFFFFF")}<a:effectLst/></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'+pic.toxml()+'</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'+timing.toxml()+'</p:sld>'))
    pic=first(doc,'p:pic');o=Overlay(doc,pic,1440,810,100)
    boxes=[(100,85,650,330),(800,85,1350,330),(100,480,650,725),(800,480,1350,725)]
    def axes(box,xlim,ylim,xticks,yticks,title,xlabel,ylabel):
        l,top,r,bot=box;o.text(title,(l+r)/2,top-29,25,bold=True)
        for val in xticks:o.text(f'{val:g}',l+(val-xlim[0])/(xlim[1]-xlim[0])*(r-l),bot+21,14)
        for val in yticks:
            o.text(f'{val:g}',l-32,bot-(val-ylim[0])/(ylim[1]-ylim[0])*(bot-top),14,width=40)
            o.parts[-1]=o.parts[-1].replace('algn="ctr"','algn="r"')
        o.equation('Horizontal axis '+title,(l+r)/2,bot+55,xlabel,20,width=200)
        o.equation('Vertical axis '+title,l-65,(top+bot)/2,ylabel,20,width=200,angle=-90)
    for k,lim in enumerate([1150,700]):
        tag=['S','G'][k]
        def sig(m,s,tag=tag):return m.sub(m.r(s),m.r(tag,plain=True))+m.d(m.r('t'))
        axes(boxes[k],[-lim,lim],[-lim,lim],[-lim,0,lim],[-lim,0,lim],['STN nonlinearity','GPe nonlinearity'][k],lambda m,s=sig:s(m,'z'),lambda m,s=sig:s(m,'w'))
    axes(boxes[2],[0,.4],[-20,100],np.arange(9)*.05,range(-20,101,20),'Response',lambda m:m.r('t')+m.r(' (s)',plain=True),lambda m:m.r('spikes/s',plain=True))
    for k,tag in enumerate(['S','G']):
        o.equation('Response legend '+tag,224,495+k*14,lambda m,tag=tag:m.sub(m.r('x'),m.r(tag,plain=True))+m.r(' (STN)' if tag=='S' else ' (GPe / Proto)',plain=True),12,width=170)
        o.parts[-1]=o.parts[-1].replace('algn="ctr"','algn="l"').replace('m:val="center"','m:val="left"')
    def integral(m):return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('T')+'</m:sup><m:e>'+m.r('σ')+m.d(m.r('t'))+m.r(' dt')+'</m:e></m:nary>'
    axes(boxes[3],[0,.4],[0,3200],[0,.1,.2,.3,.4],[0,1000,2000,3000],'Supply function',lambda m:m.r('T')+m.r(' (s)',plain=True),integral)
    insert_parts(doc,o.parts)
    number=max(int(re.search(r'slide(\d+)',n)[1]) for n in files if re.match(r'ppt/slides/slide\d+\.xml$',n))+1
    files[f'ppt/slides/slide{number}.xml']=doc.toxml(encoding='utf-8')
    files['ppt/media/sector_clean.mp4']=(OUT/'sector_clean.mp4').read_bytes();files['ppt/media/sector_clean.png']=(OUT/'sector_clean.png').read_bytes()
    files[f'ppt/slides/_rels/slide{number}.xml.rels']=xml(f'<Relationships xmlns="{PKG}"><Relationship Id="rIdLayout" Type="{b.NS["r"]}/slideLayout" Target="../slideLayouts/slideLayout12.xml"/><Relationship Id="rIdPoster" Type="{b.NS["r"]}/image" Target="../media/sector_clean.png"/><Relationship Id="rIdVideo" Type="{b.NS["r"]}/video" Target="../media/sector_clean.mp4"/><Relationship Id="rIdMedia" Type="http://schemas.microsoft.com/office/2007/relationships/media" Target="../media/sector_clean.mp4"/></Relationships>')
    pres=minidom.parseString(files['ppt/presentation.xml']);lst=first(pres,'p:sldIdLst');ids=els(lst,'p:sldId')
    n=pres.createElement('p:sldId');n.setAttribute('id',str(max(int(i.getAttribute('id')) for i in ids)+1));n.setAttributeNS(b.NS['r'],'r:id','rIdSectorSimulation');lst.insertBefore(n,ids[24])
    files['ppt/presentation.xml']=pres.toxml(encoding='utf-8')
    rel=minidom.parseString(files['ppt/_rels/presentation.xml.rels']);rr=rel.createElement('Relationship');rr.setAttribute('Id','rIdSectorSimulation');rr.setAttribute('Type',b.NS['r']+'/slide');rr.setAttribute('Target',f'slides/slide{number}.xml');rel.documentElement.appendChild(rr);files['ppt/_rels/presentation.xml.rels']=rel.toxml(encoding='utf-8')
    ct=minidom.parseString(files['[Content_Types].xml']);ov=ct.createElement('Override');ov.setAttribute('PartName',f'/ppt/slides/slide{number}.xml');ov.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');ct.documentElement.appendChild(ov);files['[Content_Types].xml']=ct.toxml(encoding='utf-8')
    b.add_notes(files,number,'Parkinsonian GPe-STN sector simulation. Each channel satisfies q_i=w_i(beta_i*z_i-w_i)>=0. The supply function panel plots the accumulated supply integral, giving the hard IQC and dissipativity with zero storage. beta_S=0.7344121335837432, beta_G=0.7048314668921489. Click to play the embedded clean 4K video; all text and math labels are editable PowerPoint overlays.')
    return number,o.count

def main():
    report=json.loads((OUT/'report.json').read_text());path=Path(report['output'])
    with zipfile.ZipFile(path) as z:files={n:z.read(n) for n in z.namelist()}
    notes={n:v for n,v in files.items() if n.startswith('ppt/notesSlides/')}
    tracks=carts(files);number,labels=sector_slide(files)
    for n,v in notes.items():assert files[n]==v,n
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        for n,v in files.items():z.writestr(n,v)
    report.update(cart_motion_overlays=tracks,simulation_slide_part=number,simulation_slide_position=25,simulation_native_labels=labels,video_resolution='3840x2160')
    (OUT/'report.json').write_text(json.dumps(report,indent=2));print('Embedded 3 clean 4K videos with native overlays; simulation is slide 25.')
if __name__=='__main__':main()
