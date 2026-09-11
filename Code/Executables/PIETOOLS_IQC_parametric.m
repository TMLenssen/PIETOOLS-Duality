function [prog,V] = PIETOOLS_IQC_parametric(prog,dp,dn,set,vars,dom)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Repeated-real-parametric IQC. The positive multiplier family is
%
%              [ Q,      S-S';
%                S'-S,   -Q  ],
%
% where Q is positive and the same family applies in primal and dual
% coordinates because Delta=delta*I is self-adjoint.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if dp(2)~=dn(2) || dp(2)<1
    error('The distributed positive/negative channel counts must agree.');
end

multiplierUpper = scalar_setting(set,'multiplierUpper',inf);
inverseFloor = scalar_setting(set,'inverseFloor',0);
if inverseFloor<0 || ~isfinite(inverseFloor)
    error('settings.inverseFloor must be a finite nonnegative scalar.');
end
if multiplierUpper<=inverseFloor
    error('settings.multiplierUpper must exceed settings.inverseFloor.');
end

n = dp(2);
Qblocks = cell(1,n);
Sblocks = cell(1,n);
I1 = eyePI([0;1],vars,dom);
op = set.options1;
for k = 1:n
    [prog,Qblocks{k}] = poslpivar(prog,[0,0;1,1],set.ddM,op);
    [prog,Sblocks{k}] = lpivar(prog,[0,0;1,1],set.ddM,op);
    if inverseFloor>0
        prog = lpi_ineq(prog,Qblocks{k}-inverseFloor*I1);
    end
    if isfinite(multiplierUpper)
        prog = lpi_ineq(prog,multiplierUpper*I1-Qblocks{k});
    end
end

Q = blkdiag(Qblocks{:});
S = blkdiag(Sblocks{:});
R = [Q,S-S'; S'-S,-Q];

d = dp+dn;
V = opvar2dopvar(zerosPI(d,d,vars,dom));
if dp(1)>0 || dn(1)>0
    V.P = blkdiag(eye(dp(1)),-eye(dn(1)));
end
V.R = R.R;
end

function value = scalar_setting(set,fieldName,defaultValue)
if isfield(set,fieldName) && ~isempty(set.(fieldName))
    value = set.(fieldName);
else
    value = defaultValue;
end
end
