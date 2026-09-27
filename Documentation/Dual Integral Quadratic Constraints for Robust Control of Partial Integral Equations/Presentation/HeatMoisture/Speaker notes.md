Slide 26

Introduce two distributed states on the same normalized material domain: v1 is heat/temperature deviation and v2 is moisture deviation. These are an illustrative physical interpretation of the coupled PDE benchmark, not calibrated dimensional temperatures or moisture concentrations. Warm and blue gradients are schematic, not simulation results; the identical layer positions persist across all four slides. Show the nominal zero-input case delta=0, wp=0 first. Coupling is exactly +v1 in the moisture dynamics and -3v2 in the heat dynamics. At s=0 both deviations are zero; at s=1 both spatial derivatives are zero (no flux). The previous picture incorrectly displayed a zero value at the right boundary.

Slide 27

Introduce one fixed real scalar delta, shared by every location and all uncertainty-dependent coefficients, with |delta| <= alpha. At this stage wp=0. a(delta)=pi^2/2-2+delta(1+delta)/(1+delta^2). The moisture equation is unchanged. The red dashed outline marks the uncertain heat reaction, not an additional state or boundary input. Later the same delta also changes the disturbance and output coefficients.

Slide 28

Introduce wp(t) as a heat-load fluctuation. This is a distributed forcing b(delta)*s*wp(t), not a boundary disturbance; the arrows enter the interior of the heat layer. zp(t)=c(delta)*integral_0^1 v1(t,s) ds+d(delta)*wp(t). Physically interpret this as a weighted mean heat response with a direct contribution from the load. It is not a bound on the pointwise peak temperature or on moisture directly. Moisture affects the output through the heat-moisture coupling. b=(1-delta^2)/(1+delta^2), c=(1+3delta^2)/(1+delta^2), d=delta(1-delta)/(1+delta^2). The full PDE and boundary conditions remain those shown on slide 25.

Slide 29

Combine the two questions for every fixed admissible delta with |delta| <= alpha. Robust stability: in the absence of load, both distributed state deviations decay to zero (spatial L2 norm). Robust performance: from zero initial state, the temporal L2 norm of zp is at most gamma times the temporal L2 norm of wp, uniformly over the uncertainty set. These are requirements to certify, not a claim that a certificate has already been found for the displayed coefficients. Smaller gamma means less amplification of heat-load fluctuations. No pointwise temperature or moisture limit is claimed.