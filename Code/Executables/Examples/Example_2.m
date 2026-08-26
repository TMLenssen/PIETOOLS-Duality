clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
codeRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(codeRoot));

%% Plant
pvar t s
a = 0;
b = 1;
d = 1;
sigma = 3;
damp = 0.2;
% Graph sector for wd = v1-sin(v1): (wd-alpha*v1)'*(beta*v1-wd) >= 0.
alpha = 0;
beta = 1.217234;
x = pde_var('state',1,[],[]);
v1 = pde_var(s,[a,b]);
v2 = pde_var(s,[a,b]);
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
z1 = pde_var('output',1);
z2 = pde_var('output',1);
w = pde_var('input',1);
u = pde_var('control',1);
PDE = [diff(v1,t) == v2;    % PDE
    diff(v2,t) == d*diff(v1,s,2) + sigma*v1 - damp*v2 - sigma*wd + w;
    diff(x,t) == u;
    zd == v1;
    z1 == x;
    z2 == int(v1,s,[a,b]);
    subs(v1,s,a) == 0;
    subs(v2,s,a) == 0;
    subs(diff(v1,s),s,b)==x];
display_PDE(PDE);
P = convert(PDE);

wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);

% Identity filters only establish the primal [z;w] and dual [w;z]
% channel order. They have no states.
Psi = id_filter(zDim,wDim,P.vars,P.dom);
DPsi = id_filter(wDim,zDim,P.vars,P.dom);

settings = lpisettings('veryheavy');
dd = 4;
settings.ddZ = 2;
settings.dd1 = 2;
% settings.dd2 = dd;
% settings.dd3 = dd;
settings.dd12 = 2;
settings.ddM = 4;
settings.epneg = 1e-8;
settings.eppn = 0;
settings.kmax = 10000;

%% Dual synthesis with a sector-bounded multiplier
progS = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progS,Vd,rhoD,~] = sector_iqc(progS,wDim,zDim,alpha,beta,settings,P.vars,P.dom,'rhoD');
settings.options1.sep = 1;
settings.options12.sep = 1;
[K,Zdec,Pdec,progS] = PIETOOLS_IQC_controller_synthesis(progS,settings,P,DPsi,Vd);

[sFR,sPinf,sDinf,sNumerr] = solve_info(progS);
rhoDValue = double(lpigetsol(progS,rhoD));

analysisSettings = lpisettings('veryheavy');
analysisSettings.ddM = 4;
analysisSettings.epneg = 1e-8;
analysisSettings.eppn = 0;
%% Identity-filtered primal and dual closed-loop graphs

GP = PIETOOLS_IQC_primal_graph(P,Psi,K);
GD = PIETOOLS_IQC_dual_graph(P,DPsi,K);

%% Primal analysis with an independent sector multiplier
progP = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progP,Vp,rhoP,~] = sector_iqc(progP,zDim,wDim,alpha,beta,analysisSettings,P.vars,P.dom,'rhoP');
[~,progP] = PIETOOLS_IQC_analysis(progP,analysisSettings,GP,Vp);
[pFR,pPinf,pDinf,pNumerr] = solve_info(progP);
rhoPValue = double(lpigetsol(progP,rhoP));

%% Dual analysis with an independent sector multiplier
progD = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progD,Va,rhoA,~] = sector_iqc(progD,wDim,zDim,alpha,beta,analysisSettings,P.vars,P.dom,'rhoA');
[~,progD] = PIETOOLS_IQC_analysis(progD,analysisSettings,GD,Va);
[dFR,dPinf,dDinf,dNumerr] = solve_info(progD);
rhoAValue = double(lpigetsol(progD,rhoA));

fprintf('\nSynthesis feasibility ratio: %.10g\n',sFR);
fprintf('Synthesis status:             pinf=%g, dinf=%g, numerr=%g\n',sPinf,sDinf,sNumerr);
fprintf('Dual synthesis gain:          %.10e\n',sqrt(rhoDValue));

fprintf('\nPrimal analysis feasibility ratio: %.10g\n',pFR);
fprintf('Primal analysis status:           pinf=%g, dinf=%g, numerr=%g\n',pPinf,pDinf,pNumerr);
fprintf('Dual analysis feasibility ratio:   %.10g\n',dFR);
fprintf('Dual analysis status:             pinf=%g, dinf=%g, numerr=%g\n',dPinf,dDinf,dNumerr);
fprintf('Primal analysis gain:               %.10e\n',sqrt(rhoPValue));
fprintf('Dual analysis gain:                 %.10e\n',sqrt(rhoAValue));

