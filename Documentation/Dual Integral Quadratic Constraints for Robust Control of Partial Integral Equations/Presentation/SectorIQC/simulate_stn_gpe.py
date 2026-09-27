"""Reproduce the project's Parkinsonian delay model and animate its sector IQC.
Uses the equilibrium-shifted STN/GPe activations, not a generic surrogate.
"""
from pathlib import Path
import numpy as np
import json,math,subprocess,shutil
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent/'Simulation/STN_GPe';OUT.mkdir(parents=True,exist_ok=True)
M=np.array([300.,400.]);B=np.array([17.,75.]);TAU=np.array([.006,.014])
HISTORY=np.array([1.,0.]);DELAY=np.array([.006,.006,.004]);ROWS=np.array([1,0,1])
def F(q):return M/(1+np.exp(np.clip(-4*np.asarray(q)/M,-700,700))*(M-B)/B)
def FS(q):return 300/(1+math.exp(-4*q/300)*(300-17)/17)
def FG(q):return 400/(1+math.exp(-4*q/400)*(400-75)/75)
lo,hi=0.,400.
for _ in range(90):
    g=(lo+hi)/2;stn=FS(-10.7*g+9.2*27)
    if FG(20*stn-12.3*g-139.4*2)-g>0:lo=g
    else:hi=g
g=(lo+hi)/2;EQ=np.array([FS(-10.7*g+9.2*27),g])
QSTAR=np.array([-10.7*g+9.2*27,20*EQ[0]-12.3*g-139.4*2])
C=M/4*np.log((M-B)/B);ZSTAR=QSTAR-C
def delta(z):return M/2*(np.tanh(2*(ZSTAR+z)/M)-np.tanh(2*ZSTAR/M))
assert np.max(np.abs(F(QSTAR)-EQ))<1e-10
assert np.max(np.abs(delta(np.zeros(2))))==0

# Tight global secant bounds for the Parkinsonian equilibrium. At the maximum,
# v*delta'(v)=delta(v). Both inflection points lie to the right of the origin.
# For v<0 the secant slope is below delta'(0); on v>0 the maximum is unique.
lo=-ZSTAR.copy();hi=lo+10*M
for _ in range(100):
    mid=(lo+hi)/2
    positive=mid/np.cosh(2*(ZSTAR+mid)/M)**2-delta(mid)>0
    lo=np.where(positive,mid,lo);hi=np.where(positive,hi,mid)
TANGENCY=(lo+hi)/2
BETA=delta(TANGENCY)/TANGENCY
assert np.max(np.abs(BETA-1/np.cosh(2*(ZSTAR+TANGENCY)/M)**2))<1e-12
# Dense independent check includes both tails, the origin and tangent points.
probe=np.vstack([np.linspace(-20000,20000,200001)[:,None]*np.ones(2),TANGENCY])
ratios=np.divide(delta(probe),probe,out=np.broadcast_to(1/np.cosh(2*ZSTAR/M)**2,probe.shape).copy(),where=probe!=0)
assert np.min(ratios)>=0 and np.max(ratios-BETA)<1e-12

def simulate(h):
    t=np.arange(round(.4/h)+1)*h;x=np.zeros((len(t),2));x[0]=HISTORY
    lags=DELAY/h
    def delayed(k,c):
        pos=k+c-lags;lower=np.floor(np.maximum(pos,0)).astype(int);frac=np.maximum(pos,0)-lower
        v=(1-frac)*x[lower,ROWS]+frac*x[lower+1,ROWS]
        return np.where(pos>0,v,HISTORY[ROWS])
    def rhs(state,v):
        return (delta(np.array([-10.7*v[0],20*v[1]-12.3*v[2]]))-state)/TAU
    for k in range(len(t)-1):
        k1=rhs(x[k],delayed(k,0));mid=delayed(k,.5)
        k2=rhs(x[k]+h*k1/2,mid);k3=rhs(x[k]+h*k2/2,mid)
        k4=rhs(x[k]+h*k3,delayed(k,1))
        x[k+1]=x[k]+h*(k1+2*k2+2*k3+k4)/6
    return t,x

