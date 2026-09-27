"""Animate the project's verified trajectories and delayed synaptic drives.

No independent animation oscillator is used. At edge coordinate s, the drive
is weight*x_source(t-s*delay); edge motion therefore has the physical delay.
"""
from pathlib import Path
import json,hashlib,subprocess,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont

B=Path(__file__).resolve().parent;ROOT=B.parents[1]
W,H=1920,740;FPS=30;SLOW=40
BLUE='#174A80';RED='#FF484D';INK='#252529';GRAY='#737D85';ORANGE='#D68B22';CONTROL='#7461A5'
FONTS={}
def font(n,bold=False):
 key=(n,bold)
 if key not in FONTS:FONTS[key]=ImageFont.truetype('C:/Windows/Fonts/arial'+('bd' if bold else '')+'.ttf',n)
 return FONTS[key]
def txt(d,xy,s,n=30,color=INK,bold=False,anchor=None):d.text(xy,s,font=font(n,bold),fill=color,anchor=anchor)
def load(which):
 if which in ['healthy','parkinsonian']:
  a=np.genfromtxt(ROOT/f'Figures/STN_GPe/stn_{which}_stimulation.csv',delimiter=',',names=True)
  return dict(t=a['t_s'],x=np.c_[a['xS_spikes_per_s'],a['xG_spikes_per_s']],u=4600*a['current_mA'],history=np.array([0.,0.]) if which=='healthy' else np.array([1.,0.]))
 a=np.genfromtxt(B/(which+'.csv'),delimiter=',',names=True)
 return dict(t=a['t'],x=np.c_[a['xS'],a['xG']],u=a['u'],d=np.c_[a['dS'],a['dG']],z=np.c_[a['zS'],a['zG']],history=np.zeros(2))
DATA={n:load(n) for n in ['healthy','parkinsonian','simClosed','simOpen']}
S=np.linspace(0,1,121)
def bezier(points):
 p=np.array(points,float);s=S[:,None]
 q=(1-s)**3*p[0]+3*(1-s)**2*s*p[1]+3*(1-s)*s*s*p[2]+s**3*p[3]
 tangent=np.gradient(q,axis=0);normal=np.c_[-tangent[:,1],tangent[:,0]];normal/=np.linalg.norm(normal,axis=1)[:,None]
 return q,normal
PATHS=[bezier([(760,215),(760,52),(195,52),(160,215)]),
       bezier([(160,338),(160,454),(748,454),(748,345)]),
       bezier([(108,246),(22,203),(28,317),(103,302)])]
def delayed_drive(data,t,source,delay,weight):
 return weight*np.interp(t-S*delay,data['t'],data['x'][:,source],left=data['history'][source])
def edge(d,q,n,v,color):
 # Same bounded display scale across scenarios; s=0/1 stay attached to nodes.
 offset=18*np.tanh(v/100)*np.sin(np.pi*S)
 moved=q+n*offset[:,None]
 d.line([tuple(p) for p in moved],fill=color,width=4,joint='curve')
 # Activity packets at fixed spatial samples follow retarded simulation data.
 for j in range(7,len(S)-6,7):
  radius=2+5*np.tanh(abs(v[j])/180)
  x,y=moved[j];d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=color)
 return moved
def arrow(d,points,color=GRAY,width=3,head=11):
 d.line(points,fill=color,width=width,joint='curve');a=np.array(points[-2],float);b=np.array(points[-1],float)
 t=(b-a)/np.linalg.norm(b-a);n=np.array([-t[1],t[0]])
 d.polygon([tuple(b),tuple(b-head*t+head*.45*n),tuple(b-head*t-head*.45*n)],fill=color)
