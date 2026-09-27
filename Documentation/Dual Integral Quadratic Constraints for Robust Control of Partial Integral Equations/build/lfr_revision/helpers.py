def run(self,s,c=None,plain=False):return ''.join('<m:r><m:rPr><m:sty m:val="'+('p' if plain else 'i')+'"/></m:rPr>'+self.pr(c)+'<m:t xml:space="preserve">'+escape(ch)+'</m:t></m:r>' for ch in s)
b.Math.r=run
def sub(m,s,i):return m.sub(m.r(s),m.r(i,plain=True))
def sig(m,s,i):return sub(m,s,i)+m.d(m.r('t'))
def history(m,i):return sub(m,'φ',i)+m.d(m.r('t')+m.r(',1',plain=True))
def dot(m,e):return '<m:acc><m:accPr><m:chr m:val="̇"/>'+m.ctrl()+'</m:accPr><m:e>'+e+'</m:e></m:acc>'
def eqxml(name,x,y,fn,size=18,width=500,color='252529'):
 global ident
 ident+=1;m=b.Math(size,color);s=b.lib.tb(ident,name,(x-width/2,y-size*1.15,width,size*2.3),'',size,color)
 eq='<a14:m><m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr><m:oMath>'+fn(m)+'</m:oMath></m:oMathPara></a14:m>'
 return re.sub(r'<a:r>.*?</a:r>',lambda _:eq,s)
def eq(name,x,y,fn,size=18,width=500,color='252529',start=0,end=5):return register(frag(eqxml(name,x,y,fn,size,width,color)),name,start,end)
def group(name,contents,box,start=0,end=5):
 global ident
 ident+=1;x,y,w,h=box
 node=frag(f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{ident}" name="{name}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="{b.emu(x)}" y="{b.emu(y)}"/><a:ext cx="{b.emu(w)}" cy="{b.emu(h)}"/><a:chOff x="{b.emu(x)}" y="{b.emu(y)}"/><a:chExt cx="{b.emu(w)}" cy="{b.emu(h)}"/></a:xfrm></p:grpSpPr>'+''.join(contents)+'</p:grpSp>')
 return register(node,name,start,end)
def diagramgroup(name,fn,box,start,end=5):
 global ident
 d=b.Slide();d.i=ident+1;fn(d);ident=d.i+1;return group(name,d.parts,box,start,end)
def text(name,x,y,t,size=14,width=640,color='747B82',start=0,end=5):
 return register(frag(b.lib.tb(1,name,(x-width/2,y-size*.85,width,size*1.7),t,size,color,'Aptos')),name,start,end)
def zline(m,i):
 if i=='S':return sig(m,'z','S')+m.r('=−')+sub(m,'w','GS')+history(m,'GS')
 return sig(m,'z','G')+m.r('=')+sub(m,'w','SG')+history(m,'SG')+m.r('−')+sub(m,'w','GG')+history(m,'GG')
def lhs(m,i):return sub(m,'τ',i)+dot(m,sub(m,'x',i))+m.d(m.r('t'))+m.r('=')
def nonlinear(m,i):return sub(m,'δ',i)+m.d(sig(m,'z',i))
