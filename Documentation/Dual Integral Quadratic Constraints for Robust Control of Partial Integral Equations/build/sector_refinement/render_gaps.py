from pathlib import Path
import numpy as np,subprocess,json
from PIL import Image,ImageDraw
B=Path(__file__).resolve().parent;ROOT=B.parents[1]
data=np.load(ROOT/'Presentation/SectorIQC/Simulation/STN_GPe/stn_gpe_sector_data.npz');beta=float(data['beta'][0]);star=float(data['zStar'][0])
read=json.loads((B/'readouts.json').read_text());S=4;W,H=620*S,225*S
def delta(z):return 150*(np.tanh(2*(star+z)/300)-np.tanh(2*star/300))
def p(z,w):return ((310+.558*z)*S,(112.5-.2*225/220*w)*S)
curve=[p(z,float(delta(z))) for z in np.linspace(-500,500,601)]
def arrow(d,a,b,c):
 d.line([a,b],fill=c,width=3*S)
 sign=1 if b[1]>a[1] else -1
 if abs(b[1]-a[1])>6*S:d.polygon([b,(b[0]-3*S,b[1]-sign*6*S),(b[0]+3*S,b[1]-sign*6*S)],fill=c)
def frame(v):
 im=Image.new('RGB',(W,H),'white');d=ImageDraw.Draw(im)
 for sign in [-1,1]:d.polygon([p(0,0),p(sign*500,0),p(sign*500,sign*500*beta)],fill='#EDF2F5')
 d.line([p(-525,0),p(540,0)],fill='#A9ADB2',width=2)
 d.line([p(0,-415),p(0,420)],fill='#A9ADB2',width=2)
 d.line([p(-500,-500*beta),p(500,500*beta)],fill='#747B82',width=3)
 d.line([p(-500,0),p(500,0)],fill='#747B82',width=3)
 d.line(curve,fill='#D61016',width=6)
 z,w=v['z'],v['w'];xx,yy=p(z,w)
 arrow(d,(xx-3*S,yy),(xx-3*S,p(z,beta*z)[1]),'#216F9C')
 arrow(d,(xx+3*S,p(z,0)[1]),(xx+3*S,yy),'#147C60')
 d.ellipse((xx-3*S,yy-3*S,xx+3*S,yy+3*S),fill='#D61016')
 return im
cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(read['fps']),'-i','-','-an','-c:v','libx264','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(B/'signed_gaps.mp4')]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
for k,v in enumerate(read['values']):
 assert abs(v['a']-(beta*v['z']-v['w']))<1e-9 and abs(v['b']-v['w'])<1e-9
 im=frame(v)
 if k==0:im.save(B/'signed_gaps.png')
 proc.stdin.write(im.tobytes())
proc.stdin.close();assert proc.wait()==0
print('Rendered exact readout samples; graph and numbers use identical values.')
