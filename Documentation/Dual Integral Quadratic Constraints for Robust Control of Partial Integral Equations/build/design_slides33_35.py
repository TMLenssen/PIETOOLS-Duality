from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
from xml.sax.saxutils import escape
import json
B=Path('build/slides33_34')
INK='252529'; BLUE='245A91'; TEAL='087F8C'; RED='C81919'; AMBER='B76316'; GRAY='66717C'
NS={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships','m':'http://schemas.openxmlformats.org/officeDocument/2006/math','a14':'http://schemas.microsoft.com/office/drawing/2010/main','mc':'http://schemas.openxmlformats.org/markup-compatibility/2006'}
def u(x):return str(round(x*12700))
def fragment(s):return D.parseString('<root '+' '.join(f'xmlns:{k}="{v}"' for k,v in NS.items())+'>'+s+'</root>').documentElement.firstChild

def rp(size=18,color=INK):return f'<a:rPr lang="en-US" sz="{round(size*100)}"><a:solidFill><a:srgbClr val="{color}"/></a:solidFill><a:latin typeface="Cambria Math"/></a:rPr>'
def r(t,color=None):return ''.join('<m:r><m:rPr><m:sty m:val="p"/></m:rPr>'+rp(SZ,color or COL)+'<m:t xml:space="preserve">'+escape(c)+'</m:t></m:r>' for c in t)
def ctrl():return '<m:ctrlPr>'+rp(SZ,COL)+'</m:ctrlPr>'
def sub(e,s):return '<m:sSub><m:sSubPr>'+ctrl()+'</m:sSubPr><m:e>'+e+'</m:e><m:sub>'+s+'</m:sub></m:sSub>'
def sup(e,s):return '<m:sSup><m:sSupPr>'+ctrl()+'</m:sSupPr><m:e>'+e+'</m:e><m:sup>'+s+'</m:sup></m:sSup>'
def acc(e,char='̇'):return '<m:acc><m:accPr><m:chr m:val="'+char+'"/>'+ctrl()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
def bar(e):return '<m:bar><m:barPr><m:pos m:val="bot"/>'+ctrl()+'</m:barPr><m:e>'+e+'</m:e></m:bar>'
def delim(e,left='(',right=')'):return '<m:d><m:dPr><m:begChr m:val="'+left+'"/><m:endChr m:val="'+right+'"/>'+ctrl()+'</m:dPr><m:e>'+e+'</m:e></m:d>'
def mat(rows):
 m='<m:m><m:mPr>'+ctrl()+'</m:mPr>'
 for row in rows:m+='<m:mr>'+''.join('<m:e>'+e+'</m:e>' for e in row)+'</m:mr>'
 return delim(m+'</m:m>','[',']')
def st(e):return sup(e,r('*'))
def tr(e):return sup(e,r('⊤'))
def bu():return sub(r('𝐵'),r('u'))
def theta():return r('Θ',TEAL)
def kval():return r('𝐾',BLUE)
def dt():return r('𝐃',TEAL)+delim(theta())

def shape(sid,name,x,y,w,h,body,fill=None,border=None,math=False):
 fillxml=f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else '<a:noFill/>'
 linexml=f'<a:ln w="12700"><a:solidFill><a:srgbClr val="{border}"/></a:solidFill></a:ln>' if border else '<a:ln><a:noFill/></a:ln>'
 xml=f'<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="{name}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="{u(x)}" y="{u(y)}"/><a:ext cx="{u(w)}" cy="{u(h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{fillxml}{linexml}</p:spPr><p:txBody><a:bodyPr wrap="square" lIns="0" tIns="0" rIns="0" bIns="0" anchor="ctr"><a:noAutofit/></a:bodyPr><a:lstStyle/>{body}</p:txBody></p:sp>'
 if math:
  fallback=xml.replace(body,'<a:p><a:r><a:rPr sz="1800"/><a:t>Editable equation (requires current PowerPoint)</a:t></a:r></a:p>')
  xml='<mc:AlternateContent><mc:Choice Requires="a14">'+xml+'</mc:Choice><mc:Fallback>'+fallback+'</mc:Fallback></mc:AlternateContent>'
 return fragment(xml)
class Slide:
 def __init__(self,doc,num):
  self.doc=doc;self.num=num;self.tree=doc.getElementsByTagName('p:spTree')[0];self.sid=300
  for k,v in NS.items():doc.documentElement.setAttribute('xmlns:'+k,v)
 def add(self,node):self.tree.appendChild(self.doc.importNode(node,True))
 def text(self,name,x,y,w,h,text,size=16,color=INK,bold=False,fill=None):
  self.sid+=1
  body=''
  for line in text.split('\n'):
   body+=f'<a:p><a:pPr algn="l"/><a:r><a:rPr lang="en-US" sz="{round(size*100)}" b="{int(bold)}"><a:solidFill><a:srgbClr val="{color}"/></a:solidFill><a:latin typeface="Aptos"/></a:rPr><a:t>{escape(line)}</a:t></a:r></a:p>'
  self.add(shape(self.sid,name,x,y,w,h,body,fill))
 def eq(self,name,x,y,w,h,fn,size=18,color=INK):
  global SZ,COL
  SZ=size;COL=color;body='<a:p><a:pPr algn="l"/><a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="left"/></m:oMathParaPr><m:oMath>'+fn()+'</m:oMath></m:oMathPara></a14:m><a:endParaRPr sz="'+str(round(size*100))+'"><a:latin typeface="Cambria Math"/></a:endParaRPr></a:p>'
  self.sid+=1;self.add(shape(self.sid,name,x,y,w,h,body,math=True))
 def title(self,title,subtitle):
  self.text('Slide title',36,25,648,42,title,25,INK,True)
  self.text('Subtitle',36,70,648,22,subtitle,12.5,GRAY)
 def header(self,stage,y,text,color=BLUE):self.text(f'Stage{stage} heading',354,y,330,20,text,14,color,True)
 def band(self,stage,text,color=TEAL,bg='EAF5F5'):
  self.text(f'Stage{stage} takeaway background',36,337,648,35,'',fill=bg)
  self.text(f'Stage{stage} takeaway',48,343,624,23,text,16,color,True)

def shapeid(node):
 ids=node.getElementsByTagName('p:cNvPr') if node.nodeType==node.ELEMENT_NODE else []
 return ids[0].getAttribute('id') if ids else None

def recolor(node,colors):
 for c in list(node.getElementsByTagName('p:cNvPr')):
  sid=c.getAttribute('id')
  if sid not in colors:continue
  s=c.parentNode.parentNode;color=colors[sid]
  for f in s.getElementsByTagName('a:srgbClr'):
   # Only recolor strokes/text, never the white block fill.
   if f.getAttribute('val').upper()!='FFFFFF':f.setAttribute('val',color)

def prepare(doc,num):
 tree=doc.getElementsByTagName('p:spTree')[0]
 diagram=[]
 keep={'5','34','35','36','37','52','53','55','61','200','201'}
 for node in list(tree.childNodes):
  if node.nodeType!=node.ELEMENT_NODE:continue
  sid=shapeid(node)
  if sid in keep:diagram.append(node);tree.removeChild(node)
  elif sid not in {'1','3','4',None}:tree.removeChild(node)
 for t in list(doc.getElementsByTagName('p:timing')):t.parentNode.removeChild(t)
 s=Slide(doc,num)
 if num!=35:
  # One outer transform preserves every diagram route and relative block position.
  grp=fragment('<p:grpSp><p:nvGrpSpPr><p:cNvPr id="250" name="Controller interconnection"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="'+u(42)+'" y="'+u(147)+'"/><a:ext cx="'+u(271)+'" cy="'+u(178.3)+'"/><a:chOff x="'+u(36)+'" y="'+u(103.00386)+'"/><a:chExt cx="'+u(335.34)+'" cy="'+u(220.715)+'"/></a:xfrm></p:grpSpPr></p:grpSp>')
  for item in diagram:grp.appendChild(item.cloneNode(True))
  fc=TEAL if num==33 else AMBER
  recolor(grp,{'17':BLUE,'18':BLUE,'113':BLUE,'52':fc,'53':fc,'34':fc,'35':fc,'36':fc,'37':fc,'55':fc,'61':fc,'200':fc,'201':fc})
  s.add(grp)
 else:
  for field in doc.getElementsByTagName('a:fld'):
   if field.getAttribute('type')=='slidenum':
    for t in field.getElementsByTagName('a:t'):
     if t.firstChild:t.firstChild.data='35'
 return s

with ZipFile(B/'original.pptx') as zin:
 d33=D.parseString(zin.read('ppt/slides/slide33.xml'));d34=D.parseString(zin.read('ppt/slides/slide34.xml'));d35=D.parseString(zin.read('ppt/slides/slide33.xml'))
 s=prepare(d33,33)
 s.title('The controller gives a zero residual','Encode the exact feedback law as a constraint on the filtered signals.')
 s.eq('Plant equation',43,101,294,24,lambda:r('𝑇')+acc(r('𝑥'))+r('=𝐴𝑥+')+bu()+r('𝑢'),16)
 s.eq('Measured state',43,126,240,20,lambda:r('𝑦=𝑥'),15)
 s.header(1,101,'1  Encode the controller')
 s.eq('Stage1 filter',365,126,306,48,lambda:theta()+r('=')+mat([[r('𝐼'),r('0')],[r('−')+kval(),r('𝐼')]]),19)
 s.header(2,185,'2  Impose the feedback law')
 s.eq('Stage2 output',365,208,310,23,lambda:acc(r('𝑦'),'̃')+r('=𝑦=𝑥'),18)
 s.eq('Stage2 residual',365,237,310,26,lambda:r('𝑢=')+kval()+r('𝑦  ⇒  ')+acc(r('𝑢',TEAL),'̃')+r('=𝑢−')+kval()+r('𝑦=0',TEAL),18)
 s.header(3,278,'3  Recover the closed loop')
 s.eq('Stage3 dynamics',365,302,310,25,lambda:r('𝑇')+acc(r('𝑥'))+r('=')+delim(r('𝐴+')+bu()+kval())+r('𝑥'),18)
 s.band(3,'The residual vanishes because the controller enforces u = Ky.')
 s=prepare(d34,34)
 s.title('Simply transposing is not enough','A transpose must act on the complete interconnection, not just its blocks.')
 s.text('Naive diagram label',43,111,283,25,'NAIVE FILTER REPLACEMENT',12,AMBER,True)
 s.header(1,101,'1  Transpose the filter',AMBER)
 s.eq('Stage1 transpose',365,127,310,48,lambda:tr(theta())+r('=')+mat([[r('𝐼'),r('−')+st(kval())],[r('0'),r('𝐼')]]),19)
 s.header(2,185,'2  Transpose the complete map',AMBER)
 s.eq('Stage2 original map',365,208,310,44,lambda:r('𝐹:=')+theta()+mat([[r('𝐺')],[r('𝐼')]]),18)
 s.eq('Stage2 reversed order',365,261,310,39,lambda:tr(r('𝐹'))+r('=')+mat([[tr(r('𝐺')),r('𝐼')]])+tr(theta()),20)
 s.text('Stage2 order explanation',365,307,310,20,'The order reverses; the column becomes a row.',12.5,AMBER)
 s.band(3,'This is not the dual filtered interconnection.',RED,'FBEDEE')
 s=prepare(d35,35)
 s.title('Use the dual filter','Transform the filter so that the dual plant retains a filtered-graph representation.')
 s.text('Stage1 definition label',43,105,265,22,'1  TRANSFORM THE FILTER',13,TEAL,True)
 s.eq('Stage1 definition',44,135,365,45,lambda:dt()+r(':=')+sup(delim(st(acc(r('𝐽'),'̂'))+tr(theta())+acc(r('𝐽'),'̂')),r('−1')),23)
 s.eq('Stage1 exchange matrix',452,128,215,55,lambda:acc(r('𝐽'),'̂')+r('=')+mat([[r('0'),r('𝐼')],[r('−𝐼'),r('0')]]),18)
 s.text('Stage2 example label',43,204,275,20,'2  FOR THIS CONTROLLER',13,TEAL,True)
 s.eq('Stage2 concrete dual filter',45,233,271,47,lambda:dt()+r('=')+mat([[r('𝐼'),r('0')],[r('−')+st(kval()),r('𝐼')]]),21)
 s.eq('Stage2 dual residual',349,220,335,36,lambda:dt()+mat([[bar(r('𝑦'))],[bar(r('𝑢'))]])+r('=')+mat([[bar(r('𝑦'))],[bar(r('𝑢'))+r('−')+st(kval())+bar(r('𝑦'))]]),17)
 s.eq('Stage2 residual zero',353,267,322,26,lambda:bar(r('𝑢'))+r('=')+st(kval())+bar(r('𝑦'))+r('  ⇒  ')+acc(bar(r('𝑢',TEAL)),'̃')+r('=0',TEAL),17)
 s.eq('Stage3 correct dual dynamics',116,300,570,29,lambda:st(r('𝑇'))+acc(bar(r('𝑥')))+r('=')+delim(st(r('𝐴'))+r('+')+st(kval())+st(bu()))+bar(r('𝑥')),21)
 s.band(3,'The zero residual now recovers the correct dual closed loop.')
 # Document-local slide insertion directly after slide 34.
 pres=D.parseString(zin.read('ppt/presentation.xml'));lst=pres.getElementsByTagName('p:sldIdLst')[0]
 rels=D.parseString(zin.read('ppt/_rels/presentation.xml.rels'))
 rid='rId'+str(max(int(e.getAttribute('Id')[3:]) for e in rels.getElementsByTagName('Relationship'))+1)
 rr=rels.createElement('Relationship');rr.setAttribute('Id',rid);rr.setAttribute('Type',NS['r']+'/slide');rr.setAttribute('Target','slides/slide45.xml');rels.documentElement.appendChild(rr)
 entries=[n for n in lst.childNodes if n.nodeType==n.ELEMENT_NODE]
 new=pres.createElement('p:sldId');new.setAttribute('id',str(max(int(n.getAttribute('id')) for n in entries)+1));new.setAttributeNS(NS['r'],'r:id',rid);lst.insertBefore(new,entries[34])
 types=D.parseString(zin.read('[Content_Types].xml'));ov=types.createElement('Override');ov.setAttribute('PartName','/ppt/slides/slide45.xml');ov.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');types.documentElement.appendChild(ov)
 edits={'ppt/slides/slide33.xml':d33.toxml(encoding='UTF-8'),'ppt/slides/slide34.xml':d34.toxml(encoding='UTF-8'),'ppt/slides/slide45.xml':d35.toxml(encoding='UTF-8'),'ppt/presentation.xml':pres.toxml(encoding='UTF-8'),'ppt/_rels/presentation.xml.rels':rels.toxml(encoding='UTF-8'),'[Content_Types].xml':types.toxml(encoding='UTF-8'),'ppt/slides/_rels/slide45.xml.rels':b'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout12.xml"/></Relationships>'}
 with ZipFile(B/'staged.pptx','w') as zout:
  for info in zin.infolist():zout.writestr(info,edits.pop(info.filename,zin.read(info.filename)))
  for name,data in edits.items():zout.writestr(name,data)
print('Prepared slides 33–35 with editable equations and preserved diagram geometry.')



