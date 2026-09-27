from pathlib import Path
import math, subprocess, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

B=Path(__file__).resolve().parent
ROOT=B.parents[1]
data=np.load(ROOT/'Presentation/SectorIQC/Simulation/STN_GPe/stn_gpe_sector_data.npz')
# Match the sector bound now displayed in the user's edited slide.
beta=0.735; star=float(data['zStar'][0])
S=3; X=35; Y=64; W=660*S; H=320*S; FPS=60; N=720
BLUE='#216F9C'; GREEN='#147C60'; RED='#D61016'
font=ImageFont.truetype('C:/Windows/Fonts/cambria.ttc',26*S)
small=ImageFont.truetype('C:/Windows/Fonts/cambria.ttc',17*S)
product_font=ImageFont.truetype('C:/Windows/Fonts/cambria.ttc',23*S)
PRODUCT_RED='#C81919'
def delta(z): return 150*(math.tanh(2*(star+z)/300)-math.tanh(2*star/300))
def p(z,w): return ((360+.558*z-X)*S,(190.5-.2*225/220*w-Y)*S)
base=Image.new('RGB',(W,H),'white'); d=ImageDraw.Draw(base)
for sign in [-1,1]:
    d.polygon([p(0,0),p(sign*500,0),p(sign*500,sign*500*beta)],fill='#EDF2F5')
def line(points,c,width): d.line(points,fill=c,width=round(width*S))
line([p(-525,0),p(540,0)],'#A9ADB2',.7)
line([p(0,-415),p(0,420)],'#A9ADB2',.7)
line([p(-500,-500*beta),p(500,500*beta)],'#747B82',1.0)
line([p(-500,0),p(500,0)],'#747B82',1.0)
line([p(z,delta(z)) for z in np.linspace(-500,500,1001)],RED,1.8)
def arrow(draw,a,b,c):
    draw.line([a,b],fill=c,width=3*S)
    dy=b[1]-a[1]
    if abs(dy)>6*S:
        sign=1 if dy>0 else -1
        draw.polygon([b,(b[0]-3*S,b[1]-sign*6*S),(b[0]+3*S,b[1]-sign*6*S)],fill=c)
def fmt(v): return f'{0.0 if abs(v)<.005 else v:+.2f}'.replace('-','−')
def frame(k):
    # Ease the start and finish while preserving one complete sweep.
    u=k/(N-1); phase=2*math.pi*(3*u*u-2*u*u*u)+math.pi/6
    z=250*math.sin(phase); w=delta(z); a=beta*z-w; b=w
    assert a*b>=-1e-8
    im=base.copy(); draw=ImageDraw.Draw(im); xx,yy=p(z,w)
    arrow(draw,(xx-3*S,yy),(xx-3*S,p(z,beta*z)[1]),BLUE)
    arrow(draw,(xx+3*S,p(z,0)[1]),(xx+3*S,yy),GREEN)
    draw.ellipse((xx-3*S,yy-3*S,xx+3*S,yy+3*S),fill=RED)
    for cx,cy,txt,ft,col in [(118,89,'z = '+fmt(z),small,'#252529'),(204,365,fmt(a),font,BLUE),(522,365,fmt(b),font,GREEN),(360,294,'ab = '+fmt(a*b)+' ≥ 0',product_font,PRODUCT_RED)]:
        draw.text(((cx-X)*S,(cy-Y)*S),txt,font=ft,fill=col,anchor='mm')
    return im
proc=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','fast','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(B/'gaps-60fps.mp4')],stdin=subprocess.PIPE)
for k in range(N):
    im=frame(k)
    if k in [0,180,360,540]: im.save(B/f'frame-{k}.png')
    proc.stdin.write(im.tobytes())
proc.stdin.close(); assert proc.wait()==0
print(f'Rendered {N} synchronized frames at {FPS} fps; poster starts at z=125.')
