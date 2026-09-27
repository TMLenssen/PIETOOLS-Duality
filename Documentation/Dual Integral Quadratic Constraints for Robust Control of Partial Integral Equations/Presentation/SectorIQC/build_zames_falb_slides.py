"""Two clean simulation slides, with embedded video and native math/text labels."""
from pathlib import Path
from xml.dom import minidom
import sys,zipfile,posixpath
import numpy as np
from simulate_zames_falb import OUT

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from build_image_overlays import b,Overlay,els,first,xml,PKG
from build_video_overlays import insert_parts,namespaces

def main():
    with zipfile.ZipFile(b.SOURCE) as z:
        candidates=[n for n in z.namelist() if n.startswith('ppt/slides/_rels/') and b'.mp4' in z.read(n) and b'Sector simulation' in z.read(n.replace('/_rels','').removesuffix('.rels'))]
        assert len(candidates)==1
        source=posixpath.dirname(posixpath.dirname(candidates[0]))+'/'+posixpath.basename(candidates[0]).removesuffix('.rels')
        source_slide=z.read(source)
    with zipfile.ZipFile(b.SOURCE.parent/'Sector IQC - Editable.pptx') as z:
        files={n:z.read(n) for n in z.namelist() if not n.startswith(('ppt/slides/','ppt/notesSlides/'))}
    pres=minidom.parseString(files['ppt/presentation.xml']);lst=first(pres,'p:sldIdLst')
    for n in list(lst.childNodes):lst.removeChild(n)
    rel=minidom.parseString(files['ppt/_rels/presentation.xml.rels'])
    for n in list(els(rel,'Relationship')):
        if n.getAttribute('Type').endswith('/slide'):n.parentNode.removeChild(n)
    ct=minidom.parseString(files['[Content_Types].xml'])
    for n in list(els(ct,'Override')):
        if n.getAttribute('PartName').startswith(('/ppt/slides/','/ppt/notesSlides/')):n.parentNode.removeChild(n)
    for ext,kind in [('mp4','video/mp4'),('png','image/png')]:
        if not any(n.getAttribute('Extension')==ext for n in els(ct,'Default')):
            n=ct.createElement('Default');n.setAttribute('Extension',ext);n.setAttribute('ContentType',kind);ct.documentElement.appendChild(n)
    for number,rate in enumerate([False,True],1):
        suffix='rate' if rate else 'integral'
        doc=minidom.parseString(source_slide);namespaces(doc)
        tree=first(doc,'p:spTree')
        for n in list(tree.childNodes):
            if getattr(n,'tagName','') not in ['p:nvGrpSpPr','p:grpSpPr','p:pic']:tree.removeChild(n)
        pic=first(doc,'p:pic');first(pic,'p:cNvPr').setAttribute('name','Zames-Falb '+suffix+' video')
        first(pic,'a:blip').setAttributeNS(b.NS['r'],'r:embed','rIdPoster')
        first(pic,'a:videoFile').setAttributeNS(b.NS['r'],'r:link','rIdVideo')
        first(pic,'p14:media').setAttributeNS(b.NS['r'],'r:embed','rIdMedia')
        o=Overlay(doc,pic,1440,810,100)
        def axes(box,xlim,ylim,xticks,yticks,title,xlabel,ylabel):
            l,top,r,bot=box;o.text(title,(l+r)/2,top-29,27,bold=True)
            for v in xticks:o.text(f'{v:g}',l+(v-xlim[0])/(xlim[1]-xlim[0])*(r-l),bot+23,20,width=65)
            for v in yticks:
                o.text(f'{v:g}',l-12,bot-(v-ylim[0])/(ylim[1]-ylim[0])*(bot-top),20,width=95)
                # Align the right edge precisely at l-12; room for six-digit tick values.
                o.parts[-1]=o.parts[-1].replace('algn="ctr"','algn="r"')
                shape=minidom.parseString(f'<root {b.DECL}>'+o.parts[-1]+'</root>')
                xf=first(shape,'a:xfrm');off=first(xf,'a:off')
                off.setAttribute('x',b.emu(o.point(l-12-95,0)[0]))
                o.parts[-1]=shape.documentElement.firstChild.toxml()
            o.equation('Horizontal axis '+title,(l+r)/2,bot+58,xlabel,24,width=250)
            o.equation('Vertical axis '+title,l-(105 if title.startswith('Supply') else 83),(top+bot)/2,ylabel,24,width=260,angle=-90)
        boxes=[(100,85,650,330),(800,85,1350,330),(100,480,650,725),(800,480,1350,725)]
        for k,lim in enumerate([1150,700]):
            tag=['S','G'][k]
            def sig(m,s,tag=tag):return m.sub(m.r(s),m.r(tag,plain=True))+m.d(m.r('t'))
            axes(boxes[k],[-lim,lim],[-lim,lim],[-lim,0,lim],[-lim,0,lim],['STN nonlinearity','GPe nonlinearity'][k],lambda m,s=sig:s(m,'z'),lambda m,s=sig:s(m,'w'))
        axes(boxes[2],[0,.4],[-20,100],np.arange(9)*.05,range(-20,101,20),'Response',lambda m:m.r('t')+m.r(' (s)',plain=True),lambda m:m.r('spikes/s',plain=True))
        for k,tag in enumerate(['S','G']):
            o.equation('Response legend '+tag,218,495+k*24,lambda m,tag=tag:m.sub(m.r('x'),m.r(tag,plain=True))+m.r(' (STN)' if tag=='S' else ' (GPe)',plain=True),20,width=145)
        def supply(m):return m.sub(m.r('σ'),m.r('i'))+m.d(m.r('t'))
        def integ(m):return '<m:nary><m:naryPr><m:chr m:val="∫"/><m:limLoc m:val="subSup"/>'+m.ctrl()+'</m:naryPr><m:sub>'+m.r('0',plain=True)+'</m:sub><m:sup>'+m.r('T')+'</m:sup><m:e>'+supply(m)+m.r(' dt')+'</m:e></m:nary>'
        axes(boxes[3],[0,.4],[-10000,100000] if rate else [0,6000],[0,.1,.2,.3,.4],[0,50000,100000] if rate else [0,2000,4000,6000],'Supply rate' if rate else 'Supply function',lambda m:m.r('t' if rate else 'T')+m.r(' (s)',plain=True),supply if rate else integ)
        for k,tag in enumerate(['STN','GPe']):o.text(tag,885,495+k*24,20,width=75)
        insert_parts(doc,o.parts)
        files[f'ppt/slides/slide{number}.xml']=doc.toxml(encoding='utf-8')
        files[f'ppt/media/zf_{suffix}.mp4']=(OUT/f'Zames-Falb {suffix}.mp4').read_bytes()
        files[f'ppt/media/zf_{suffix}.png']=(OUT/f'Zames-Falb {suffix}.png').read_bytes()
        files[f'ppt/slides/_rels/slide{number}.xml.rels']=xml(f'<Relationships xmlns="{PKG}"><Relationship Id="rIdLayout" Type="{b.NS["r"]}/slideLayout" Target="../slideLayouts/slideLayout12.xml"/><Relationship Id="rIdPoster" Type="{b.NS["r"]}/image" Target="../media/zf_{suffix}.png"/><Relationship Id="rIdVideo" Type="{b.NS["r"]}/video" Target="../media/zf_{suffix}.mp4"/><Relationship Id="rIdMedia" Type="http://schemas.microsoft.com/office/2007/relationships/media" Target="../media/zf_{suffix}.mp4"/></Relationships>')
        n=pres.createElement('p:sldId');n.setAttribute('id',str(255+number));n.setAttributeNS(b.NS['r'],'r:id',f'rIdZF{number}');lst.appendChild(n)
        n=rel.createElement('Relationship');n.setAttribute('Id',f'rIdZF{number}');n.setAttribute('Type',b.NS['r']+'/slide');n.setAttribute('Target',f'slides/slide{number}.xml');rel.documentElement.appendChild(n)
        n=ct.createElement('Override');n.setAttribute('PartName',f'/ppt/slides/slide{number}.xml');n.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');ct.documentElement.appendChild(n)
    for key,d in [('ppt/presentation.xml',pres),('ppt/_rels/presentation.xml.rels',rel),('[Content_Types].xml',ct)]:files[key]=d.toxml(encoding='utf-8')
    note=(OUT/'README.md').read_text(encoding='utf-8')
    for i in [1,2]:b.add_notes(files,i,note+'\nBlue = STN; red = GPe. Click the video to play. Labels and math are editable native PowerPoint shapes.')
    target=OUT/'Zames-Falb - Editable.pptx'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for name,value in files.items():z.writestr(name,value)
    print(target)

if __name__=='__main__':main()
