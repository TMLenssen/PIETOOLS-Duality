"""Render clean 4K Zames--Falb media with the sector demonstration's geometry."""
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from simulate_zames_falb import OUT

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Presentation/Overlays'))
from render_clean_videos import ScaledDraw,encode

BOXES=[(100,85,650,330),(800,85,1350,330),(100,480,650,725),(800,480,1350,725)]
COLORS=['#174A80','#E6373E']

def render(data,i,rate=False):
    im=Image.new('RGB',(3840,2160),'white');d=ScaledDraw(im,3840/1440)
    def axes(box,xlim,ylim,xticks,yticks):
        l,a,r,b=box
        def p(x,y):return (l+(x-xlim[0])/(xlim[1]-xlim[0])*(r-l),b-(y-ylim[0])/(ylim[1]-ylim[0])*(b-a))
        d.line([(l,a),(l,b),(r,b)],fill='#333333',width=1)
        for v in xticks:
            x=p(v,ylim[0])[0];d.line([(x,b),(x,b+6)],fill='#333333',width=1)
        for v in yticks:
            y=p(xlim[0],v)[1];d.line([(l-6,y),(l,y)],fill='#333333',width=1)
        return p
    for k,lim in enumerate([1150,700]):
        p=axes(BOXES[k],[-lim,lim],[-lim,lim],[-lim,0,lim],[-lim,0,lim])
        d.line([p(-lim,0),p(lim,0)],fill='#AAAAAA',width=1)
        d.line([p(0,-lim),p(0,lim)],fill='#DDDDDD',width=1)
        z=np.linspace(-lim,lim,501);M=[300,400][k];star=data['zStar'][k]
        w=M/2*(np.tanh(2*(star+z)/M)-np.tanh(2*star/M))
        d.line([p(a,b) for a,b in zip(z,w)],fill=COLORS[k],width=2.5)
        x,y=p(data['z'][i,k],data['w'][i,k]);d.ellipse((x-5,y-5,x+5,y+5),fill=COLORS[k])
    ids=list(range(0,i+1,20))
    if ids[-1]!=i:ids.append(i)
    p=axes(BOXES[2],[0,.4],[-20,100],np.arange(9)*.05,range(-20,101,20))
    y=p(0,0)[1]
    for x in range(100,650,6):d.line([(x,y),(x+2,y)],fill='#888888',width=1)
    for k in range(2):
        pts=[p(data['t'][j],data['x'][j,k]) for j in ids]
        if len(pts)>1:d.line(pts,fill=COLORS[k],width=2)
        d.line([(110,495+k*24),(135,495+k*24)],fill=COLORS[k],width=2)
    limits=[-10000,100000] if rate else [0,6000]
    ticks=[0,50000,100000] if rate else [0,2000,4000,6000]
    p=axes(BOXES[3],[0,.4],limits,[0,.1,.2,.3,.4],ticks)
    if rate:d.line([p(0,0),p(.4,0)],fill='#AAAAAA',width=1)
    values=data['q'] if rate else data['integral']
    for k in range(2):
        pts=[p(data['t'][j],values[j,k]) for j in ids]
        if len(pts)>1:d.line(pts,fill=COLORS[k],width=2.5)
        x,y=pts[-1];d.ellipse((x-4,y-4,x+4,y+4),fill=COLORS[k])
        d.line([(810,495+k*24),(835,495+k*24)],fill=COLORS[k],width=2)
    return im

def main():
    with np.load(OUT/'stn_gpe_zames_falb_data.npz') as d:data={k:d[k] for k in d.files}
    for rate,suffix in [(False,'integral'),(True,'rate')]:
        render(data,len(data['t'])-1,rate).save(OUT/f'Zames-Falb {suffix}.png')
        frames=(render(data,round(min(i,288)*(len(data['t'])-1)/288),rate) for i in range(337))
        encode(OUT/f'Zames-Falb {suffix}.mp4',frames,'3840x2160',24)

if __name__=='__main__':main()
