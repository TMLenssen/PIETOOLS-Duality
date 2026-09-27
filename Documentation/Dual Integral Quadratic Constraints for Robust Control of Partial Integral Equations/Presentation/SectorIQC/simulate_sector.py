"""Simulate a spatial memoryless sector operator; export data and a slide video.
Requires numpy and Pillow; uses ffmpeg for the optional MP4.
"""
from pathlib import Path
import json,math,subprocess,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont

HERE=Path(__file__).resolve().parent
OUT=HERE/'Simulation';OUT.mkdir(exist_ok=True)
ALPHA=.2;BETA=1.2
SPACE=np.linspace(0,1,161);TIME=np.linspace(0,12,1441)
T=TIME[:,None];S=SPACE[None,:]
Z=(1-np.exp(-2*T))*(1.6*np.sin(2*np.pi*T/4)*np.cos(np.pi*S)+.4*np.sin(2*np.pi*T/1.7)*np.sin(2*np.pi*S))
W=.7*Z+.3*np.tanh(Z)
Q=(BETA*Z-W)*(W-ALPHA*Z)
SIGMA=np.trapezoid(Q,SPACE,axis=1)
IQC=np.r_[0,np.cumsum((SIGMA[1:]+SIGMA[:-1])*.5*np.diff(TIME))]
Q_MATRIX=-ALPHA*BETA*Z**2+(ALPHA+BETA)*Z*W-W**2
assert np.min(Q)>=-1e-12
assert np.max(np.abs(Q-Q_MATRIX))<1e-12
assert np.min(np.diff(IQC))>=-1e-12
# A deliberately out-of-sector operator must fail this check.
WBAD=1.4*Z
assert np.min((BETA*Z-WBAD)*(WBAD-ALPHA*Z))<-.1
fine_final=float(IQC[-1]);coarse=np.trapezoid(SIGMA[::2],TIME[::2])
assert abs(coarse-fine_final)<1e-4
summary=dict(alpha=ALPHA,beta=BETA,duration=12,spatial_points=len(SPACE),time_points=len(TIME),
    minimum_pointwise_supply=float(Q.min()),final_integral=fine_final,
    minimum_integral_increment=float(np.diff(IQC).min()),quadratic_form_max_error=float(np.max(np.abs(Q-Q_MATRIX))),
    time_grid_refinement_difference=float(abs(coarse-fine_final)),
    interpretation='Simulation illustrates the hard IQC for this memoryless operator; sector membership holds analytically for all scalar inputs. No plant or PDE dynamics are simulated.')
(OUT/'results.json').write_text(json.dumps(summary,indent=2))
np.savez_compressed(OUT/'sector_data.npz',t=TIME,s=SPACE,z=Z,w=W,q=Q,sigma=SIGMA,integral=IQC)
np.savetxt(OUT/'supply_history.csv',np.c_[TIME,SIGMA,IQC],delimiter=',',header='t,sigma,integral',comments='')

WID,HEI=1440,810
INK='#252529';GRAY='#747B82';RED='#D61016';BLUE='#216F9C';GREEN='#147C60';LIGHT='#EDF2F5'
FONT=Path('C:/Windows/Fonts')
def font(size,bold=False):return ImageFont.truetype(str(FONT/('arialbd.ttf' if bold else 'arial.ttf')),size)
def mathfont(size):return ImageFont.truetype(str(FONT/'cambria.ttc'),size)

