from pathlib import Path
import sys,importlib.util,json,subprocess
import numpy as np
from PIL import Image,ImageDraw
B=Path(__file__).resolve().parent;ROOT=B.parents[1];OLD=B.parent/'neuron_simulation_slides'
def module(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
n=module('neural',OLD/'render_neural_movies.py')
labels=[];capture=False
def txt(d,xy,s,n=30,color='#252529',bold=False,anchor=None):
 if capture:
  box=d.textbbox(xy,s,font=globals()['n'].font(n,bold),anchor=anchor)
  labels.append(dict(text=s,box=list(box),size=n,color=color,bold=bold))
n.txt=txt
def network(d,which,t):
 controlled=which=='controlled';a=n.DATA['simClosed' if controlled else which]
 current=np.array([np.interp(t,a['t'],a['x'][:,i]) for i in [0,1]])
 weights=[19,-1.12,-6.6] if which=='healthy' else [20,-10.7,-12.3]
 for k,(source,delay) in enumerate([(0,.006),(1,.006),(1,.004)]):
  q,normal=n.PATHS[k];n.edge(d,q,normal,n.delayed_drive(a,t,source,delay,weights[k]),n.BLUE if k==0 else n.RED)
 d.polygon([(160,215),(163,193),(179,200)],fill=n.BLUE)
 d.ellipse((736,333,760,357),fill=n.RED);d.line((103,286,103,316),fill=n.RED,width=4)
 n.node(d,(160,277),'Proto',current[1],'#FF6266','#D91018');n.node(d,(760,277),'STN',current[0],'#29CDEE','#386FF5')
 txt(d,(112,210),'+',39,n.BLUE);txt(d,(779,341),'−',38,n.RED);txt(d,(64,323),'−',34,n.RED)
 if controlled or which=='healthy':
  active=.1<=t<=.14 if controlled else bool(np.max(a['u'][(a['t']>=max(0,t-1/n.FPS/n.SLOW))&(a['t']<=t)],initial=0)>0)
  n.electrode(d,active)
  if not controlled:txt(d,(902,73),'u(t)',30,anchor='rm')
 if controlled:
  pulse=.1<=t<=.14
  for points,xy,s in [([(69,277),(96,277)],(40,244),'dG'), ([(854,277),(825,277)],(873,244),'dS')]:
   n.arrow(d,points,n.ORANGE if pulse else '#C4C7CA',4 if pulse else 2);txt(d,xy,s,25,n.ORANGE,anchor='mm')
  for yy,s,c in [(545,'u: control',n.CONTROL),(590,'dS, dG: external pulse',n.ORANGE)]:
   d.line((230,yy+12,275,yy+12),fill=c,width=4);txt(d,(295,yy),s,28,c)
n.network=network
# Keep only the labels needed to read the plots. All are native overlays.
oldtxt=txt
def concise(d,xy,s,*args,**kwargs):
 if '40x slower' in s:return
 replacements={'Population deviations (spikes/s)':'Deviation (spikes/s)', 'External stimulation u(t) (spikes/s)':'Stimulation (spikes/s)', 'Control and external pulse (spikes/s)':'Inputs (spikes/s)', 'Dashed: same pulse, controller off':'Dashed: controller off', 'GPe / Proto':'GPe'}
 return oldtxt(d,xy,replacements.get(s,s),*args,**kwargs)
n.txt=concise
def encode(name,frames,w,h,fps):
 cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{w}x{h}','-r',str(fps),'-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(B/(name+'.mp4'))]
 with subprocess.Popen(cmd,stdin=subprocess.PIPE) as p:
  for i,im in enumerate(frames):
   p.stdin.write(im.tobytes())
   if i%180==0:print(name,i,flush=True)
  p.stdin.close();assert p.wait()==0
 subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(B/(name+'.mp4')),'-frames:v','1',str(B/(name+'-first.png'))],check=True)
def neurons():
 global capture,labels
 n.verify()
 for which in ['healthy','parkinsonian','controlled']:
  labels=[];capture=True;n.render(which,0);capture=False
  (B/(which+'-labels.json')).write_text(json.dumps(labels,ensure_ascii=False),encoding='utf8')
  end=.5 if which=='controlled' else .4
  encode(which,(n.render(which,min(end,i/1200)) for i in range(round(end*1200)+60)),1920,740,30)
  n.render(which,end).save(B/(which+'-end.png'))