def compute():
    tc,xc=simulate(20e-6);t,x=simulate(10e-6)
    error=float(np.max(np.abs(x[::2]-xc)));assert error<.05
    saved=np.genfromtxt(ROOT/'Figures/STN_GPe/stn_parkinsonian_stimulation.csv',delimiter=',',names=True)
    reference=np.c_[saved['xS_spikes_per_s'],saved['xG_spikes_per_s']]
    reference_error=float(np.max(np.abs(x-reference)));assert reference_error<1e-5
    delayed_gs=np.interp(t-.006,t,x[:,1],left=0)
    delayed_sg=np.interp(t-.006,t,x[:,0],left=1)
    delayed_gg=np.interp(t-.004,t,x[:,1],left=0)
    z=np.c_[-10.7*delayed_gs,20*delayed_sg-12.3*delayed_gg]
    w=delta(z);q=w*(BETA*z-w)
    integ=np.vstack([np.zeros(2),np.cumsum((q[1:]+q[:-1])/2*np.diff(t)[:,None],axis=0)])
    assert q.min()>-1e-9 and np.diff(integ,axis=0).min()>-1e-9
    assert np.max(np.abs(q-(BETA*z*w-w*w)))<1e-9
    coarse_integral=np.trapezoid(q[::2],t[::2],axis=0)
    assert np.max(np.abs(coarse_integral-integ[-1]))<.01
    results=dict(model='Parkinsonian GPe–STN delayed network from the manuscript and stn_parkinsonian_stimulation.m',
        duration_s=.4,dt_s=1e-5,sector_lower=[0,0],sector_upper=BETA.tolist(),sector_tangency=TANGENCY.tolist(),equilibrium=EQ.tolist(),shifted_inputs=ZSTAR.tolist(),
        weights=dict(wSG=20,wGS=10.7,wGG=12.3,wCS=9.2,wXG=139.4),
        refinement_error=error,existing_MATLAB_trajectory_error=reference_error,
        minimum_supply=q.min(axis=0).tolist(),integral_final=integ[-1].tolist(),
        integral_refinement_error=np.abs(coarse_integral-integ[-1]).tolist(),
        description='w_i(t)=delta_i(z_i(t)) is the activation output, not the firing-rate deviation x_i(t). q_i=w_i(beta_i*z_i-w_i)>=0. beta_i are tight global sector bounds, not slope bounds. The manuscript value 0.492 is only locally applicable. Delta dissipativity does not imply feedback stability.')
    (OUT/'results.json').write_text(json.dumps(results,indent=2))
    np.savez_compressed(OUT/'stn_gpe_sector_data.npz',t=t,x=x,z=z,w=w,q=q,integral=integ,equilibrium=EQ,zStar=ZSTAR,beta=BETA)
    np.savetxt(OUT/'supply_history.csv',np.c_[t,q,integ],delimiter=',',header='t,qS,qG,integralS,integralG',comments='')
    ids=np.arange(0,len(t),20)
    browser=dict(t=t[ids].tolist(),x=x[ids].tolist(),z=z[ids].tolist(),w=w[ids].tolist(),q=q[ids].tolist(),integral=integ[ids].tolist(),M=M.tolist(),zStar=ZSTAR.tolist(),equilibrium=EQ.tolist(),beta=BETA.tolist())
    (OUT/'data.js').write_text('window.STN_DATA='+json.dumps(browser,separators=(',',':'))+';',encoding='utf-8')
    template=(Path(__file__).parent/'stn_gpe_interactive.html').read_text(encoding='utf-8')
    (OUT/'STN-GPe sector simulation.html').write_text(template.replace('/*SIMULATION_DATA*/','window.STN_DATA='+json.dumps(browser,separators=(',',':'))+';'),encoding='utf-8')
    print(json.dumps(results,indent=2),flush=True)
    return t,x,z,w,q,integ

from render_dissipativity import render

def main():
    import sys
    if '--render-only' in sys.argv:
        saved=np.load(OUT/'stn_gpe_sector_data.npz')
        data=tuple(saved[key] for key in ['t','x','z','w','q','integral'])
        template=(Path(__file__).parent/'stn_gpe_interactive.html').read_text(encoding='utf-8')
        (OUT/'STN-GPe sector simulation.html').write_text(template.replace('/*SIMULATION_DATA*/',(OUT/'data.js').read_text(encoding='utf-8')),encoding='utf-8')
    else:
        data=compute()
    render(data,28000).save(OUT/'STN-GPe sector simulation.png')
    ff=shutil.which('ffmpeg')
    if ff:
        cmd=[ff,'-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1440x810','-r','24','-i','-','-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'STN-GPe sector simulation.mp4')]
        with subprocess.Popen(cmd,stdin=subprocess.PIPE) as p:
            for k in range(289):p.stdin.write(render(data,round(k*40000/288)).tobytes())
            for _ in range(48):p.stdin.write(render(data,40000).tobytes())
            p.stdin.close();assert p.wait()==0
    print('Saved STN-GPe sector simulation and video.',flush=True)

if __name__=='__main__':main()
