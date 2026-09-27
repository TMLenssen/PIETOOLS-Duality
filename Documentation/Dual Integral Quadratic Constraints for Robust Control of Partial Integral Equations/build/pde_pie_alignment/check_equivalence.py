"""Check the displayed identities for nontrivial compatible delay histories."""
import numpy as np
from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom as D
import json
B=Path(__file__).resolve().parent
# x is exponential for positive time, with a compatible quadratic history term.
# The history term tests the transport transient before the initial history exits.
def traj(q,tau,c,a,derivative=0):
 q=np.asarray(q)
 if derivative==0:return c*np.exp(-q/tau)+a*np.minimum(q,0)**2
 if derivative==1:return -c/tau*np.exp(-q/tau)+2*a*np.minimum(q,0)
 return c/tau**2*np.exp(-q/tau)+2*a*(q<0)
nodes,weights=np.polynomial.legendre.leggauss(40)
def integrate(fn,t,s,delay):
 cuts=sorted(set([0.,s]+([t/delay] if 0<t/delay<s else [])))
 return sum((b-a)/2*np.dot(weights,fn((b-a)/2*nodes+(b+a)/2)) for a,b in zip(cuts,cuts[1:]))
worst=[0.,0.]
for tau,delay,c,a in [(14.,6.,.7,.002),(6.,6.,-.4,-.003),(14.,4.,.7,.002)]:
 for t in [.1,1.8,3.3,5.7,8.,20.]:
  for s in [.12,.43,.81,1.]:
   phi=traj(t-delay*s,tau,c,a)
   v=-delay*traj(t-delay*s,tau,c,a,1)
   phi_rebuilt=traj(t,tau,c,a)+integrate(lambda th:-delay*traj(t-delay*th,tau,c,a,1),t,s,delay)
   pie_lhs=traj(t,tau,c,a,1)+integrate(lambda th:-delay*traj(t-delay*th,tau,c,a,2),t,s,delay)
   worst[0]=max(worst[0],abs(phi-phi_rebuilt));worst[1]=max(worst[1],abs(pie_lhs+v/delay))
assert max(worst)<1e-12,worst
with ZipFile(B/'final.pptx') as z,ZipFile(B/'source.pptx') as source:
 parts=json.loads((B/'parts.json').read_text())
 for p in parts:
  if p not in parts[19:26]:assert z.read(p)==source.read(p),p
 for p in source.namelist():
  if p.startswith('ppt/media/'):assert z.read(p)==source.read(p),p
 for p in parts[19:26]:
  d=D.parseString(z.read(p))
  for n in list(d.getElementsByTagName('mc:Fallback')):n.parentNode.removeChild(n)
  ids=[n.getAttribute('id') for n in d.getElementsByTagName('p:cNvPr')];assert len(ids)==len(set(ids)),p
 d=D.parseString(z.read(parts[20]))
 for nm in ['PIE distributed dynamics','Exact state reconstruction']:
  shape=next(n for n in d.getElementsByTagName('p:sp') if n.getElementsByTagName('p:cNvPr')[0].getAttribute('name')==nm)
  assert '+' in ''.join(n.firstChild.data for n in shape.getElementsByTagName('m:t') if n.firstChild)
report=dict(reconstruction_max_error=worst[0],pie_dynamics_max_error=worst[1],unchanged_other_slides=True,unchanged_original_media=True)
(B/'validation.json').write_text(json.dumps(report,indent=2));print(report)
