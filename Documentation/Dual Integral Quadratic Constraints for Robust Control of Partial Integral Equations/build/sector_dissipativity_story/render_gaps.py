from pathlib import Path
import numpy as np,subprocess,json
from PIL import Image,ImageDraw
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
data=np.load(ROOT/'Presentation/SectorIQC/Simulation/STN_GPe/stn_gpe_sector_data.npz')
beta=float(data['beta'][0]);star=float(data['zStar'][0]);M=300.
def delta(z):return M/2*(np.tanh(2*(star+z)/M)-np.tanh(2*star/M))
S=4;W,H=300*S,220*S
def p(z,w):return ((150+.27*z)*S,(110-.20*w)*S)
curve=[p(z,float(delta(z))) for z in np.linspace(-500,500,601)]
def arrow(d,aa,bb,col):
 d.line([aa,bb],fill=col,width=3*S)
 sign=1 if bb[1]>aa[1] else -1
 if abs(bb[1]-aa[1])>7*S:d.polygon([bb,(bb[0]-3*S,bb[1]-sign*6*S),(bb[0]+3*S,bb[1]-sign*6*S)],fill=col)
def frame(t):
 im=Image.new('RGB',(W,H),'white');d=ImageDraw.Draw(im)
 for sign in [-1,1]:d.polygon([p(0,0),p(sign*500,0),p(sign*500,sign*500*beta)],fill='#EDF2F5')
 d.line([p(-525,0),p(540,0)],fill='#A9ADB2',width=3)
 d.line([p(0,-415),p(0,420)],fill='#A9ADB2',width=3)
 d.line([p(-500,-500*beta),p(500,500*beta)],fill='#747B82',width=4)
 d.line([p(-500,0),p(500,0)],fill='#747B82',width=4)
 d.line(curve,fill='#D61016',width=7)
 z=250*np.sin(2*np.pi*t/12);w=float(delta(z));xx,yy=p(z,w)
 xoff=3*S
 arrow(d,(xx-xoff,yy),(xx-xoff,p(z,beta*z)[1]),'#216F9C')
 arrow(d,(xx+xoff,p(z,0)[1]),(xx+xoff,yy),'#147C60')
 d.ellipse((xx-3*S,yy-3*S,xx+3*S,yy+3*S),fill='#D61016')
 return im
fps=24;duration=12
cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(fps),'-i','-','-an','-c:v','libx264','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(B/'signed_gaps.mp4')]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
for k in range(duration*fps):
 im=frame(k/fps)
 if k==0:im.save(B/'signed_gaps.png')
 proc.stdin.write(im.tobytes())
proc.stdin.close();assert proc.wait()==0
zz=np.linspace(-250,250,2001);ww=delta(zz);a=beta*zz-ww;bb=ww
assert np.all(a[zz>0]>0) and np.all(bb[zz>0]>0)
assert np.all(a[zz<0]<0) and np.all(bb[zz<0]<0)
# Both population channels use the same correct supply identity.
for nu in [.2,1.,3.]:
 z=data['z'];w=data['w'];aa=data['beta']*z-w;bbb=w
 zt=nu*aa+bbb;wt=nu*aa-bbb;sig=zt**2-wt**2
 assert np.min(sig)>-1e-8
 assert np.max(np.abs(sig-4*nu*aa*bbb))<1e-7
report=dict(beta=beta,zStar=star,duration=duration,frames=duration*fps,gap_signs_verified=True,weighted_supply_identity_verified=True,original_integral_final=data['integral'][-1].tolist(),unit_scaling_supply_integral_final=(4*data['integral'][-1]).tolist())
(B/'simulation_validation.json').write_text(json.dumps(report,indent=2));print(report)
