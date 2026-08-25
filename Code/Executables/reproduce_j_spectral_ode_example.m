%% Reproduce the ODE example from j_spectral_factorization.m with PIETOOLS
% jfactor is the only Control System Toolbox boundary. Its finite-dimensional
% factor realizations are converted immediately to PI operators. Every graph,
% LPI, H-infinity calculation, and nonlinear interconnection after that point
% is assembled with PI operators.

clearvars; close all; clc; echo off;

pietoolsRoot = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
mosekRoot = 'C:\Program Files\Mosek\11.0\toolbox\r2019b';
addpath(genpath(pietoolsRoot));
addpath(fileparts(mfilename('fullpath')),'-begin');
if isfolder(mosekRoot)
    addpath(genpath(mosekRoot));
end

settings = lpisettings('light');
settings.eppos = 1e-3;  % Match PD,PP >= 1e-3*I in the original example.

%% IQC and primal/dual J-spectral factors
s = tf('s');
beta = 1.217234;
hatbeta = 2;
epsIQC = 1e-2;

L = blkdiag(1/(s+1),1);
M = 1 - 1/(s+1);
Pid = diag([1,-1/beta^2]);

Pi1 = L'*[0 beta; beta -2]*L;
Pi2 = L'*[0 -s; s 0]*L;
Pi3 = L'*[0 hatbeta*M'; hatbeta*M -(M+M')]*L;
PI = epsIQC*Pid + Pi1 + Pi2 + Pi3;

D(1,1) = PI(1,1);
D(2,2) = 1;
D(1,3) = PI(1,2);
D(3,1) = PI(2,1);
D(3,3) = PI(2,2);
D(4,4) = -1;

nzJ = 2;
nwJ = 2;
[PsiPss,DPsiPss] = jfactor(minreal(ss(D)),nzJ,nwJ);

%% Upright pendulum generalized plant
g = 9.81;
b = 0.2;
Ap = [0 1; g -b];
Bp = [0 0; -g 1];
Bu = [0;1];
Cp = [1 1; 0 0];
Dp = zeros(2);
Dzu = [0;1];

% Pure ODEs are represented as PI operators with a zero L2 component.
pvar sx stheta
vars = [sx,stheta];
dom = [0,1];

P.vars = vars;
P.dom = dom;
P.T = matrix_operator(eye(size(Ap,1)),vars,dom);
P.A = matrix_operator(Ap,vars,dom);
P.B1 = matrix_operator(Bp,vars,dom);
P.Bu = matrix_operator(Bu,vars,dom);
P.C1 = matrix_operator(Cp,vars,dom);
P.D11 = matrix_operator(Dp,vars,dom);
P.Dzu = matrix_operator(Dzu,vars,dom);

Psi = factor_box(PsiPss,nzJ,nwJ,vars,dom);
DPsi = factor_box(DPsiPss,nwJ,nzJ,vars,dom);
clear PsiPss DPsiPss D PI Pi1 Pi2 Pi3 Pid L M s

%% Start the synthesis program and define Vbar before the executive
progSynth = lpiprogram(vars(:,1),vars(:,2),dom);
[progSynth,muD] = lpidecvar(progSynth,'muD');
[progSynth,rhoD] = lpidecvar(progSynth,'rhoD');
progSynth = lpi_ineq(progSynth,muD-1e-4);
progSynth = lpi_ineq(progSynth,rhoD);
progSynth = lpisetobj(progSynth,rhoD);

Vbar = [muD,0,0,0;
        0,1,0,0;
        0,0,-muD,0;
        0,0,0,-rhoD];

[K,Zsynth,Psynth,progSynth] = PIETOOLS_IQC_controller_synthesis( ...
    progSynth,settings,P,DPsi,Vbar);

muDValue = double(lpigetsol(progSynth,muD));
rhoDValue = double(lpigetsol(progSynth,rhoD));
fprintf('\nController on [x_P; x_Theta]:\n');
disp(double(K.P));

% Paper constructions:
%       GP = Psi*[P;I],        GD = D(Psi)*[P^T;I].
PT.vars = P.vars;
PT.dom = P.dom;
PT.T = P.T';
PT.A = P.A';
PT.B1 = P.C1';
PT.C1 = P.B1';
PT.D11 = P.D11';

GP = PIETOOLS_IQC_graph(P,Psi);
GD = PIETOOLS_IQC_graph(PT,DPsi);

% Close the same synthesized K on the shared graph state. These closure
% maps differ, but the graph construction above does not.
BK = [P.Bu;
      Psi.B1*P.Dzu];
GP.A = GP.A+BK*K;
GP.C1 = GP.C1+Psi.D11*P.Dzu*K;
GP.C2 = GP.C2+Psi.D21*P.Dzu*K;

BuT = P.Bu';
ZuD = zero_operator(BuT.dim(:,1),DPsi.T.dim(:,2),vars,dom);
Cy = [BuT,ZuD];
GD.A = GD.A+K'*Cy;
GD.B1 = GD.B1+K'*P.Dzu';

%% Start the universal primal analysis and define V before the executive
progPrimal = lpiprogram(vars(:,1),vars(:,2),dom);
[progPrimal,muP] = lpidecvar(progPrimal,'muP');
progPrimal = lpi_ineq(progPrimal,muP-1e-4);

V = [muP,0,0,0;
     0,1,0,0;
     0,0,-muP,0;
     0,0,0,-rhoDValue];

[Pprimal,progPrimal] = PIETOOLS_IQC_analysis( ...
    progPrimal,settings,GP,V);
muPValue = double(lpigetsol(progPrimal,muP));
rhoPValue = rhoDValue;
%% Dual analysis
progDual = lpiprogram(vars(:,1),vars(:,2),dom);
VbarSolved = [muDValue,0,0,0;
              0,1,0,0;
              0,0,-muDValue,0;
              0,0,0,-rhoDValue];
[Pdual,progDual] = PIETOOLS_IQC_analysis( ...
    progDual,settings,GD,VbarSolved);

%% Construct and analyze G_0 and G_0^top
% Scale the already assembled primal and dual graphs. The normalized graph
% map eliminates the lower output using PI-operator algebra.
GP0 = scale_graph(GP, ...
    diag([sqrt(muPValue),1]),diag([sqrt(muPValue),sqrt(rhoDValue)]));
GD0 = scale_graph(GD, ...
    diag([sqrt(muDValue),1]),diag([sqrt(muDValue),sqrt(rhoDValue)]));
G0 = normalized_graph(GP0);
G0T = normalized_graph(GD0);

% Use the existing PIETOOLS H-infinity executive for both PIE systems.
[progG0,RG0,gamG0] = quiet_hinf_gain(G0,settings);
[progG0T,RG0T,gamG0T] = quiet_hinf_gain(G0T,settings);

fprintf('PIETOOLS bound on ||G_0||_inf      = %.10e\n',gamG0);
fprintf('PIETOOLS bound on ||G_0^top||_inf = %.10e\n',gamG0T);
fprintf('\nNormalized filtered-graph gains:\n');
fprintf('  primal spectral-factor mu_P  = %.10e\n',muPValue);
fprintf('  primal spectral-factor rho_P = %.10e (sqrt(rho_P) = %.10e)\n', ...
    rhoPValue,sqrt(rhoPValue));
fprintf('  dual spectral-factor mu_D    = %.10e\n',muDValue);
fprintf('  dual spectral-factor rho_D   = %.10e (sqrt(rho_D) = %.10e)\n', ...
    rhoDValue,sqrt(rhoDValue));
% Retain all certificates in the workspace for inspection.
Certificates = struct( ...
    'K',K,'Zsynthesis',Zsynth,'Psynthesis',Psynth,'programSynthesis',progSynth, ...
    'GP',GP,'GD',GD, ...
    'Pprimal',Pprimal,'programPrimal',progPrimal, ...
    'Pdual',Pdual,'programDual',progDual, ...
    'muD',muDValue,'rhoD',rhoDValue,'muP',muPValue, ...
    'G0',G0,'programG0',progG0,'RG0',RG0,'gamG0',gamG0, ...
    'G0T',G0T,'programG0T',progG0T,'RG0T',RG0T,'gamG0T',gamG0T);

%% Simulate the nonlinear closed loop
% PIE_sim_nl contains the complete simulation path: PI-operator assembly,
% closedLoopPIE, PIESIM discretization, closure of Delta, ode45, signal
% reconstruction, and plotting. The inputs of CL.P.B1 are ordered
% as [w_Delta;w_p], so simOpts.wp drives every channel after w_Delta.
CL.P = P;
CL.Theta = Psi;
CL.K = K;
CL.CDelta = matrix_operator([1,0],vars,dom);

Delta = @(zDelta) zDelta-sin(zDelta);
x0 = [0.5;0;zeros(sum(Psi.T.dim(:,2)),1)];
simOpts.N = 2;
simOpts.plot = true;
simOpts.labels = {'\theta [rad]','d\theta/dt'};
% simOpts.wp = @(t) 0;              % zero disturbance
simOpts.wp = @(t) 050*(t>=1 && t<=2);  % example pulse disturbance
sim = PIE_sim_nl(CL,Delta,[0,10],x0,simOpts);

t = sim.t;
x = sim.x;
u = sim.u;
Certificates.simulation = sim;

function op = matrix_operator(value,vars,dom)
op = mat2opvar(value,[size(value,1),size(value,2)],vars,dom);
end

function op = zero_operator(rowDim,colDim,vars,dom)
op = mat2opvar(zeros(sum(rowDim),sum(colDim)), ...
    [rowDim,colDim],vars,dom);
end

function Box = factor_box(sys,nz,nw,vars,dom)
A = sys.A;
B = sys.B;
C = sys.C;
D = sys.D;
if size(B,2) ~= nz+nw || size(C,1) ~= nz+nw
    error('The spectral factor dimensions do not match the J partition.');
end

Box.T = matrix_operator(eye(size(A,1)),vars,dom);
Box.A = matrix_operator(A,vars,dom);
Box.B1 = matrix_operator(B(:,1:nz),vars,dom);
Box.B2 = matrix_operator(B(:,nz+1:nz+nw),vars,dom);
Box.C1 = matrix_operator(C(1:nz,:),vars,dom);
Box.C2 = matrix_operator(C(nz+1:nz+nw,:),vars,dom);
Box.D11 = matrix_operator(D(1:nz,1:nz),vars,dom);
Box.D12 = matrix_operator(D(1:nz,nz+1:nz+nw),vars,dom);
Box.D21 = matrix_operator(D(nz+1:nz+nw,1:nz),vars,dom);
Box.D22 = matrix_operator(D(nz+1:nz+nw,nz+1:nz+nw),vars,dom);
end

function G = scale_graph(G,R1,R2)
if ~isequal(size(R1),[sum(G.C1.dim(:,1)),sum(G.C1.dim(:,1))])
    error('R1 has dimensions incompatible with the upper graph output.');
end
if ~isequal(size(R2),[sum(G.C2.dim(:,1)),sum(G.C2.dim(:,1))])
    error('R2 has dimensions incompatible with the lower graph output.');
end
R1 = mat2opvar(R1,G.C1.dim(:,1),G.vars,G.dom);
R2 = mat2opvar(R2,G.C2.dim(:,1),G.vars,G.dom);
G.C1 = R1*G.C1;
G.D11 = R1*G.D11;
G.C2 = R2*G.C2;
G.D21 = R2*G.D21;
end

function PIE = normalized_graph(G)
% Realize N*Gamma^(-1) directly from [N;Gamma] using PI operators.
if sum(G.D21.dim(:,1)) ~= sum(G.D21.dim(:,2))
    error('The lower graph feedthrough must be square.');
end
D21inv = inv_opvar_2(G.D21);

PIE = pie_struct();
PIE.vars = G.vars;
PIE.dom = G.dom;
PIE.T = G.T;
PIE.Tw = mat2opvar( ...
    zeros(sum(G.T.dim(:,1)),sum(D21inv.dim(:,2))), ...
    [G.T.dim(:,1),D21inv.dim(:,2)],G.vars,G.dom);
PIE.A = G.A-G.B1*D21inv*G.C2; 
PIE.B1 = G.B1*D21inv; 
PIE.C1 = G.C1-G.D11*D21inv*G.C2; 
PIE.D11 = G.D11*D21inv; 
PIE = initialize(PIE);
end

function [prog,R,gam] = quiet_hinf_gain(PIE,settings)
evalc('[prog,R,gam] = PIETOOLS_Hinf_gain(PIE,settings);');
end