def dashed(d,points,color=GRAY,width=2,step=12):
 a=np.array(points)
 for i in range(0,len(a)-1,step):d.line([tuple(v) for v in a[i:min(i+step//2+1,len(a))]],fill=color,width=width)
def panel(d,box,end,ylim,title,yticks,show_time=False):
 x0,y0,x1,y1=box;lo,hi=ylim
 def xy(t,y):return np.c_[x0+np.asarray(t)/end*(x1-x0),y1-(np.asarray(y)-lo)/(hi-lo)*(y1-y0)]
 txt(d,(x0,y0-43),title,28)
 for y in yticks:
  yp=float(xy([0],[y])[0,1]);d.line((x0,yp,x1,yp),fill='#E7E9EB',width=1)
  txt(d,(x0-16,yp),f'{y:g}',24,GRAY,anchor='rm')
 d.line((x0,y0,x0,y1,x1,y1),fill=GRAY,width=2)
 if lo<0<hi:
  yy=float(xy([0],[0])[0,1]);d.line((x0,yy,x1,yy),fill='#BDC3C7',width=1)
 if show_time:
  for t in np.arange(0,end+.001,.1):
   xx=float(xy([t],[0])[0,0]);txt(d,(xx,y1+10),f'{t:.1f}',24,GRAY,anchor='mt')
  txt(d,(x1,y1+40),'Time (s)',24,GRAY,anchor='rt')
 return xy
def line(d,data,t,y,xy,color,width=3,dash=False):
 stop=np.searchsorted(data['t'],t,side='right');ts=data['t'][:stop];ys=np.asarray(y)[:stop]
 if len(ts)<2:return
 # Retain extrema within pixel columns: narrow stimulation pulses stay visible.
 coords=xy(ts,ys);pix=coords[:,0].astype(int);keep=[0]
 borders=np.r_[0,np.where(np.diff(pix))[0]+1,len(pix)]
 for a,b in zip(borders[:-1],borders[1:]):
  if b-a>2:keep.extend(sorted(set([a,b-1,a+int(np.argmin(ys[a:b])),a+int(np.argmax(ys[a:b]))])))
  else:keep.extend(range(a,b))
 pts=coords[sorted(set(keep))]
 if dash:dashed(d,pts,color,width)
 else:d.line([tuple(p) for p in pts],fill=color,width=width)
 if not dash:
  x,y=pts[-1];d.ellipse((x-5,y-5,x+5,y+5),fill=color)
def node(d,center,label,deviation,color,dotcolor):
 x,y=center;r=62;d.ellipse((x-r,y-r,x+r,y+r),fill=color)
 for a in np.arange(15,360,30)*np.pi/180:
  xx=x+47*np.cos(a);yy=y+47*np.sin(a);rr=6+2*np.tanh(abs(deviation)/20)
  d.ellipse((xx-rr,yy-rr,xx+rr,yy+rr),fill=dotcolor)
 txt(d,(x,y),label,38,anchor='mm')
def electrode(d,active=False):
 arrow(d,[(900,110),(823,110),(799,150),(780,225)],ORANGE if active else GRAY,3)
 d.line((790,183,780,219),fill='#B8B8B8',width=12)
 d.line((783,207,780,219),fill='#E3BF24',width=12)
def network(d,which,t):
 controlled=which=='controlled';key='simClosed' if controlled else which;data=DATA[key]
 current=np.array([np.interp(t,data['t'],data['x'][:,i]) for i in [0,1]])
 weights=[19.,-1.12,-6.6] if which=='healthy' else [20.,-10.7,-12.3]
 for k,(source,delay) in enumerate([(0,.006),(1,.006),(1,.004)]):
  q,n=PATHS[k];edge(d,q,n,delayed_drive(data,t,source,delay,weights[k]),BLUE if k==0 else RED)
 d.polygon([(160,215),(163,193),(179,200)],fill=BLUE)
 d.ellipse((736,333,760,357),fill=RED);d.line((103,286,103,316),fill=RED,width=4)
 node(d,(160,277),'Proto',current[1],'#FF6266','#D91018');node(d,(760,277),'STN',current[0],'#29CDEE','#386FF5')
 txt(d,(112,210),'+',39,BLUE);txt(d,(779,341),'−',38,RED);txt(d,(64,323),'−',34,RED)
 txt(d,(460,43),f'wSG = {weights[0]:.1f}',32,BLUE,anchor='mm')
 txt(d,(460,449),f'wGS = {abs(weights[1]):g}',32,RED,anchor='mm')
 txt(d,(43,365),'wGG',25,RED,anchor='mm');txt(d,(43,398),f'{abs(weights[2]):g}',27,RED,anchor='mm')
 label='Healthy network' if which=='healthy' else 'Parkinsonian network'
 txt(d,(457,247),label,32,anchor='mm')
 txt(d,(457,291),f'STN {current[0]:+.2f}   GPe {current[1]:+.2f}',26,GRAY,anchor='mm')
 txt(d,(457,326),'Deviation from equilibrium (spikes/s)',23,GRAY,anchor='mm')
 if controlled:
  # Controller receives the measured state/history and drives the STN input.
  arrow(d,[(160,342),(160,560),(320,560)],GRAY)
  arrow(d,[(760,370),(760,503),(554,503),(554,534)],GRAY)
  d.rounded_rectangle((320,527,570,597),radius=8,outline=CONTROL,width=3,fill='white')
  txt(d,(445,562),'Controller K',32,CONTROL,True,anchor='mm')
  arrow(d,[(570,567),(904,567),(904,110),(824,110),(799,150),(780,225)],CONTROL,3)
  uu=np.interp(t,data['t'],data['u']);txt(d,(880,607),f'u(t) = {uu:+.2f}',26,CONTROL,anchor='rt')
  pulse=.1<=t<=.14
  for xx,points,sig in [(160,[(69,277),(96,277)],'dG'),(760,[(854,277),(825,277)],'dS')]:
   arrow(d,points,ORANGE if pulse else '#C4C7CA',4 if pulse else 2)
   txt(d,(40 if xx==160 else 873,244),sig,23,ORANGE if pulse else GRAY,anchor='mm')
  if pulse:txt(d,(457,191),'External pulse',30,ORANGE,True,anchor='mm')
  else:txt(d,(457,191),'Feedback active',27,CONTROL,anchor='mm')
  txt(d,(445,647),'Paper controller: sector IQC, alpha = 0.492',25,GRAY,anchor='mm')
 elif which=='healthy':
  window=(data['t']>=max(0,t-1/FPS/SLOW))&(data['t']<=t)
  active=bool(np.max(data['u'][window],initial=0)>0);electrode(d,active)
  txt(d,(902,73),'u(t)',30,ORANGE if active else INK,anchor='rm')
  txt(d,(455,560),'100 Hz stimulation burst',28,GRAY,anchor='mm')
  txt(d,(455,601),'The response returns to equilibrium.',27,GRAY,anchor='mm')
 else:
  txt(d,(455,560),'No stimulation',28,GRAY,anchor='mm')
  txt(d,(455,601),'A small initial perturbation grows into oscillations.',25,GRAY,anchor='mm')
 txt(d,(35,716),'Line motion follows delayed synaptic drive (6 / 6 / 4 ms).',22,GRAY)
def render(which,t):
 im=Image.new('RGB',(W,H),'white');d=ImageDraw.Draw(im);network(d,which,t)
 controlled=which=='controlled';a=DATA['simClosed' if controlled else which];end=float(a['t'][-1])
 if controlled:
  xy=panel(d,(1055,66,1860,236),end,(-25,105),'Population deviations (spikes/s)',[-20,0,50,100])
  o=DATA['simOpen']
  for j,c in enumerate([BLUE,RED]):line(d,o,t,o['x'][:,j],xy,'#ADB3B9',2,True);line(d,a,t,a['x'][:,j],xy,c,4)
  txt(d,(1060,252),'Dashed: same pulse, controller off',24,GRAY)
  xy=panel(d,(1055,342,1860,493),end,(-4,1),'Controlled response (zoom)',[-4,-2,0])
  for j,c in enumerate([BLUE,RED]):line(d,a,t,a['x'][:,j],xy,c,4)
  xy=panel(d,(1055,583,1860,675),end,(-22,12),'Control and external pulse (spikes/s)',[-20,0,10],True)
  line(d,a,t,a['u'],xy,CONTROL,4)
  line(d,a,t,a['d'][:,0],xy,ORANGE,3);line(d,a,t,a['d'][:,1],xy,ORANGE,2,True)
 elif which=='healthy':
  xy=panel(d,(1055,70,1860,228),end,(0,1000),'External stimulation u(t) (spikes/s)',[0,500,1000])
  line(d,a,t,a['u'],xy,BLUE,2)
  xy=panel(d,(1055,354,1860,632),end,(-25,105),'Population deviations (spikes/s)',[-20,0,50,100],True)
  for j,c in enumerate([BLUE,RED]):line(d,a,t,a['x'][:,j],xy,c,4)
 else:
  xy=panel(d,(1055,90,1860,610),end,(-25,105),'Population deviations (spikes/s)',[-20,0,20,40,60,80,100],True)
  for j,c in enumerate([BLUE,RED]):line(d,a,t,a['x'][:,j],xy,c,4)
 # Consistent compact legend; simulation time is explicit, including slowdown.
 yy=19 if controlled else 275 if which=='healthy' else 15
 entries=[(1530,'STN',BLUE),(1680,'GPe',RED)] if controlled or which=='parkinsonian' else [(1330,'STN',BLUE),(1500,'GPe / Proto',RED)]
 for xx,name,c in entries:
  d.line((xx,yy+14,xx+38,yy+14),fill=c,width=4);txt(d,(xx+49,yy),name,24,c)
 txt(d,(445,689),f't = {t:.3f} s   |   40x slower',22,GRAY,anchor='mm')
 return im
def verify():
 a=DATA['simClosed'];o=DATA['simOpen'];meta=json.loads((B/'paper_data.json').read_text())
 assert np.max(np.abs(a['x'][a['t']<.1]))<1e-8
 assert np.max(np.abs(a['d'][a['t']>.14]))==0
 assert np.max(np.abs(a['x'][a['t']>=.4]))<1e-5
 assert np.max(np.ptp(o['x'][o['t']>=.35],axis=0))>40
 assert np.max(a['z'][:,0])<119.088146 and np.max(a['z'][:,1])<201.850931
 assert max(np.max(v) for v in meta['validation'].values())<1e-3
 for key,data in DATA.items():
  for source,tau,w in [(0,.006,20),(1,.006,-10.7),(1,.004,-12.3)]:
   q=delayed_drive(data,.2,source,tau,w)
   assert abs(q[0]-w*np.interp(.2,data['t'],data['x'][:,source]))<1e-10
   assert abs(q[-1]-w*np.interp(.2-tau,data['t'],data['x'][:,source]))<1e-10
 peak=float(np.max(np.abs(a['x'])));norm=np.max(np.abs(a['x']),axis=1)
 last=int(np.where(norm>.01*peak)[0][-1]);settled=float(a['t'][last+1])
 files=[ROOT/'Figures/STN_GPe/stn_healthy_stimulation.csv',ROOT/'Figures/STN_GPe/stn_parkinsonian_stimulation.csv',Path(meta['source']),Path(meta['controllerFile'])]
 result=dict(source_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
  controller_alpha=meta['alpha'],equilibrium=meta['equilibrium'],pulse_interval_s=[.1,.14],pulse_amplitude=[10,-10],
  controlled_peak_deviation=peak,controlled_final=a['x'][-1].tolist(),settles_below_one_percent_at_s=settled,
  uncontrolled_tail_peak_to_peak=np.ptp(o['x'][o['t']>=.35],axis=0).tolist(),peak_control=float(np.max(np.abs(a['u']))),
  spatial_refinement=meta['validation'],animation_mapping='edge(s,t)=w*x_source(t-s*tau); displacement=18*tanh(edge/100)*sin(pi*s)',
  delay_endpoint_checks='passed',seconds_of_simulation_per_second_of_video=1/SLOW)
 (B/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2),flush=True)
def encode(which):
 end=float(DATA['simClosed' if which=='controlled' else which]['t'][-1]);count=round(end*SLOW*FPS)
 for name,t in [('poster',.132 if which=='controlled' else .14 if which=='healthy' else .25),('start',0),('pulse',.12),('end',end)]:render(which,t).save(B/f'{which}-{name}.png')
 cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(B/f'{which}.mp4')]
 with subprocess.Popen(cmd,stdin=subprocess.PIPE) as p:
  for frame in range(count+2*FPS):
   t=min(end,frame/(FPS*SLOW));p.stdin.write(render(which,t).tobytes())
   if frame%150==0:print(f'{which}: frame {frame}/{count+2*FPS}',flush=True)
  p.stdin.close();assert p.wait()==0
 print('Rendered '+which,flush=True)
if __name__=='__main__':
 if '--previews' in sys.argv:
  verify()
  for which in ['healthy','parkinsonian','controlled']:
   for name,t in [('poster',.132 if which=='controlled' else .14 if which=='healthy' else .25),('end',.5 if which=='controlled' else .4)]:render(which,t).save(B/f'{which}-{name}.png')
 else:
  verify()
  for which in ['healthy','parkinsonian','controlled']:encode(which)
