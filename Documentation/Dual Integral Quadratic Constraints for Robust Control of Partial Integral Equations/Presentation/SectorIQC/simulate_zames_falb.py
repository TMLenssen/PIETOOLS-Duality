"""Paper's three-pole Zames--Falb filter on the unchanged Parkinsonian trajectory.

The global slope bound is 1; the paper's synthesis value .562 is local.
The causal filter starts at zero, irrespective of the plant's delay history.
"""
from pathlib import Path
import json
import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE / 'Simulation/STN_GPe_Zames_Falb'
RATES = 1 / np.array([.014, .006, .004])
WEIGHTS = (10/15) * np.array([10.7, 20., 12.3]) / 43.
ALPHA = 1.

def evaluate(t, z, w):
    e = ALPHA*z-w
    state = np.zeros((3, 2))
    filtered = np.zeros_like(e)
    for j, dt in enumerate(np.diff(t)):
        decay = np.exp(-RATES*dt)
        gain = -np.expm1(-RATES*dt)
        # Exact filter propagation for piecewise-linear sampled input.
        ramp_gain = dt-gain/RATES
        state = decay[:, None]*state + gain[:, None]*e[j] + ramp_gain[:, None]*(e[j+1]-e[j])/dt
        filtered[j+1] = WEIGHTS @ state
    q = 2*w*(e-filtered)  # Exact normalization of Pi_ZF in the manuscript.
    integral = np.vstack([np.zeros(2), np.cumsum((q[1:]+q[:-1])*np.diff(t)[:, None]/2, axis=0)])
    return filtered, q, integral

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source = HERE/'Simulation/STN_GPe/stn_gpe_sector_data.npz'
    with np.load(source) as d:
        data = {k:d[k].copy() for k in d.files}
    t,z,w = (data[k] for k in ['t','z','w'])
    filtered,q,integral = evaluate(t,z,w)
    _,_,coarse = evaluate(t[::2],z[::2],w[::2])
    discrepancy = np.max(np.abs(coarse-integral[::2]),axis=0)
    assert np.all(integral >= -1e-8)
    assert np.all(q.min(axis=0)<0)
    assert np.max(discrepancy)<.1, discrepancy
    assert np.isclose(WEIGHTS.sum(),2/3)
    derivative = 1/np.cosh(2*(z+data['zStar'])/np.array([300.,400.]))**2
    results = dict(alpha=ALPHA, poles=(-RATES).tolist(), residues=(WEIGHTS*RATES).tolist(),
        filter_L1_norm=float(WEIGHTS.sum()), filter_initial_state='zero',
        supply='q_i(t)=2*w_i(t)*[alpha*z_i(t)-w_i(t)-H(alpha*z_i-w_i)(t)]',
        normalization='Matches the unregularized Pi_ZF matrix in manuscript Section 9.',
        duration_s=float(t[-1]), timestep_s=float(t[1]-t[0]),
        minimum_supply=q.min(axis=0).tolist(), minimum_integral=integral.min(axis=0).tolist(),
        final_integral=integral[-1].tolist(), refinement_max_error=discrepancy.tolist(),
        trajectory_max_slope=derivative.max(axis=0).tolist(),
        source_trajectory=str(source),
        qualification='Same exact nonlinearities and plant response as sector simulation. The paper synthesis slope .562 is local and invalid for this trajectory. Global slope 1 is used with the identical paper filter. No epsilon regularization is included. This illustrates a hard IQC, not closed-loop stability.')
    data.update(filtered=filtered,q=q,integral=integral)
    np.savez_compressed(OUT/'stn_gpe_zames_falb_data.npz',**data)
    (OUT/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    np.savetxt(OUT/'supply_history.csv',np.c_[t,q,integral],delimiter=',',header='t,qS,qG,integralS,integralG',comments='')
    ids=np.arange(0,len(t),20)
    browser={k:data[k][ids].tolist() for k in ['t','x','z','w','q','integral','filtered']}
    browser.update(M=[300,400],zStar=data['zStar'].tolist(),alpha=ALPHA)
    template=(HERE/'zames_falb_interactive.html').read_text(encoding='utf-8')
    (OUT/'STN-GPe Zames-Falb simulation.html').write_text(template.replace('/*SIMULATION_DATA*/','window.STN_DATA='+json.dumps(browser,separators=(',',':'))+';'),encoding='utf-8')
    (OUT/'README.md').write_text('''# STN–GPe Zames–Falb simulation

Uses the three-pole multiplier in Section 9 of the manuscript:
M(s)=1-H(s), H(s)=sum_k kappa_k/(s+a_k),
a=(1/.014,1/.006,1/.004), kappa_k=(2/3)*(10.7,20,12.3)_k/43*a_k.
The filter starts at zero. Its impulse response is nonnegative and has L1 norm 2/3.

The nonlinearities, delays, initial history, and response are exactly those of the sector demonstration.
Global slope alpha=1 is used. The synthesis value .562 is local and does not cover this trajectory.
The supply q_i=2*w_i*(alpha*z_i-w_i-H(alpha*z_i-w_i)) matches the paper's unregularized matrix normalization.
The integral can decrease while remaining nonnegative. This is a hard IQC for this causal realization.
It does not assert stability of the feedback interconnection, or identify the IQC integral with physical energy.

The HTML has editable DOM labels and switches between accumulated supply and instantaneous supply.
The 4K video and poster contain no baked labels; the accompanying PowerPoint has editable text/math overlays.
Regenerate: python Presentation/SectorIQC/simulate_zames_falb.py
Render: python Presentation/SectorIQC/render_zames_falb.py
''',encoding='utf-8')
    print(json.dumps(results,indent=2))

if __name__=='__main__':main()
