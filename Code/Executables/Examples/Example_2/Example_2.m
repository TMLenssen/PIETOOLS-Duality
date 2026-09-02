clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Example 4: sine-feedback diffusion equation
%
% The primal analysis uses the original LFR
%
%   x_t = x_ss + lambda*wd,         zd = x,      wd = sin(zd).
%
% The dual analysis uses the equivalent transformed LFR
%
%   x_t = x_ss + lambda*J*wd,       zd = x_s,
%   wd  = cos(J*zd).*zd,
%
% where (Jf)(s)=int_0^s f(theta)dtheta. Since x(0,t)=0, both LFRs
% produce the same closed loop x_t=x_ss+lambda*sin(x).
% Moreover, zd*wd=cos(J*zd)*zd^2, so -zd^2<=zd*wd<=zd^2. Equivalently,
% (zd-wd)*(wd+zd)=sin(J*zd)^2*zd^2>=0; hence tildeDelta lies in
% the sector [-1,1].
pvar t s
a = 0;
b = 1;
alpha = -1;
beta = 1;
analysisMode = 'dual';       % 'primal' or 'dual'
kypSlackMode = 'signed';     % 'normal' or 'signed'

% Search for the largest certified lambda.
lambdaLower = 0;
lambdaUpper = 5;
lambdaTolerance = 1e-2;
residualFactor = 1.1;


settings = lpisettings('veryheavy');
% dd = 10;
% settings.dd1 = dd;
% settings.dd12 = dd;
% settings.dd2 = dd;
% settings.dd3 = dd;
settings.sos_opts.solver = 'mosek';
settings.ddM = 2;
settings.multiplierUpper = 1e4;
settings.inverseFloor = 1e-8;
settings.kypMarginUpper = 100;
settings.kypSlackMode = kypSlackMode;
settings.options1.sep = 0;
settings.options12.sep = 0;



%% Then bisect over lambda
bestTest = struct([]);
while lambdaUpper-lambdaLower > lambdaTolerance
    lambdaTrial = 0.5*(lambdaLower+lambdaUpper);
    trial = test_lambda(lambdaTrial,a,b,alpha,beta,settings,t,s, ...
        analysisMode,residualFactor);
    fprintf(['lambda=%8.5f, feasible=%d | %s: eps=% .3e, ' ...
        'res=%.2e, FR=%.3f, numerr=%g\n'],lambdaTrial,trial.feasible, ...
        analysisMode, ...
        trial.eps,trial.residual,trial.feasratio,trial.numerr);

    if trial.feasible
        lambdaLower = lambdaTrial;
        bestTest = trial;
    else
        lambdaUpper = lambdaTrial;
    end
end

fprintf('\nCertified bisection interval: [%.6g, %.6g]\n', ...
    lambdaLower,lambdaUpper);
fprintf('Linear worst-case limit:      (pi/2)^2 = %.6g\n',(pi/2)^2);
if ~isempty(bestTest)
    if strcmpi(kypSlackMode,'signed')
        fprintf('Last %s eps:                %.6g\n', ...
            analysisMode,bestTest.eps);
    else
        fprintf('Last %s normal-mode residual: %.3e\n', ...
            analysisMode,bestTest.residual);
    end
end

function result = test_lambda(lambda,a,b,alpha,beta,settings,t,s, ...
        analysisMode,residualFactor)
x = pde_var(s,[a,b]);
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);

switch lower(analysisMode)
    case 'primal'
        PDE = [diff(x,t) == diff(x,s,2) + lambda*wd;
               zd == x;
               subs(x,s,a) == 0;
               subs(diff(x,s),s,b) == 0];
        P = convert(PDE);
    case 'dual'
        PDE = [diff(x,t) == diff(x,s,2) + wd;
               zd == diff(x,s);
               subs(x,s,a) == 0;
               subs(diff(x,s),s,b) == 0];
        P = convert(PDE);

        % Replace the pointwise input by lambda*J.
        inputDirection = P.B1.R.R0;
        P.B1.R.R0 = 0*inputDirection;
        P.B1.R.R1 = lambda*inputDirection;
        P.B1.R.R2 = 0*inputDirection;
    otherwise
        error('analysisMode must be ''primal'' or ''dual''.');
end

wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);
prog = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);

switch lower(analysisMode)
    case 'primal'
        Psi = id_filter(zDim,wDim,P.vars,P.dom);
        G = PIETOOLS_IQC_primal_graph(P,Psi);
        [prog,V] = PIETOOLS_IQC_sector(prog,zDim,wDim, ...
            alpha,beta,settings,P.vars,P.dom);
    case 'dual'
        DPsi = id_filter(wDim,zDim,P.vars,P.dom);
        G = PIETOOLS_IQC_dual_graph(P,DPsi);
        [prog,V] = PIETOOLS_IQC_sector(prog,wDim,zDim, ...
            alpha,beta,settings,P.vars,P.dom);
end

[~,prog,kyp] = PIETOOLS_IQC_analysis(prog,settings,G,V);
result = certificate(prog,kyp,residualFactor,settings.kypSlackMode);
end

function cert = certificate(prog,epsDecision,residualFactor,kypSlackMode)
info = prog.solinfo.info;
cert.feasratio = double(info.feasratio);
cert.pinf = double(info.pinf);
cert.dinf = double(info.dinf);
cert.numerr = double(info.numerr);
cert.residual = double(prog.solinfo.residual);

if strcmpi(kypSlackMode,'signed')
    cert.eps = double(lpigetsol(prog,epsDecision));
    cert.marginRatio = cert.eps/max(cert.residual,eps);
    cert.feasible = cert.eps > residualFactor*cert.residual;
else
    cert.eps = NaN;
    cert.marginRatio = NaN;
    cert.feasible = cert.pinf==0 && cert.dinf==0 && cert.numerr<=1 ...
    && isfinite(cert.feasratio) && abs(cert.feasratio-1)<=0.3 ...
    && isfinite(cert.residual);
end
end

function F = id_filter(d1,d2,vars,dom)
d0 = zeros(size(d1));
F.T = zerosPI(d0,d0,vars,dom);
F.A = zerosPI(d0,d0,vars,dom);
F.B1 = zerosPI(d0,d1,vars,dom);
F.B2 = zerosPI(d0,d2,vars,dom);
F.C1 = zerosPI(d1,d0,vars,dom);
F.C2 = zerosPI(d2,d0,vars,dom);
F.D11 = eyePI(d1,vars,dom);
F.D12 = zerosPI(d1,d2,vars,dom);
F.D21 = zerosPI(d2,d1,vars,dom);
F.D22 = eyePI(d2,vars,dom);
end
