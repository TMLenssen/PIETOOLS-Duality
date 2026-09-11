function [sectorUpper,slopeUpper] = stn_gpe_admissible_trajectories(beta,Kd)
%STN_GPE_ADMISSIBLE_TRAJECTORIES Input limits for Example 4's shifted sigmoids.
%   [sectorUpper,slopeUpper] = stn_gpe_admissible_trajectories(beta,Kd)
%   returns [S,G] limits such that z_i(t) <= the corresponding upper bound.
%   Kd defaults to 1. Use sectorUpper for a sector certificate and slopeUpper for a ZF
%   slope certificate. Inf means no restriction; invariance is not tested.
%
%   Example: [sectorUpper,slopeUpper] = stn_gpe_admissible_trajectories(0.4);

if nargin<2
    Kd = 1;
end
validateattributes(beta,{'numeric'},{'real','finite','scalar','positive'});
validateattributes(Kd,{'numeric'},{'real','finite','scalar'});
[~,zStar,~,p] = stn_gpe_equilibrium(Kd);
M = [p.MS,p.MG];
sectorUpper = [Inf,Inf];
slopeUpper = [Inf,Inf];
if beta>=1
    return
end
assert(all(zStar<0), ...
    'This helper assumes both equilibria are below the sigmoid midpoint.');

% Invert the sigmoid derivative to find the slope boundary.
distance = (M/2)*acosh(1/sqrt(beta));
slopeUpper = -zStar-distance;
assert(all(slopeUpper>0), ...
    'beta must exceed both equilibrium slopes to admit a neighborhood.');

for i = 1:2
    delta = @(z) (M(i)/2)*(tanh(2*(zStar(i)+z)/M(i)) ...
        -tanh(2*zStar(i)/M(i)));
    gap = @(z) delta(z)-beta*z;
    % The gap peaks where the derivative falls back to beta, beyond the
    % midpoint. If this peak is positive, bracket the FIRST sector crossing.
    peak = -zStar(i)+distance(i);
    if gap(peak)>0
        sectorUpper(i) = fzero(gap,[slopeUpper(i),peak]);
    end
end
end
