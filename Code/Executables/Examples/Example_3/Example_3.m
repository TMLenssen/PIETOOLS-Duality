clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Sine-feedback damped wave equation
%
% The primal analysis uses the original LFR
%
%   q_tt = q_ss - damping*q_t + lambda*wd,      zd = q,
%   wd   = sin(zd).
%
% The dual analysis uses the equivalent transformed LFR
%
%   q_tt = q_ss - damping*q_t + lambda*J*wd,    zd = q_s,
%   wd   = cos(J*zd).*zd,
%
% where (Jf)(s)=int_0^s f(theta)dtheta. Since q(0,t)=0, both LFRs
% produce the same sine-feedback closed loop.
% Moreover, zd*wd=cos(J*zd)*zd^2, so -zd^2<=zd*wd<=zd^2. Equivalently,
% (zd-wd)*(wd+zd)=sin(J*zd)^2*zd^2>=0; hence tildeDelta lies in
% the sector [-1,1].
pvar t s
a = 0;
b = 1;
damping = 2;

alpha = -1;
beta = 1;
analysisMode = 'dual';     % 'primal' or 'dual'
kypSlackMode = 'signed';   % 'normal' or 'signed'

% Search for the largest certified lambda.
lambdaLower = 0;
lambdaUpper = 5;
lambdaTolerance = 1e-2;
residualFactor = 1.1;

% Simulate the last feasible lambda after the bisection.
runSimulation = true;
plotSimulation = true;
simulationGridPoints = 101;
simulationFinalTime = 500;
nonlinearity = @(q) sin(q);

settings = lpisettings('veryheavy');
settings.sos_opts.solver = 'mosek';
settings.ddM = 4;
settings.multiplierUpper = 1e4;
settings.inverseFloor = 1e-8;
settings.kypMarginUpper = 100;
settings.kypSlackMode = kypSlackMode;
settings.options1.sep = 0;
settings.options12.sep = 0;

%% Bisection over lambda
bestTest = struct([]);
while lambdaUpper-lambdaLower > lambdaTolerance
    lambdaTrial = 0.5*(lambdaLower+lambdaUpper);
    trial = test_lambda(lambdaTrial,a,b,damping,alpha,beta,settings,t,s, ...
        analysisMode,residualFactor);
    fprintf(['lambda=%8.5f, feasible=%d | %s: eps=% .3e, ' ...
        'res=%.2e, FR=%.3f, numerr=%g\n'],lambdaTrial,trial.feasible, ...
        analysisMode,trial.eps,trial.residual, ...
        trial.feasratio,trial.numerr);

    if trial.feasible
        lambdaLower = lambdaTrial;
        bestTest = trial;
    else
        lambdaUpper = lambdaTrial;
    end
end

fprintf('\nCertified bisection interval: [%.6g, %.6g]\n', lambdaLower,lambdaUpper);
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

%% Simulate the final certified value
if runSimulation && ~isempty(bestTest)
    sim = simulate_wave(lambdaLower,damping,nonlinearity, ...
        simulationGridPoints,simulationFinalTime);
    fprintf('\nSimulation at lambda = %.6g with phi(q)=%s\n', ...
        lambdaLower,func2str(nonlinearity));
    fprintf('Initial state L2 norm: %.6g\n',sim.stateL2(1));
    fprintf('Final state L2 norm:   %.6g\n',sim.stateL2(end));
    fprintf('Final/initial ratio:   %.6g\n', ...
        sim.stateL2(end)/sim.stateL2(1));

    if plotSimulation
        plot_wave_simulation(sim);
    end
elseif runSimulation
    warning('No feasible lambda was found, so the simulation was skipped.');
end

function result = test_lambda(lambda,a,b,damping,alpha,beta,settings,t,s, ...
        analysisMode,residualFactor)
q = pde_var(s,[a,b]);
v = pde_var(s,[a,b]);
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);

switch lower(analysisMode)
    case 'primal'
        PDE = [diff(q,t) == v;
               diff(v,t) == diff(q,s,2) - damping*v + lambda*wd;
               zd == q;
               subs(q,s,a) == 0;
               subs(v,s,a) == 0;
               subs(diff(q,s),s,b) == 0];
        P = convert(PDE);
    case 'dual'
        PDE = [diff(q,t) == v;
               diff(v,t) == diff(q,s,2) - damping*v + wd;
               zd == diff(q,s);
               subs(q,s,a) == 0;
               subs(v,s,a) == 0;
               subs(diff(q,s),s,b) == 0];
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

function sim = simulate_wave(lambda,damping,nonlinearity,N,tFinal)
% Method of lines for q(0,t)=0 and q_s(1,t)=0.
s = linspace(0,1,N).';
ds = s(2)-s(1);
n = N-1;
e = ones(n,1);
Dss = spdiags([e,-2*e,e],-1:1,n,n)/ds^2;
Dss(end,end-1) = 2/ds^2;
Dss(end,end) = -2/ds^2;

q0 = 0.25*sin(0.5*pi*s(2:end));
v0 = zeros(n,1);
y0 = [q0;v0];
tRequested = linspace(0,tFinal,501).';

jacobianPattern = [sparse(n,n),speye(n); ...
                   spones(Dss)+speye(n),speye(n)];
odeOptions = odeset('RelTol',1e-7,'AbsTol',1e-9, ...
                    'JPattern',jacobianPattern);
rhs = @(~,y) wave_rhs(y,Dss,lambda,damping,nonlinearity);
[t,y] = ode15s(rhs,tRequested,y0,odeOptions);

q = zeros(numel(t),N);
v = zeros(numel(t),N);
q(:,2:end) = y(:,1:n);
v(:,2:end) = y(:,n+1:end);
qL2 = sqrt(trapz(s.',q.^2,2));
vL2 = sqrt(trapz(s.',v.^2,2));

sim.lambda = lambda;
sim.s = s;
sim.t = t;
sim.q = q;
sim.v = v;
sim.qL2 = qL2;
sim.vL2 = vL2;
sim.stateL2 = hypot(qL2,vL2);
end

function dy = wave_rhs(y,Dss,lambda,damping,nonlinearity)
n = size(Dss,1);
q = y(1:n);
v = y(n+1:end);
dy = [v; Dss*q-damping*v+lambda*nonlinearity(q)];
end

function fig = plot_wave_simulation(sim)
% This function is not called when plotSimulation=false.
fig = figure('Color','w');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile;
surf(sim.s,sim.t,sim.q,'EdgeColor','none');
xlabel('s'); ylabel('t'); zlabel('q(s,t)');
title(sprintf('Wave simulation, \\lambda = %.4g',sim.lambda));
view(3); axis tight;

nexttile;
semilogy(sim.t,sim.stateL2,'LineWidth',1.5);
xlabel('t'); ylabel('State L_2 norm');
title('Decay of the simulated state');
grid on;
end
