function [Theta,J,info] = PIETOOLS_static_J_factorization( ...
    V,positiveDim,tol,samplePoints)
%PIETOOLS_STATIC_J_FACTORIZATION Factor a numerical static PN multiplier.
%
% [THETA,J,INFO] = PIETOOLS_STATIC_J_FACTORIZATION(V,POSITIVEDIM,...)
% constructs a feedthrough-only PI filter satisfying approximately
%
%                 V = THETA.operator'*J*THETA.operator.
%
% V must be a square opvar. A dopvar is recognized, but it must first be
% evaluated using Vsol=lpigetsol(prog,V). POSITIVEDIM is the
% [finite;distributed] dimension of the positive block. Channels are
% assumed to be ordered positive then negative within the finite and
% distributed components of V. If POSITIVEDIM is omitted, half of each
% total dimension is used.
%
% Defaults:
%   tol = 1e-3
%   samplePoints = 101 equally spaced points over V.I
%
% With V=[V11,V12;V21,V22], the upper-triangular construction is
%
%   S = V22-V21*inv_opvar_2(V11)*V12,
%   A ~= sqrt(V11),  B ~= sqrt(-S),
%   THETA.operator = [A, A*inv_opvar_2(V11)*V12; 0, B].
%
% THETA has zero dynamic states and fields T,A,B1,B2,C1,C2,D11,...,D22,
% so it can be passed directly to PIETOOLS_IQC_graph.

narginchk(1,4);
validate_multiplier_type(V);

if nargin < 2 || isempty(positiveDim)
    positiveDim = V.dim(:,1)/2;
end
if nargin < 3 || isempty(tol), tol = 1e-3; end
if nargin < 4 || isempty(samplePoints)
    samplePoints = linspace(V.I(1),V.I(2),101);
end

[V11,V12,V21,V22,positiveDim,negativeDim] = ...
    split_multiplier(V,positiveDim);

Ipositive = eyePI(positiveDim,V.vars,V.I);
Inegative = eyePI(negativeDim,V.vars,V.I);
J = blkdiag(Ipositive,-Inegative);