%% Nonlinear closed-loop simulation

Nsim = 16;
Tsim = 120;
amp = 0.12;

splot = linspace(0,1,200).';
boundaryState0 = 0;
z0 = @(s) amp*sin(pi*s/2); %0.12*sin(0.5*pi*s);
zt0 = @(s) zeros(size(s));
wp = @(t) cos(t)*(heaviside(t-1) - heaviside(t-10)) ;
wd = @(z) z-sin(z);

tgrid = linspace(0,Tsim,3000);
x0.ode = boundaryState0;
x0.pde = {zt0,z0};

simOpts.N = Nsim;
simOpts.splot = splot;
simOpts.statePIE = P;
simOpts.nwd0 = 0;
simOpts.wp = wp;
simOpts.ode = odeset('RelTol',1e-6,'AbsTol',1e-8);

simOL = PIE_sim_nl(P,wd,tgrid,x0,simOpts);
simCL = PIE_sim_nl(closedLoopPIE(P,K),wd,tgrid,x0,simOpts);

tsim = simOL.t;
zsimOL = simOL.zPlot;
zsimCL = simCL.zPlot;
z1OL = simOL.z1;
z1CL = simCL.z1;
z2OL = simOL.z2;
z2CL = simCL.z2;



zL2 = sqrt(trapz(tsim,z1CL.^2+z2CL.^2));
wL2 = sqrt(trapz(tsim,sum(simOL.wp.^2,2)));
fprintf('Simulated Induced L2 norm  ||zp||_L2/||wp||_L2:              %.10e\n',zL2/wL2);

figure('Name','Example 2 nonlinear simulation','Color','w');
subplot(2,2,1);
surf(splot,tsim,zsimOL,'EdgeColor','none');
view(2);
axis tight;
shading interp;
colorbar;
xlabel('s');
ylabel('t');
title('Uncontrolled nonlinear state');

subplot(2,2,2);
surf(splot,tsim,zsimCL,'EdgeColor','none');
view(2);
axis tight;
shading interp;
colorbar;
xlabel('s');
ylabel('t');
title('Controlled nonlinear state');

subplot(2,2,[3 4]);
plot(tsim,max(abs(zsimOL),[],2),'LineWidth',1.4); hold on;
plot(tsim,max(abs(zsimCL),[],2),'LineWidth',1.4);
grid on;
xlabel('t');
ylabel('max_s |z(s,t)|');
legend('Uncontrolled','Controlled','Location','best');
title('Amplitude comparison');

figure('Name','Example 2 finite outputs','Color','w');
subplot(2,1,1);
plot(tsim,z1OL,'LineWidth',1.4); hold on;
plot(tsim,z1CL,'LineWidth',1.4);
grid on;
xlabel('t');
ylabel('z_1');
legend('Uncontrolled','Controlled','Location','best');

subplot(2,1,2);
plot(tsim,z2OL,'LineWidth',1.4); hold on;
plot(tsim,z2CL,'LineWidth',1.4);
grid on;
xlabel('t');
ylabel('z_2');
legend('Uncontrolled','Controlled','Location','best');


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

function [prog,V,rho,M] = sector_iqc(prog,dp,dn,alpha,beta,set,vars,dom,name)
if ~isfinite(alpha) || ~isfinite(beta) || alpha>=beta
    error('Sector bounds must satisfy alpha < beta.');
end
if dp(2)~=1 || dn(2)~=1
    error('sector_iqc is only written for one distributed uncertainty channel.');
end
[prog,rho] = lpidecvar(prog,name);
prog = lpi_ineq(prog,rho);
prog = lpisetobj(prog,rho);

d = dp+dn;
V = opvar2dopvar(zerosPI(d,d,vars,dom));
V.P = blkdiag(eye(dp(1)),-rho*eye(dn(1)));

op = set.options1;
op.sep = 0;
[prog,M] = poslpivar(prog,[0;1],set.ddM,op);
M = M+set.eppn*eyePI([0;1],vars,dom);

Z = zerosPI([0;1],[0;1],vars,dom);
T = mat2opvar([beta, -1; -alpha, 1],[0,0;2,2],vars,dom);
Vdist = [Z, M'; M, Z];
Vdist = T'*Vdist*T;
V.R = Vdist.R;
end

function [ratio,pinf,dinf,numerr] = solve_info(prog)
info = prog.solinfo.info;
ratio = double(info.feasratio);
pinf = double(info.pinf);
dinf = double(info.dinf);
numerr = double(info.numerr);
end