def delta():
 global capture,labels
 data=np.load(OLD/'delta_trajectories.npz');T,Y,D,L=[data[k] for k in ['t','y','delta','lambda1']]
 def render(i,t):
  im=Image.new('RGB',(1920,540),'white');d=ImageDraw.Draw(im);x0,y0,x1,y1=140,58,1330,448
  def xy(ts,ys):return np.c_[x0+np.asarray(ts)/30*(x1-x0),y1-np.asarray(ys)/100*(y1-y0)]
  txt(d,(x0,6),'Average temperature deviation',32)
  for y in range(0,101,20):
   yy=xy([0],[y])[0,1];d.line((x0,yy,x1,yy),fill='#E5E8EB',width=1);txt(d,(x0-22,yy),str(y),28,n.GRAY,anchor='rm')
  d.line((x0,y0,x0,y1,x1,y1),fill=n.GRAY,width=2)
  for t0 in range(0,31,5):txt(d,(x0+t0/30*(x1-x0),y1+12),str(t0),28,n.GRAY,anchor='mt')
  txt(d,(x1,y1+46),'Time (s)',29,n.GRAY,anchor='rt')
  xp=xy([8],[0])[0,0]
  for yy in range(y0,y1,15):d.line((xp,yy,xp,min(yy+7,y1)),fill='#B5BCC3',width=2)
  txt(d,(xp+10,y0+10),'Heater off',27,n.GRAY)
  for j in range(i+1):
   ids=T<=(30 if j<i else t);pts=xy(T[ids],Y[j,ids]);color='#C81919' if L[j]>0 and (j<i or t>8) else n.BLUE
   if len(pts)>1:d.line([tuple(p) for p in pts],fill=color,width=4)
   if j==i:
    x,y=pts[-1];d.ellipse((x-6,y-6,x+6,y+6),fill=color)
  for j,delta in enumerate(D):
   yy=92+j*55;col='#C81919' if L[j]>0 else n.BLUE
   d.line((1440,yy+15,1484,yy+15),fill=col,width=4);txt(d,(1504,yy),f'δ = {delta:+.3f}',32,col)
  txt(d,(1440,440),'Red: diverging',28,'#C81919')
  return im
 labels=[];capture=True;render(0,0);capture=False
 (B/'delta-labels.json').write_text(json.dumps(labels,ensure_ascii=False),encoding='utf8')
 encode('delta',(render(i,min(30,k/30*12)) for i in range(6) for k in range(90)),1920,540,30)
 render(5,30).save(B/'delta-end.png')
def slopes():
 sys.path.insert(0,str(ROOT/'Presentation/SectorIQC'))
 import render_zames_falb as z
 import inspect
 source=inspect.getsource(z.render)
 start=source.index('        p=axes(BOXES[k]');end=source.index('    ids=list',start)
 source=source[:start]+'''        p=axes(BOXES[k],[-lim,lim],[0,1.05],[-lim,0,lim],[0,.5,1])
        for v in [0,1]:
            for x in np.linspace(-lim,lim,70)[:-1:2]:d.line([p(x,v),p(x+2*lim/70,v)],fill='#888888',width=1)
        z=np.linspace(-lim,lim,501);M=[300,400][k];star=data['zStar'][k]
        slope=1/np.cosh(2*(star+z)/M)**2
        d.line([p(a,b) for a,b in zip(z,slope)],fill=COLORS[k],width=2.5)
        current=data['z'][i,k];value=1/np.cosh(2*(star+current)/M)**2
        assert 0<=value<=1
        x,y=p(current,value);d.ellipse((x-5,y-5,x+5,y+5),fill=COLORS[k])
''' +source[end:]
 exec(source,z.__dict__)
 with np.load(z.OUT/'stn_gpe_zames_falb_data.npz') as a:data={k:a[k] for k in a.files}
 for rate,name in [(False,'slope-integral'),(True,'slope-rate')]:
  encode(name,(z.render(data,round(min(i,288)*(len(data['t'])-1)/288),rate) for i in range(337)),3840,2160,24)
  z.render(data,len(data['t'])-1,rate).save(B/(name+'-end.png'))
if __name__=='__main__':
 {'neurons':neurons,'delta':delta,'slopes':slopes}[sys.argv[1]]()
