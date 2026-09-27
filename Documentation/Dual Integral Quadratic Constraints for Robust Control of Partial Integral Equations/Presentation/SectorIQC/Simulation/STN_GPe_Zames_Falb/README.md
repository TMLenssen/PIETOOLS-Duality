# STN–GPe Zames–Falb simulation

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
