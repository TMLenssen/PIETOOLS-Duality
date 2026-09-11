clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Plant
pvar t s
a = 0;
b = 1;
x1 = pde_var(1,s,[a,b]);
x3 = pde_var(1,s,[a,b]);
x2 = pde_var('state');
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
z1 = pde_var('out');
w = pde_var('in');
z2 = pde_var('out');
y = pde_var('sense');
u = pde_var('control');

lam = 1;
dev = 0.8;
PDE = [diff(x1,t) == diff(x1,s,2)+lam*x1+dev*wd+s*(s-1)*w;
       % diff(x2,t) == u;
       zd == x1;%diff(x1,s,2);
       % z1 == x2;
       z2 == int(x1,s,[a,b]);
       subs(x1,s,a) == 0;
       subs(diff(x1,s,1),s,b) == 0];


display_PDE(PDE);
P = convert(PDE);

wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);

% Identity filters only establish the primal [z;w] and dual [w;z]
% channel order. They have no states.
Psi = id_filter(zDim,wDim,P.vars,P.dom);
DPsi = id_filter(wDim,zDim,P.vars,P.dom);

settings = lpisettings('veryheavy');
settings.sos_opts.solver = 'mosek';
settings.ddM = 2;
settings.multiplierUpper = 1e4;
settings.inverseFloor = 1e-8;
settings.kypSlackMode = 'normal';
settings.controllerCleanTol = 1e-10;
settings.options1.sep = 0;
settings.options12.sep = 0;
pnEps = settings.eppn;


%% Identity-filtered primal and dual closed-loop graphs

GP = PIETOOLS_IQC_primal_graph(P,Psi);
GD = PIETOOLS_IQC_dual_graph(P,DPsi);




%% Primal analysis with a new PN multiplier
progP = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progP,rhoP] = lpidecvar(progP,'rhoP');
progP = lpi_ineq(progP,rhoP);
[progP,Vp] = PIETOOLS_IQC_parametric( ...
    progP,zDim,wDim,settings,P.vars,P.dom);
Vp.P = blkdiag(eye(zDim(1)),-rhoP*eye(wDim(1)));
progP = lpisetobj(progP,rhoP);
[Pp,progP] = PIETOOLS_IQC_analysis(progP,settings,GP,Vp);

pFR = feasratio(progP);
rhoP = double(lpigetsol(progP,rhoP));
Vp = lpigetsol(progP,Vp);

%% Dual analysis with another new PN multiplier
progD = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progD,rhoA] = lpidecvar(progD,'rhoA');
progD = lpi_ineq(progD,rhoA);
[progD,Va] = PIETOOLS_IQC_parametric( ...
    progD,wDim,zDim,settings,P.vars,P.dom);
Va.P = blkdiag(eye(wDim(1)),-rhoA*eye(zDim(1)));
progD = lpisetobj(progD,rhoA);
[Pd,progD] = PIETOOLS_IQC_analysis(progD,settings,GD,Va);

dFR = feasratio(progD);
rhoA = double(lpigetsol(progD,rhoA));
Va = lpigetsol(progD,Va);

fprintf('\nPrimal analysis feasibility ratio: %.10g\n',pFR);
fprintf('Dual analysis feasibility ratio:   %.10g\n',dFR);
fprintf('Primal analysis gain:               %.10e\n',sqrt(rhoP));
fprintf('Dual analysis gain:                 %.10e\n',sqrt(rhoA));
check_feasible(pFR,'primal analysis');
check_feasible(dFR,'dual analysis');

Certificates = struct( ...
    'GP',GP,'Vp',Vp,'Pp',Pp,'progP',progP,'pFR',pFR,'rhoP',rhoP, ...
    'GD',GD,'Va',Va,'Pd',Pd,'progD',progD,'dFR',dFR,'rhoA',rhoA, ...
    'pnEps',pnEps,'dev',dev);

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

function check_feasible(ratio,label)
if ~isfinite(ratio) || ratio<=0
    error('Example_1:Infeasible', ...
        '%s is infeasible (feasibility ratio %.6g).',label,ratio);
end
end
