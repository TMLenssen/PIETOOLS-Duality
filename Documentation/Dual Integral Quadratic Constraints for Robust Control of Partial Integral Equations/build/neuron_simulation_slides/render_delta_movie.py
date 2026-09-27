"""One randomly sampled heat-equation trajectory at a time.
Exact Dirichlet eigenfunction solution, with a modal-convergence check.
"""
from pathlib import Path
import numpy as np,json,subprocess
from PIL import Image,ImageDraw,ImageFont
B=Path(__file__).resolve().parent;W,H=1920,540;FPS=30
BLUE='#174A80';RED='#C81919';GRAY='#737D85';INK='#252529';F={}
def font(n,b=False):
 if (n,b) not in F:F[n,b]=ImageFont.truetype('C:/Windows/Fonts/arial'+('bd' if b else '')+'.ttf',n)
 return F[n,b]
def text(d,p,s,n=31,c=INK,b=False,anchor=None):d.text(p,s,font=font(n,b),fill=c,anchor=anchor)
SEED=20260926;DELTA=np.random.default_rng(SEED).uniform(-.5,.5,6);T=np.linspace(0,30,1501)
CRITICAL=(.2+.01*np.pi**2)/.25-1
def solution(delta,modes):
 n=np.arange(1,2*modes,2);lam=.25*(1+delta)-.2-.01*(np.pi*n)**2
 heat=np.minimum(T,8)[:,None]
 f=np.expm1(heat*lam)/lam*np.exp(np.maximum(T-8,0)[:,None]*lam)
 return f@(16/(np.pi*n)**2)
Y=np.array([solution(v,200) for v in DELTA]);LAMBDA=.25*(1+DELTA)-.2-.01*np.pi**2
error=float(max(np.max(abs(Y[i]-solution(v,400))) for i,v in enumerate(DELTA)))
assert error<1e-6
assert np.all(Y>=0) and np.all(Y[:,0]==0)
for i,lam in enumerate(LAMBDA):
 if lam>0:assert np.all(np.diff(Y[i,T>8])>0)
 else:assert np.all(np.diff(Y[i,T>8])<0)
def render(i,t):
 dlt=DELTA[i];unstable=LAMBDA[i]>0;red=unstable and t>8;color=RED if red else BLUE
 im=Image.new('RGB',(W,H),'white');d=ImageDraw.Draw(im)
 x0,y0,x1,y1=140,58,1230,448
 def xy(t,y):return np.c_[x0+np.asarray(t)/30*(x1-x0),y1-np.asarray(y)/100*(y1-y0)]
 text(d,(x0,6),'Average temperature deviation',32)
 for y in [0,20,40,60,80,100]:
  yy=float(xy([0],[y])[0,1]);d.line((x0,yy,x1,yy),fill='#E5E8EB',width=1);text(d,(x0-22,yy),str(y),28,GRAY,anchor='rm')
 d.line((x0,y0,x0,y1,x1,y1),fill=GRAY,width=2)
 for tt in range(0,31,5):text(d,(x0+tt/30*(x1-x0),y1+12),str(tt),28,GRAY,anchor='mt')
 text(d,(x1,y1+46),'Time (s)',29,GRAY,anchor='rt')
 xp=float(xy([8],[0])[0,0])
 for yy in range(y0,y1,15):d.line((xp,yy,xp,min(yy+7,y1)),fill='#B5BCC3',width=2)
 text(d,(xp+10,y0+10),'Heater off',27,GRAY)
 ids=T<=t;points=xy(T[ids],Y[i,ids])
 if len(points)>1:d.line([tuple(p) for p in points],fill=color,width=5)
 x,y=points[-1];d.ellipse((x-7,y-7,x+7,y+7),fill=color)
 text(d,(1370,42),f'Random sample {i+1} / {len(DELTA)}',31,GRAY)
 text(d,(1370,97),f'δ = {dlt:+.3f}',52,color,True)
 # Sampling interval and actual stability boundary, independent of curve color.
 xx0,xx1=1370,1840;yy=217;d.line((xx0,yy,xx1,yy),fill='#A6ADB4',width=3)
 xc=xx0+(CRITICAL+.5)*(xx1-xx0);d.line((xc,yy-16,xc,yy+16),fill=GRAY,width=2)
 xv=xx0+(dlt+.5)*(xx1-xx0);d.ellipse((xv-9,yy-9,xv+9,yy+9),fill=color)
 text(d,(xx0,yy+24),'−0.5',28,GRAY,anchor='mt');text(d,(xx1,yy+24),'+0.5',28,GRAY,anchor='mt')
 text(d,(1370,291),f'Critical δ = {CRITICAL:.3f}',29,GRAY)
 if t<=8:status='Heater on';detail='u(t) = 2'
 elif unstable:status='Diverging';detail='Positive dominant growth rate'
 else:status='Decaying';detail='Negative dominant growth rate'
 text(d,(1370,355),status,39,color,True);text(d,(1370,407),detail,27,GRAY)
 text(d,(1370,459),f't = {t:04.1f} s',30,GRAY)
 return im
meta=dict(seed=SEED,samples=DELTA.tolist(),dominant_growth_rates=LAMBDA.tolist(),critical_delta=CRITICAL,
 modal_refinement_error=error,heater_amplitude=2,heater_off=8,simulation_end=30,
 description='Uniform random samples fixed for reproducible video playback. One curve is shown at a time. Red after heater switch-off iff the exact PDE dominant eigenvalue is positive. u=2 on [0,8), zero thereafter. 200 odd Fourier modes; checked against 400.')
(B/'delta_verification.json').write_text(json.dumps(meta,indent=2))
np.savez_compressed(B/'delta_trajectories.npz',t=T,delta=DELTA,y=Y,lambda1=LAMBDA)
render(0,0).save(B/'delta-start.png');render(0,30).save(B/'delta-diverging.png');render(5,30).save(B/'delta-decaying.png')
cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(B/'delta.mp4')]
print(json.dumps(meta,indent=2),flush=True)
with subprocess.Popen(cmd,stdin=subprocess.PIPE) as p:
 for i in range(len(DELTA)):
  for k in range(6*FPS):p.stdin.write(render(i,min(30,k/FPS*6)).tobytes())
  print(f'Rendered delta sample {i+1}',flush=True)
 p.stdin.close();assert p.wait()==0
