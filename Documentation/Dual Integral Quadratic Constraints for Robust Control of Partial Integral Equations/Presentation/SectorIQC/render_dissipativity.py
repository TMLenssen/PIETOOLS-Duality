"""Plots only, matching the presentation's STN/GPe response plot."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
INK='#333333'; GRAY='#666666'; BLUE='#174A80'; RED='#E6373E'; GREEN='#147C60'
BOXES=[(100,85,650,330),(800,85,1350,330),(100,480,650,725),(800,480,1350,725)]

def render(data,i):
    from simulate_stn_gpe import M,ZSTAR,BETA
    t,x,z,w,q,integral=data
    im=Image.new('RGB',(1440,810),'white');d=ImageDraw.Draw(im)
    def text(px,py,value,size=20,color=INK,anchor=None,math=False,bold=False):
        name='cambria.ttc' if math else ('arialbd.ttf' if bold else 'arial.ttf')
        d.text((px,py),value,font=ImageFont.truetype('C:/Windows/Fonts/'+name,size),fill=color,anchor=anchor)
    def axes(box,xlim,ylim,xticks,yticks,title,xlabel,ylabel):
        l,top,r,b=box
        def p(a,v):return l+(a-xlim[0])/(xlim[1]-xlim[0])*(r-l),b-(v-ylim[0])/(ylim[1]-ylim[0])*(b-top)
        text((l+r)/2,top-45,title,25,anchor='ma',bold=True)
        d.line((l,top,l,b,r,b),fill=INK,width=1)
        for val in xticks:
            px,_=p(val,ylim[0]);d.line((px,b,px,b+6),fill=INK,width=1)
            text(px,b+11,f'{val:g}',18,anchor='ma')
        for val in yticks:
            _,py=p(xlim[0],val);d.line((l-6,py,l,py),fill=INK,width=1)
            text(l-13,py-10,f'{val:g}',18,anchor='ra')
        text((l+r)/2,b+42,xlabel,23,anchor='ma',math=True)
        font=ImageFont.truetype('C:/Windows/Fonts/cambria.ttc',22)
        bb=font.getbbox(ylabel);layer=Image.new('RGBA',(bb[2]-bb[0]+8,bb[3]-bb[1]+8))
        ImageDraw.Draw(layer).text((4-bb[0],4-bb[1]),ylabel,font=font,fill=INK)
        layer=layer.rotate(90,expand=True);im.paste(layer,(l-78,round((top+b-layer.height)/2)),layer)
        return p
    for k,(color,limit,title) in enumerate([(BLUE,1150,'STN nonlinearity'),(RED,700,'GPe nonlinearity')]):
        p=axes(BOXES[k],(-limit,limit),(-limit,limit),[-limit,0,limit],[-limit,0,limit],title,'zᵢ(t)','wᵢ(t)')
        for sign in [-1,1]:d.polygon([p(0,0),p(sign*limit,0),p(sign*limit,sign*limit*BETA[k])],fill='#F0F3F5')
        d.line([p(-limit,0),p(limit,0)],fill='#A0A0A0',width=1)
        d.line([p(0,-limit),p(0,limit)],fill='#D0D0D0',width=1)
        d.line([p(-limit,-limit*BETA[k]),p(limit,limit*BETA[k])],fill='#777777',width=1)
        zz=np.linspace(-limit,limit,500);ww=M[k]/2*(np.tanh(2*(ZSTAR[k]+zz)/M[k])-np.tanh(2*ZSTAR[k]/M[k]))
        d.line([p(a,v) for a,v in zip(zz,ww)],fill=color,width=3)
        a,v=z[i,k],w[i,k]
        d.line([p(a,BETA[k]*a),p(a,v)],fill='#777777',width=3)
        d.line([p(a,v),p(a,0)],fill=GREEN,width=3)
        px,py=p(a,v);d.ellipse((px-5,py-5,px+5,py+5),fill=color)
    p=axes(BOXES[2],(0,.4),(-20,100),[0,.1,.2,.3,.4],[-20,0,40,80,100],'Response','t (s)','spikes/s')
    zero=p(0,0)[1]
    for px in range(100,650,6):d.line((px,zero,px+2,zero),fill=GRAY,width=1)
    ids=list(range(0,i+1,20))
    if ids[-1]!=i:ids.append(i)
    for k,color in enumerate([BLUE,RED]):
        pts=[p(t[j],x[j,k]) for j in ids]
        if len(pts)>1:d.line(pts,fill=color,width=2)
        yy=493+k*26;d.line((117,yy+10,151,yy+10),fill=color,width=2)
        text(160,yy,['xₛ (STN)','xɢ (GPe)'][k],18,math=True)
    total=integral.sum(axis=1)
    p=axes(BOXES[3],(0,.4),(0,3200),[0,.1,.2,.3,.4],[0,1000,2000,3000],'Supply function','T (s)','∫₀ᵀ σ(t) dt')
    for k,color in enumerate([BLUE,RED]):
        pts=[p(t[j],integral[j,k]) for j in ids]
        if len(pts)>1:d.line(pts,fill=color,width=3)
        px,py=p(t[i],integral[i,k]);d.ellipse((px-4,py-4,px+4,py+4),fill=color)
        yy=495+k*24;d.line((810,yy,835,yy),fill=color,width=2)
        text(850,yy-10,['STN','GPe'][k],20)
    return im