def render(index):
    im=Image.new('RGB',(WID,HEI),'white');d=ImageDraw.Draw(im)
    def text(x,y,t,size=22,c=INK,bold=False,anchor=None,math=False):d.text((x,y),t,font=mathfont(size) if math else font(size,bold),fill=c,anchor=anchor)
    text(52,32,'Sector bounds → dissipativity',34,bold=True)
    text(52,83,'wΔ(t,s) = 0.7 zΔ(t,s) + 0.3 tanh(zΔ(t,s))     ·     [α, β] = [0.2, 1.2]',24,math=True)
    text(1358,37,f't = {TIME[index]:.2f} s',23,GRAY,anchor='ra')
    # Sector plot. The selected spatial point is red; other points are grey.
    box=(78,161,633,555)
    def phase(z,w):return 355+z*123,358-w*82
    for sg in (-1,1):d.polygon([phase(0,0),phase(sg*2.1,sg*2.1*ALPHA),phase(sg*2.1,sg*2.1*BETA)],fill=LIGHT)
    d.line([phase(-2.2,0),phase(2.2,0)],fill='#B9BDC1',width=1)
    d.line([phase(0,-2.5),phase(0,2.5)],fill='#B9BDC1',width=1)
    for slope in (ALPHA,BETA):d.line([phase(-2.1,-2.1*slope),phase(2.1,2.1*slope)],fill=GRAY,width=2)
    zz=np.linspace(-2.1,2.1,180);ww=.7*zz+.3*np.tanh(zz)
    d.line([phase(a,b) for a,b in zip(zz,ww)],fill=RED,width=3)
    for z,w in zip(Z[index,::4],W[index,::4]):
        x,y=phase(z,w);d.ellipse((x-2,y-2,x+2,y+2),fill='#A2A8AE')
    j=40;z=Z[index,j];w=W[index,j];x,y=phase(z,w)
    d.line([phase(z,BETA*z),phase(z,w)],fill=BLUE,width=5)
    d.line([phase(z,w),phase(z,ALPHA*z)],fill=GREEN,width=5)
    d.ellipse((x-6,y-6,x+6,y+6),fill=RED)
    text(355,132,'wΔ(t,s)',21,anchor='ma',math=True)
    text(592,373,'zΔ(t,s)',21,math=True)
    text(610,140,'βzΔ',20,GRAY,math=True)
    text(612,317,'αzΔ',20,GRAY,math=True)
    text(73,580,'Red point: s = 0.25   ·   Grey points: other locations',18,GRAY)
    text(73,616,f'q(t,0.25) = {Q[index,j]:.3f} ≥ 0',24,GREEN,math=True)
    # Time histories at the selected location and cumulative spatial supply.
    def axes(box,ylo,yhi,title):
        left,top,right,bottom=box
        text(left,top-35,title,21,bold=True)
        def p(t,v):return left+(right-left)*t/12,bottom-(bottom-top)*(v-ylo)/(yhi-ylo)
        for tick in (0,4,8,12):
            xx,_=p(tick,ylo);d.line((xx,top,xx,bottom),fill='#EEF0F2',width=1);text(xx,bottom+6,str(tick),16,GRAY,anchor='ma')
        d.line((left,bottom,right,bottom),fill='#B9BDC1',width=1)
        if ylo<0:d.line([p(0,0),p(12,0)],fill='#D1D5D8',width=1)
        xx,_=p(TIME[index],0);d.line((xx,top,xx,bottom),fill='#CDD1D5',width=1)
        return p
    p=axes((763,185,1355,350),-2,2,'Input and output at s = 0.25')
    for values,color in [(Z[:,j],BLUE),(W[:,j],RED)]:
        pts=[p(t,v) for t,v in zip(TIME[:index+1:2],values[:index+1:2])]
        if len(pts)>1:d.line(pts,fill=color,width=3)
    text(1030,151,'zΔ(t,0.25)',18,BLUE,math=True);text(1200,151,'wΔ(t,0.25)',18,RED,math=True)
    p=axes((763,452,1355,625),0,math.ceil(IQC[-1]*1.15),'Accumulated supply over s ∈ [0,1]')
    pts=[p(t,v) for t,v in zip(TIME[:index+1:2],IQC[:index+1:2])]
    if len(pts)>1:d.line(pts,fill=GREEN,width=3)
    text(774,463,f'IQC integral = {IQC[index]:.3f}',21,GREEN)
    text(774,496,f'Instantaneous spatial supply = {SIGMA[index]:.3f}',18,GRAY)
    text(1348,651,'time t [s]',17,GRAY,anchor='ra')
    d.line((52,688,1385,688),fill='#E2E5E8',width=1)
    text(720,708,'q(t,s) = (βzΔ(t,s) − wΔ(t,s))(wΔ(t,s) − αzΔ(t,s)) ≥ 0',25,GREEN,anchor='ma',math=True)
    text(720,752,'Every finite-horizon integral is nonnegative.  ΨΔ = I; zero storage.',21,INK,anchor='ma')
    return im

def main():
    render(430).save(OUT/'sector_simulation.png')
    ffmpeg=shutil.which('ffmpeg')
    if ffmpeg:
        path=OUT/'Sector IQC - Simulation.mp4'
        command=[ffmpeg,'-y','-loglevel','error','-f','rawvideo','-vcodec','rawvideo','-pix_fmt','rgb24','-s',f'{WID}x{HEI}','-r','24','-i','-','-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(path)]
        with subprocess.Popen(command,stdin=subprocess.PIPE) as proc:
            for k in range(289):proc.stdin.write(render(round(k*1440/288)).tobytes())
            # Hold the completed trajectory for two seconds for presentation use.
            last=render(1440).tobytes()
            for _ in range(48):proc.stdin.write(last)
            proc.stdin.close();assert proc.wait()==0
        print('Saved',path)
    print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
