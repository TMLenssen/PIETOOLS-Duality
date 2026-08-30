function [prog,V] = PIETOOLS_IQC_sector(prog,dp,dn,alpha,beta,set,vars,dom)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pointwise sector IQC for a repeated scalar nonlinearity. The positive
% pointwise sector family has the same form in primal and dual coordinates.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~isfinite(alpha) || ~isfinite(beta) || alpha >= beta
    error('Sector bounds must satisfy alpha < beta.');
end
if dp(2) ~= 1 || dn(2) ~= 1
    error('This IQC requires one distributed uncertainty channel.');
end

multiplierUpper = scalar_setting(set,'multiplierUpper',1e6);
inverseFloor = scalar_setting(set,'inverseFloor',1e-6);
validate_settings(multiplierUpper,inverseFloor);

d = dp+dn;
V = opvar2dopvar(zerosPI(d,d,vars,dom));
if dp(1) > 0 || dn(1) > 0
    V.P = blkdiag(eye(dp(1)),-eye(dn(1)));
else
    V.P = zeros(0,0);
end

I1 = eyePI([0;1],vars,dom);
Z = zerosPI([0;1],[0;1],vars,dom);
[prog,M] = positive_pointwise_weight(prog,set);
prog = lpi_ineq(prog,M-inverseFloor*I1);
if isfinite(multiplierUpper)
    prog = lpi_ineq(prog,multiplierUpper*I1-M);
end

Tsector = mat2opvar( ...
    [beta,-1; -alpha,1], ...
    [0,0;2,2],vars,dom);
Vdist = Tsector'*[Z,M'; M,Z]*Tsector;
V.R = Vdist.R;
end

function [prog,M] = positive_pointwise_weight(prog,set)
op = set.options1;
op.sep = 0;
op.exclude = [0 0 1 1];
op.psatz = 0;
[prog,M] = poslpivar(prog,[0;1],set.ddM,op);
end

function value = scalar_setting(set,fieldName,defaultValue)
if isfield(set,fieldName) && ~isempty(set.(fieldName))
    value = set.(fieldName);
else
    value = defaultValue;
end
end

function validate_settings(multiplierUpper,inverseFloor)
if ~isscalar(multiplierUpper) || multiplierUpper <= 0
    error('settings.multiplierUpper must be a positive scalar.');
end
if ~isscalar(inverseFloor) || ~isfinite(inverseFloor) || inverseFloor <= 0
    error('settings.inverseFloor must be a positive finite scalar.');
end
if isfinite(multiplierUpper) && inverseFloor >= multiplierUpper
    error('settings.inverseFloor must be smaller than settings.multiplierUpper.');
end
end
