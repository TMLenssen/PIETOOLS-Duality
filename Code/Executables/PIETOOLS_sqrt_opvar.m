function [X,prog,info] = PIETOOLS_sqrt_opvar(P,epsTol,epsX,settings,samplePoints)
%PIETOOLS_SQRT_OPVAR Approximate a positive square root of a 1-D PI operator.
%
% [X,PROG,INFO] = PIETOOLS_SQRT_OPVAR(P,EPSTOL,EPSX,SETTINGS,POINTS)
% finds a square, self-adjoint PI operator X intended to satisfy
%
%       P-EPSTOL*I <= X'*X <= P+EPSTOL*I,   X >= EPSX*I.
%
% Defaults:
%   EPSTOL  = 1e-2
%   EPSX    = 1e-8
%   SETTINGS = lpisettings('light',0,'','mosek')
%   POINTS   = 101 equally spaced points on P.I
%
% INFO contains the feasibility ratio, the residual X*X-P, componentwise
% sampled errors, and their maximum. PIETOOLS and the chosen solver must
% already be on the MATLAB path.
%
% The lower-bound LMI is the original square/self-adjoint v2
% construction. Its interpretation as X^2 >= P-eps*I assumes the relevant
% operators commute; this is not a general noncommutative equivalence.

narginchk(1,5);
if nargin < 2 || isempty(epsTol), epsTol = 1e-2; end
if nargin < 3 || isempty(epsX), epsX = 1e-8; end
if nargin < 4 || isempty(settings)
    settings = lpisettings('light',0,'','mosek');
end
if nargin < 5 || isempty(samplePoints)
    samplePoints = linspace(P.I(1),P.I(2),101);
end

validate_inputs(P,epsTol,epsX,settings,samplePoints);

prog = lpiprogram(P.var1,P.var2,P.I);
Iop = eyePI(P.dim(:,1),P.vars,P.I);

[prog,Xpositive] = positive_operator_sum(prog,P.dim,settings);
Xop = Xpositive+epsX*Iop;

Pupper = P+epsTol*Iop;
upperBlock = [Iop, Xop;
              Xop',Pupper];

Plower = P-epsTol*Iop;
lowerBlock = [Plower*Xop,Plower;
              Plower',   Xop];

prog = impose_positive_block(prog,upperBlock,settings);
prog = impose_positive_block(prog,lowerBlock,settings);

disp('- Solving the PI square-root LPI...');
prog = lpisolve(prog,settings.sos_opts);
ratio = get_feasibility_ratio(prog);
fprintf('PI square-root feasibility ratio: %.10g\n',ratio);
if ~isfinite(ratio) || ratio <= 0
    error('PIETOOLS_sqrt_opvar:InfeasibleLPI', ...
        'The square-root LPI was infeasible (feasibility ratio %.10g).',ratio);
end

X = lpigetsol(prog,Xop);
info = sampled_residual(X*X-P,samplePoints);
info.feasibilityRatio = ratio;
fprintf(['Error in P, Q1, R0, R1, R2 = ', ...
         '%.2e %.2e %.2e %.2e %.2e\n'], ...
        info.componentError.P,info.componentError.Q1, ...
        info.componentError.R0,info.componentError.R1, ...
        info.componentError.R2);
end

function validate_inputs(P,epsTol,epsX,settings,samplePoints)
if ~isa(P,'opvar')
    error('P must be a numerical one-dimensional opvar.');
end
if any(P.dim(:,1) ~= P.dim(:,2))
    error('P must have equal input and output dimensions.');
end
if ~isscalar(epsTol) || ~isreal(epsTol) || epsTol <= 0
    error('epsTol must be a positive real scalar.');
end
if ~isscalar(epsX) || ~isreal(epsX) || epsX < 0
    error('epsX must be a nonnegative real scalar.');
end
if ~isstruct(settings)
    error('settings must be a PIETOOLS lpisettings structure.');
end
required = {'dd2','options2','sos_opts'};
missing = required(~isfield(settings,required));
if ~isempty(missing)
    error('settings is missing field(s): %s.',strjoin(missing,', '));
end
if ~isnumeric(samplePoints) || isempty(samplePoints) || ...
        any(~isfinite(samplePoints(:)))
    error('samplePoints must be a nonempty finite numeric vector.');
end
if any(samplePoints(:) < P.I(1)) || any(samplePoints(:) > P.I(2))
    error('samplePoints must lie in P.I.');
end
end

function [prog,Pop] = positive_operator_sum(prog,dim,settings)
[prog,Pop] = poslpivar(prog,dim,settings.dd2,settings.options2);
useSecondCone = ~isfield(settings,'override2') || settings.override2 ~= 1;
if useSecondCone
    required = {'dd3','options3'};
    missing = required(~isfield(settings,required));
    if ~isempty(missing)
        error('settings is missing field(s): %s.',strjoin(missing,', '));
    end
    [prog,Pop2] = poslpivar(prog,dim,settings.dd3,settings.options3);
    Pop = Pop+Pop2;
end
end

function prog = impose_positive_block(prog,positiveBlock,settings)
[prog,slack] = positive_operator_sum(prog,positiveBlock.dim,settings);
prog = lpi_eq(prog,slack-positiveBlock,'symmetric');
end

function ratio = get_feasibility_ratio(prog)
try
    ratio = double(prog.solinfo.info.feasratio);
catch
    ratio = NaN;
end
if ~isscalar(ratio) || ~isreal(ratio), ratio = NaN; end
end

function info = sampled_residual(residual,samplePoints)
errors.P = max_abs_numeric(residual.P);
errors.Q1 = max_abs_1d(residual.Q1,residual.var1,samplePoints);
errors.R0 = max_abs_1d(residual.R.R0,residual.var1,samplePoints);
errors.R1 = max_abs_2d(residual.R.R1,residual.var1,residual.var2,samplePoints);
errors.R2 = max_abs_2d(residual.R.R2,residual.var1,residual.var2,samplePoints);
info.residual = residual;
info.componentError = errors;
info.maxSampledError = max([errors.P,errors.Q1,errors.R0,errors.R1,errors.R2]);
end

function err = max_abs_numeric(value)
if isempty(value), err = 0; else, err = max(abs(double(value)),[],'all'); end
end

function err = max_abs_1d(value,var,samplePoints)
if isempty(value), err = 0; return; end
err = 0;
for k = 1:numel(samplePoints)
    evaluated = double(subs(value,var,samplePoints(k)));
    err = max(err,max(abs(evaluated),[],'all'));
end
end

function err = max_abs_2d(value,var1,var2,samplePoints)
if isempty(value), err = 0; return; end
err = 0;
for k = 1:numel(samplePoints)
    partiallyEvaluated = subs(value,var1,samplePoints(k));
    for ell = 1:numel(samplePoints)
        evaluated = double(subs(partiallyEvaluated,var2,samplePoints(ell)));
        err = max(err,max(abs(evaluated),[],'all'));
    end
end
end
