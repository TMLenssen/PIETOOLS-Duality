function [prog,V] = PIETOOLS_IQC_slope_dual(prog,dp,dn,hatalpha,hatbeta,set,vars,dom,name)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Inverse-safe dual slope IQC for a repeated scalar nonlinearity.
%
% The nonlinearity is slope restricted by
% hatalpha <= dphi/dz <= hatbeta.
%
% The dual 3PI weight has coefficients S0=m+lambda and S1=S2=lambda.
% Its exact inverse has the valid primal slope form.
%
% Settings:
%   multiplierUpper      = 1e6
%   inverseFloor         = 1e-6
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~isfinite(hatalpha) || ~isfinite(hatbeta) || hatalpha >= hatbeta
    error('Slope bounds must satisfy hatalpha < hatbeta.');
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
Vdist = zerosPI([0;2],[0;2],vars,dom);

[prog,m] = positive_pointwise_weight(prog,set);
[prog,lambda] = lpidecvar(prog,'placeholder');
prog = lpi_ineq(prog,m-inverseFloor*I1);
prog = lpi_ineq(prog,lambda);
if isfinite(multiplierUpper)
    intervalLength = dom(2)-dom(1);
    prog = lpi_ineq(prog, ...
        (multiplierUpper-(1+intervalLength)*lambda)*I1-m);
end
Tslope = mat2opvar( ...
    [hatbeta,-1; -hatalpha,1], ...
    [0,0;2,2],vars,dom);

Sslope = m+lambda*I1;
Sslope.R.R1 = lambda;
Sslope.R.R2 = lambda;
Vdist = Vdist+(1/(hatbeta-hatalpha)^2) ...
    *Tslope'*[Z,Sslope'; Sslope,Z]*Tslope;

V.R = Vdist.R;
end

function [prog,E] = positive_pointwise_weight(prog,set)
op = set.options1;
op.sep = 0;
op.exclude = [0 0 1 1];
op.psatz = 0;
[prog,E] = poslpivar(prog,[0;1],set.ddM,op);
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
