clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
codeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(codeRoot));

%% Plant
pvar t s
a = 0;
b = 1;
x1 = pde_var(1,s,[a,b]);
x3 = pde_var(1,s,[a,b]);
x2 = pde_var('state');
zd1 = pde_var('output',1,s,[a,b]);
zd2 = pde_var('output',1,s,[a,b]);
wd1 = pde_var('input',1,s,[a,b]);
wd2 = pde_var('input',1,s,[a,b]);
z1 = pde_var('out');
w = pde_var('in');
z2 = pde_var('out');
y = pde_var('sense');
u = pde_var('control');

lam = 5;
dev = 0.5;
PDE = [diff(x1,t) == diff(x1,s,2)+lam*x1+s*(1-s)*w+dev*wd2;
       diff(x2,t) == u;
       zd2 == x1;
       z1 == x2;
       z2 == int(x1,s,[a,b]);
       subs(x1,s,a) == 0;
       subs(diff(x1,s,1),s,b) == x2];

display_PDE(PDE);
P = convert(PDE);

wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);

% Identity filters only establish the primal [z;w] and dual [w;z]
% channel order. They have no states.
Psi = id_filter(zDim,wDim,P.vars,P.dom);
DPsi = id_filter(wDim,zDim,P.vars,P.dom);

settings = lpisettings('veryheavy');
settings.ddZ = 2;
settings.dd1 = 2;
% settings.dd2 = 4;
% settings.dd3 = 4;
settings.dd12 = 2;
settings.ddM = 8;
settings.epneg = 1e-8;
settings.eppn = 0;
settings.kmax = 10000;

%% Dual synthesis with an independent PN multiplier
progS = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progS,Vd,rhoD] = iqcvar(progS,wDim,zDim,settings,P.vars,P.dom,'rhoD');
settings.options1.sep = 1;
settings.options12.sep = 1;
[K,Zs,Ps,progS] = PIETOOLS_IQC_controller_synthesis(progS,settings,P,DPsi,Vd);

sFR = feasratio(progS);
rhoD = double(lpigetsol(progS,rhoD));
Vd = lpigetsol(progS,Vd);

analysisSettings = settings;
analysisSettings.options1.sep = 0;
analysisSettings.options12.sep = 0;


%% Identity-filtered primal and dual closed-loop graphs

GP = PIETOOLS_IQC_primal_graph(P,Psi,K);
GD = PIETOOLS_IQC_dual_graph(P,DPsi,K);


%% Primal analysis with a new PN multiplier
progP = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progP,Vp,rhoP] = iqcvar(progP,zDim,wDim,analysisSettings,P.vars,P.dom,'rhoP');
[Pp,progP] = PIETOOLS_IQC_analysis(progP,analysisSettings,GP,Vp);

pFR = feasratio(progP);
rhoP = double(lpigetsol(progP,rhoP));
Vp = lpigetsol(progP,Vp);
%% Dual analysis with another new PN multiplier
progD = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progD,Va,rhoA] = iqcvar(progD,wDim,zDim,analysisSettings,P.vars,P.dom,'rhoA');
[Pd,progD] = PIETOOLS_IQC_analysis(progD,analysisSettings,GD,Va);

dFR = feasratio(progD);
rhoA = double(lpigetsol(progD,rhoA));
Va = lpigetsol(progD,Va);

fprintf('\nSynthesis feasibility ratio: %.10g\n',sFR);
fprintf('Dual synthesis gain:          %.10e\n',sqrt(rhoD));
fprintf('Certified controller bound:    %.10e\n',settings.kmax);
fprintf('\nPrimal analysis feasibility ratio: %.10g\n',pFR);
fprintf('Dual analysis feasibility ratio:   %.10g\n',dFR);
fprintf('Primal analysis gain:               %.10e\n',sqrt(rhoP));
fprintf('Dual analysis gain:                 %.10e\n',sqrt(rhoA));
warn_if_infeasible(sFR,'synthesis');
warn_if_infeasible(pFR,'primal analysis');
warn_if_infeasible(dFR,'dual analysis');

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

function [prog,V,rho] = iqcvar(prog,dp,dn,set,vars,dom,name)
% Structured scalar-channel IQC multiplier used for synthesis.
if dp(2)~=dn(2)
    error('The scalar distributed positive/negative channel counts must match.');
end
[prog,rho] = lpidecvar(prog,name);
prog = lpi_ineq(prog,rho);
prog = lpisetobj(prog,rho);

n = dp(2);
Qb = cell(1,n);
Sb = cell(1,n);
op = set.options1;
op.sep = 0;
for k = 1:n
    [prog,Qb{k}] = poslpivar(prog,[0,0;1,1],set.ddM,op);
    [prog,Sb{k}] = lpivar(prog,[0,0;1,1],set.ddM,op);
end
Q = blkdiag(Qb{:});
S = blkdiag(Sb{:});
I = eyePI([0;n],vars,dom);
R = [Q+set.eppn*I, S-S';
     S'-S, -Q-set.eppn*I];

d = dp+dn;
V = opvar2dopvar(zerosPI(d,d,vars,dom));
V.P = blkdiag(eye(dp(1)),-rho*eye(dn(1)));
V.R = R.R;
end


function ratio = feasratio(prog)
try
    ratio = double(prog.solinfo.info.feasratio);
catch
    ratio = NaN;
end
if ~isscalar(ratio) || ~isreal(ratio)
    ratio = NaN;
end
end

function warn_if_infeasible(ratio,label)
if ~isfinite(ratio) || ratio<=0
    warning('Example_1:PoorFeasibility', ...
        '%s has poor feasibility ratio %.6g.',label,ratio);
end
end

