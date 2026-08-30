function [prog,V] = PIETOOLS_IQC_slope(prog,dp,dn,hatalpha,hatbeta,set,vars,dom)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Primal slope IQC for a repeated scalar nonlinearity.
%
% The nonlinearity is slope restricted by
% hatalpha <= dphi/dz <= hatbeta.
%
% Setting:
%   multiplierUpper = 1e6
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~isfinite(hatalpha) || ~isfinite(hatbeta) || hatalpha >= hatbeta
    error('Slope bounds must satisfy hatalpha < hatbeta.');
end
if dp(2) ~= 1 || dn(2) ~= 1
    error('This IQC requires one distributed uncertainty channel.');
end

multiplierUpper = scalar_setting(set,'multiplierUpper',1e6);
validate_settings(multiplierUpper);

d = dp + dn;
V = opvar2dopvar(zerosPI(d,d,vars,dom));
if dp(1) > 0 || dn(1) > 0
    V.P = blkdiag(eye(dp(1)),-eye(dn(1)));
else
    V.P = zeros(0,0);
end

I1 = eyePI([0;1],vars,dom);
Z = zerosPI([0;1],[0;1],vars,dom);
Vdist = zerosPI([0;2],[0;2],vars,dom);

Tslope = mat2opvar( ...
    [hatbeta,-1; -hatalpha,1], ...
    [0,0;2,2],vars,dom);
[prog,m] = positive_pointwise_weight(prog,set);
[prog,hDiff,s,th,a,b] = interval_sos_kernel(prog,set);
Sslope = m+pairwise_difference_operator(hDiff,s,th,a,b);
if isfinite(multiplierUpper)
    prog = lpi_ineq(prog,multiplierUpper*I1-Sslope);
end
Vdist = Vdist+Tslope'*[Z,Sslope'; Sslope,Z]*Tslope;

V.R = Vdist.R;
end

function [prog,E] = positive_pointwise_weight(prog,set)
op = set.options1;
op.sep = 0;
op.exclude = [0 0 1 1];
op.psatz = 0;
[prog,E] = poslpivar(prog,[0;1],set.ddM,op);
end

function [prog,h,s,th,a,b] = interval_sos_kernel(prog,set)
op = set.options1;
op.sep = 0;
op.exclude = [0 1 0 1];
op.psatz = 0;

[prog,q0,Z0] = sos_kernel_term(prog,set.ddM,op);
s = Z0.var1;
th = Z0.var2;
a = Z0.I(1);
b = Z0.I(2);
h = q0;

% Symmetrization preserves pointwise nonnegativity on [a,b]^2.
h = 0.5*(h+varswap(h,s,th));
end

function [prog,q,Z] = sos_kernel_term(prog,ddM,op)
[prog,~,Q,Z] = poslpivar(prog,[0;1],ddM,op);
z = Z.R.R1;
q = z.'*Q*z;
end

function R = pairwise_difference_operator(h,s,th,a,b)
dopvar R;
R.I = [a,b];
R.var1 = s;
R.var2 = th;
R.R.R0 = int(h,th,a,b);
R.R.R1 = -h;
R.R.R2 = -h;
end

function value = scalar_setting(set,fieldName,defaultValue)
if isfield(set,fieldName) && ~isempty(set.(fieldName))
    value = set.(fieldName);
else
    value = defaultValue;
end
end

function validate_settings(multiplierUpper)
if ~isscalar(multiplierUpper) || multiplierUpper <= 0
    error('settings.multiplierUpper must be a positive scalar.');
end
end