adjointError = sample_opvar_error(V21-V12',samplePoints);
if adjointError > 1e-6
    error('V21 must equal V12''; sampled mismatch is %.3e.',adjointError);
end

% Remove insignificant numerical asymmetry before inversion/square roots.
V11 = 0.5*(V11+V11');
V22 = 0.5*(V22+V22');

iopts.N = 60;
iopts.mulDeg = 6;
iopts.kerDeg = [6,6];
V11inv = invert_op(V11,iopts,samplePoints);
inverseResidual = V11*V11inv-Ipositive;
Schur = V22-V21*V11inv*V12;
negativeSchur = -0.5*(Schur+Schur');

[A,sqrtInfoV11] = sqrt_pi_block(V11,tol,samplePoints);
[B,sqrtInfoSchur] = sqrt_pi_block(negativeSchur,tol,samplePoints);

Theta11 = A;
Theta12 = A*V11inv*V12;
Theta21 = zerosPI(negativeDim,positiveDim,V.vars,V.I);
Theta22 = B;

Theta.operator = [Theta11,Theta12;
                  Theta21,Theta22];
% Feedthrough-only realization for PIETOOLS_IQC_graph.
stateDim = zeros(size(positiveDim));
Theta.T = zerosPI(stateDim,stateDim,V.vars,V.I);
Theta.A = zerosPI(stateDim,stateDim,V.vars,V.I);
Theta.B1 = zerosPI(stateDim,positiveDim,V.vars,V.I);
Theta.B2 = zerosPI(stateDim,negativeDim,V.vars,V.I);
Theta.C1 = zerosPI(positiveDim,stateDim,V.vars,V.I);
Theta.C2 = zerosPI(negativeDim,stateDim,V.vars,V.I);
Theta.D11 = Theta11;
Theta.D12 = Theta12;
Theta.D21 = Theta21;
Theta.D22 = Theta22;

factorResidual = Theta.operator'*J*Theta.operator-V;

info.positiveDim = positiveDim;
info.negativeDim = negativeDim;
info.schurComplement = Schur;
info.negativeSchurComplement = negativeSchur;
info.V11Inverse = V11inv;
info.inverseResidual = inverseResidual;
info.maxSampledInverseError = sample_opvar_error(inverseResidual,samplePoints);
info.sqrtV11 = sqrtInfoV11;
info.sqrtNegativeSchur = sqrtInfoSchur;
info.factorResidual = factorResidual;
info.maxSampledFactorError = sample_opvar_error(factorResidual,samplePoints);
info.adjointError = adjointError;

fprintf('Static J-factorization sampled residual: %.3e\n', ...
    info.maxSampledFactorError);
end

function [X,info] = sqrt_pi_block(P,tol,pts)
% Apply Newton to the complete operator block, including all channel and
% finite/distributed couplings. A diagonal congruence balances the channel
% magnitudes without changing the factorization identity.
[D,Di,sc] = balance_op(P,pts);
Pb = D'*P*D;
[Xb,info] = sqrt_newton(Pb,tol,pts);
X = Xb*Di;
info.balance = sc;
info.residual = X'*X-P;
info.maxSampledError = sample_opvar_error(info.residual,pts);
info.reachedTolerance = info.maxSampledError<=tol;
fprintf('Balanced whole-block factor residual: %.3e\n', ...
    info.maxSampledError);
end

function [D,Di,sc] = balance_op(P,pts)
n0 = P.dim(1,1);
n = sum(P.dim(:,1));
mag = zeros(1,n);
for i = 1:n
    mag(i) = max(sample_opvar_error(P(i,i),pts),1e-12);
end
sc = 1./sqrt(mag);
D = eyePI(P.dim(:,1),P.vars,P.I);
Di = eyePI(P.dim(:,1),P.vars,P.I);
if n0>0
    D.P = diag(sc(1:n0));
    Di.P = diag(1./sc(1:n0));
end
if n0<n
    D.R.R0 = diag(sc(n0+1:n));
    Di.R.R0 = diag(1./sc(n0+1:n));
end
end

function [X,info] = sqrt_newton(P,tol,pts)
I = eyePI(P.dim(:,1),P.vars,P.I);
scale = max(1,sample_opvar_error(P,pts));
Pn = (1/scale)*P;
Y = 0.5*(I+Pn);
best = Y;
bestErr = scale*sample_opvar_error(Y*Y-Pn,pts);
stall = 0;

iopts.N = 60;
iopts.mulDeg = 6;
iopts.kerDeg = [6,6];
maxIter = 8;
history = nan(1,maxIter);
history(1) = bestErr;
fprintf('Newton PI square-root residual 1: %.3e\n',bestErr);
for k = 2:maxIter
    Yinv = invert_op(Y,iopts,pts);
    Ynew = 0.5*(Y+Pn*Yinv);
    Ynew = 0.5*(Ynew+Ynew');
    err = scale*sample_opvar_error(Ynew*Ynew-Pn,pts);
    history(k) = err;
    fprintf('Newton PI square-root residual %d: %.3e\n',k,err);
    if err < bestErr
        best = Ynew;
        bestErr = err;
        stall = 0;
    else
        stall = stall+1;
    end
    Y = Ynew;
    if bestErr <= min(tol,1e-10) || stall>=2
        break
    end
end
X = sqrt(scale)*best;
info.method = 'newton';
info.iterations = k;
info.history = history(1:k);
info.scale = scale;
info.residual = X*X-P;
info.maxSampledError = bestErr;
info.reachedTolerance = bestErr<=tol;
fprintf('Newton PI square-root best residual: %.3e\n',bestErr);
end

function Xinv = invert_op(X,opts,pts)
scale = max(1,sample_opvar_error(X,pts));
sepErr = max_abs_2d(X.R.R1-X.R.R2,X.var1,X.var2,pts);
if sepErr<=1e-10*scale
    Xinv = inv_opvar_old(X);
else
    Xinv = inv_opvar_2(X,opts);
end
end

function validate_multiplier_type(V)
if ~(isa(V,'opvar') || isa(V,'dopvar'))
    error('V must be an opvar or dopvar.');
end
if isa(V,'dopvar')
    error(['V is an unresolved dopvar. Evaluate it first using ', ...
           'Vsol = lpigetsol(prog,V), then factor Vsol.']);
end
if any(V.dim(:,1) ~= V.dim(:,2))
    error('V must be a square PI operator.');
end
end

function [V11,V12,V21,V22,positiveDim,negativeDim] = ...
        split_multiplier(V,positiveDim)
totalDim = V.dim(:,1);
positiveDim = positiveDim(:);
if numel(positiveDim) ~= 2 || any(~isfinite(positiveDim)) || ...
        any(positiveDim < 0) || any(positiveDim ~= floor(positiveDim))
    error(['positiveDim must be a nonnegative integer ', ...
           '[finite;distributed] vector.']);
end
negativeDim = totalDim-positiveDim;
if any(negativeDim < 0) || any(negativeDim ~= floor(negativeDim))
    error('positiveDim is incompatible with V.dim.');
end
if sum(positiveDim)==0 || sum(negativeDim)==0
    error('V must contain at least one positive and one negative channel.');
end

% opvar linear indexing orders all finite channels before all distributed
% channels. Select the positive and negative groups within each component.
nFinite = totalDim(1);
positiveIdx = [1:positiveDim(1), ...
               nFinite+(1:positiveDim(2))];
negativeIdx = [positiveDim(1)+(1:negativeDim(1)), ...
               nFinite+positiveDim(2)+(1:negativeDim(2))];

V11 = V(positiveIdx,positiveIdx);
V12 = V(positiveIdx,negativeIdx);
V21 = V(negativeIdx,positiveIdx);
V22 = V(negativeIdx,negativeIdx);
end

function err = sample_opvar_error(P,samplePoints)
values = [max_abs_numeric(P.P), ...
          max_abs_1d(P.Q1,P.var1,samplePoints), ...
          max_abs_1d(P.Q2,P.var1,samplePoints), ...
          max_abs_1d(P.R.R0,P.var1,samplePoints), ...
          max_abs_2d(P.R.R1,P.var1,P.var2,samplePoints), ...
          max_abs_2d(P.R.R2,P.var1,P.var2,samplePoints)];
err = max(values);
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
