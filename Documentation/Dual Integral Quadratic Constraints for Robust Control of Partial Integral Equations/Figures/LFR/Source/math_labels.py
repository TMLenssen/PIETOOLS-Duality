"""Convert all LFR library labels to editable Office Math."""
from pathlib import Path
from copy import deepcopy
from xml.dom import minidom
from xml.sax.saxutils import escape
import zipfile, json, hashlib, unicodedata

ROOT=Path(__file__).resolve().parents[3]
STAGE=ROOT/'build/math_lfr'
MASTER=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\LFR - Editable.pptx')
M='http://schemas.openxmlformats.org/officeDocument/2006/math'
A14='http://schemas.microsoft.com/office/drawing/2010/main'
MC='http://schemas.openxmlformats.org/markup-compatibility/2006'

def omml(runs,size,color):
    def props():return f'<a:rPr sz="{size}"><a:solidFill><a:srgbClr val="{color}"/></a:solidFill><a:latin typeface="Cambria Math"/></a:rPr>'
    def control():return '<m:ctrlPr>'+props()+'</m:ctrlPr>'
    def mr(t,italic=False,bold=False):
        sty=('bi' if italic else 'b') if bold else ('i' if italic else 'p')
        return f'<m:r><m:rPr><m:sty m:val="{sty}"/></m:rPr>{props()}<m:t>{escape(t)}</m:t></m:r>'
    def acc(e,accent):return '<m:acc><m:accPr><m:chr m:val="'+accent+'"/>'+control()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
    def bar(e):return '<m:bar><m:barPr><m:pos m:val="bot"/>'+control()+'</m:barPr><m:e>'+e+'</m:e></m:bar>'
    def delimiter(e,beg='‖',end='‖'):
        return f'<m:d><m:dPr><m:begChr m:val="{beg}"/><m:endChr m:val="{end}"/>{control()}</m:dPr><m:e>'+e+'</m:e></m:d>'
    atoms=[]; stack=[]
    for r in runs:
        t=r['text'];baseline=r['base']
        if baseline:
            script=''.join(mr(c,r['italic'],r['bold']) for c in t)
            prev=atoms.pop()
            if baseline>0 and isinstance(prev,tuple):
                base,sub=prev
                atoms.append('<m:sSubSup><m:sSubSupPr>'+control()+'</m:sSubSupPr><m:e>'+base+'</m:e><m:sub>'+sub+'</m:sub><m:sup>'+script+'</m:sup></m:sSubSup>')
            elif baseline<0:
                if isinstance(prev,tuple):atoms.append((prev[0],prev[1]+script))
                else:atoms.append((render(prev),script))
            else:atoms.append('<m:sSup><m:sSupPr>'+control()+'</m:sSupPr><m:e>'+render(prev)+'</m:e><m:sup>'+script+'</m:sup></m:sSup>')
            continue
        chars=list(unicodedata.normalize('NFD',t))
        for j,c in enumerate(chars):
            if c.isspace() or c in ('\u0303','\u0302'):continue
            if c=='‖':
                if stack and stack[-1][0]=='‖':
                    _,outer=stack.pop();inner=''.join(map(render,atoms));atoms=outer;atoms.append(delimiter(inner))
                else:stack.append(('‖',atoms));atoms=[]
                continue
            if c=='(':
                stack.append(('(',atoms));atoms=[];continue
            if c==')' and stack and stack[-1][0]=='(':
                _,outer=stack.pop();inner=''.join(map(render,atoms));atoms=outer;atoms.append(delimiter(inner,'(',')'));continue
            e=mr(c,r['italic'],r['bold'])
            if r['under']:e=bar(e)
            if j+1<len(chars) and chars[j+1] in ('\u0303','\u0302'):e=acc(e,chars[j+1])
            atoms.append(e)
    assert not stack,stack
    body=''.join(map(render,atoms))
    return '<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+body+'</m:oMath></m:oMathPara></a14:m>'

def render(e):
    if isinstance(e,tuple):return '<m:sSub><m:e>'+e[0]+'</m:e><m:sub>'+e[1]+'</m:sub></m:sSub>'
    return e

def main():
    STAGE.mkdir(exist_ok=True,parents=True)
    with zipfile.ZipFile(MASTER) as z:files={n:z.read(n) for n in z.namelist()}
    original=dict(files);count=0
    for i in range(1,20):
        key=f'ppt/slides/slide{i}.xml';doc=minidom.parseString(files[key]);root=doc.documentElement
        root.setAttribute('xmlns:m',M);root.setAttribute('xmlns:a14',A14)
        root.setAttribute('xmlns:mc',MC);root.setAttribute('mc:Ignorable','a14')
        for shape in doc.getElementsByTagName('p:sp'):
            runs=shape.getElementsByTagName('a:r')
            if not runs:continue
            latin=runs[0].getElementsByTagName('a:latin')
            name=shape.getElementsByTagName('p:cNvPr')[0].getAttribute('name')
            if not latin or (latin[0].getAttribute('typeface')!='Cambria Math' and not name.startswith('Editable label:')):continue
            if name in ('Filtering equivalence','Gain duality'):continue
            rr=[]
            for r in runs:
                pr=r.getElementsByTagName('a:rPr')[0]
                rr.append(dict(text=''.join(x.firstChild.data for x in r.getElementsByTagName('a:t') if x.firstChild),
                    base=int(pr.getAttribute('baseline') or 0),size=int(pr.getAttribute('sz')),
                    italic=pr.getAttribute('i')=='1',bold=pr.getAttribute('b')=='1',under=pr.getAttribute('u')=='sng'))
            size=max(r['size'] for r in rr);color=runs[0].getElementsByTagName('a:srgbClr')[0].getAttribute('val')
            math=omml(rr,size,color)
            temp=minidom.parseString(f'<wrap xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:m="{M}" xmlns:a14="{A14}">{math}</wrap>')
            para=shape.getElementsByTagName('a:p')[0]
            for r in list(runs):para.removeChild(r)
            end=para.getElementsByTagName('a:endParaRPr')[0]
            para.insertBefore(doc.importNode(temp.documentElement.firstChild,True),end)
            count+=1
        files[key]=doc.toxml(encoding='utf-8')
    assert count>130,count
    assert all(files[n]==b for n,b in original.items() if n not in [f'ppt/slides/slide{i}.xml' for i in range(1,20)])
    with zipfile.ZipFile(STAGE/'LFR - Editable.pptx','w',zipfile.ZIP_DEFLATED) as z:
        for n,b in files.items():z.writestr(n,b)
    rows=json.loads((ROOT/'Figures/LFR/Source/index.json').read_text())
    rows.append(dict(slide=16,asset='16-pde-to-pie-conversion'))
    rows.extend(json.loads((ROOT/'Figures/LFR/Source/paper_figures.json').read_text()))
    (STAGE/'manifest.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256(MASTER.read_bytes()).hexdigest(),diagrams=rows,equations=count),indent=2))
    print(f'Converted {count} editable mathematical labels; all other library parts unchanged.')

if __name__=='__main__':main()
