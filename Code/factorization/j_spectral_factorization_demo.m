clearvars; close all; clc; yalmip('clear');
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"));
s = tf('s');

echo off

%% IQCs
beta = 1.217234; hatbeta = 2; epsIQC = 1e-2;

L = blkdiag(1/(s+1),1);
M = 1 - 1/(s+1);
Pid = diag([1,-1/beta^2]);

Pi{1} = L'*[0 beta; beta -2]*L;
Pi{2} = L'*[0 -s; s 0]*L;
Pi{3} = L'*[0 hatbeta*M'; hatbeta*M -(M+M')]*L;

%% Primal and dual J-factorizations
PsiP = [];
PsiD = [];

PI = epsIQC*Pid+Pi{1}+Pi{2}+Pi{3};

D(1,1) = PI(1,1);
D(2,2) = 1;
D(1,3) = PI(1,2);
D(3,1) = PI(2,1);
D(3,3) = PI(2,2);
D(4,4) = -1;

nzJ = 2;
nwJ = 2;
[ThP,ThD] = jfactor(minreal(ss(D)),nzJ,nwJ);


PsiP = ThP;
PsiD = ThD;

%% Pendulum
g = 9.81; b = 0.2;

Ap = [0 1;
      g -b];

Bp = [0, 0;-g,1];
Bu = [0;1];

Cp  = [1 1; 0 0];
Dp  = zeros(2);
Dzu = [0;1];

np = size(Ap,1);

opts = sdpsettings('solver','mosek','verbose',0);

%% =========================================================
% NUMERICAL STRICTNESS USED DURING GAMMA/RHO OPTIMIZATION
% ==========================================================

epsFeas = 0;%1e-6;

%% =========================================================
% DUAL SYNTHESIS: STAGE 1 -- MINIMIZE RHO
% ==========================================================

plantD = ss(Ap',Cp',Bp',Dp');
GD = augment(plantD,PsiD);

Ad = GD.A;
Bd = GD.B;
Cd = GD.C;
Dd = GD.D;

nxD = size(Ad,1);
nwD = size(Bd,2);

PD   = sdpvar(nxD,nxD,'symmetric');
Z    = sdpvar(nxD,1);
muD  = sdpvar(1);
rhoD = sdpvar(1);

Cy = [Bu', zeros(1,nxD-np)];

X = PD*Ad + Z*Cy;
Y = PD*Bd + Z*Dzu';

% 4x4 multiplier corresponding to jfactor(...,2,2)
VD = [ muD, 0,    0,     0;
       0,   1,    0,     0;
       0,   0,   -muD,   0;
       0,   0,    0,    -rhoD ];

LD_rho = ...
    [X+X', Y;
     Y',   epsFeas*eye(nwD)] ...
    + [Cd Dd]'*VD*[Cd Dd];

conD_rho = [ ...
    PD >= 1e-3*eye(nxD), ...
    LD_rho <= 0, ...
    muD >= 1e-4, ...
    rhoD >= 0];

solD_rho = optimize(conD_rho,rhoD,opts);

if solD_rho.problem
    error('Dual rho minimization failed: %s',solD_rho.info);
end

%% Store the complete optimal dual solution

PDval   = value(PD);
Zval    = value(Z);
muDval  = value(muD);
rhoDval = value(rhoD);

% Controller synthesized ONLY on the dual side
K = Zval'/PDval;

%% =========================================================
% PRIMAL CLOSED LOOP -- K FIXED FROM DUAL SYNTHESIS
% ==========================================================

plantP = ss(Ap,Bp,Cp,Dp);
GP = augment_controller(plantP,PsiP,Bu,Dzu,K);

A0 = GP.A;
B0 = GP.B;
C0 = GP.C;
D0 = GP.D;

nxP = size(A0,1);
nwP = size(B0,2);

assert(size(K,2) == nxP, ...
    'Primal and dual augmented state dimensions differ.');


%% =========================================================
% PRIMAL ANALYSIS: STAGE 1 -- K FIXED, MINIMIZE RHO
% ==========================================================

PP   = sdpvar(nxP,nxP,'symmetric');
muP  = sdpvar(1);
rhoP = sdpvar(1);

epsilonP = sdpvar(1);

VP = [ muP, 0,       0,          0;
          0,       1,       0,          0;
          0,       0,      -muP,     0;
          0,       0,       0,         -rhoDval ];

LP_eps = ...
    [A0'*PP + PP*A0, PP*B0;
     B0'*PP,             epsFeas*eye(nwP)] ...
    + [C0 D0]'*VP*[C0 D0];

conP_eps = [ ...
    PP >= 1e-3*eye(nxP), ...
    LP_eps <= 0, ...
    muP >= 1e-4, ...
    rhoP >= 0];

solP_eps = optimize(conP_eps,rhoP,opts);

if solP_eps.problem
    error('Primal epsilon maximization failed: %s',solP_eps.info);
end

epsilonPval = epsFeas;%value(epsilonP);
muPval = value(muP);
rhoPval = rhoDval;%value(rhoP);

%% =========================================================
% INDUCED L2 GAINS OF G_0 AND G_0^T
% ==========================================================

% Construct G_0 from the primal analysis solution. The primal LMI uses
%   VP = diag(muP,1,-muP,-rhoP) = RP'*Jp*RP,
% so the primal J-spectral factor is ThetaP = RP*PsiP.
% (Here rhoP is the squared performance gain coefficient, so sqrt(rhoP)
% appears in the spectral factor.)
if muPval <= 0 || rhoPval <= 0 || muDval <= 0 || rhoDval <= 0
    error('The primal and dual multiplier parameters must be positive.');
end

RP = diag([sqrt(muPval), 1, ...
           sqrt(muPval), sqrt(rhoPval)]);

% GP maps w -> PsiP*[P_K; I]*w. Premultiplication by RP gives the
% optimized primal factor. Thus
% G_0 = (Theta_11*P_K + Theta_12) ...
%       *(Theta_21*P_K + Theta_22)^(-1).
GPscaled = RP*GP;
G0 = normalized_graph_map(GPscaled,nzJ,nwJ);

% Construct G_0^T independently from the dual synthesis solution. The dual
% LMI uses VD = diag(muD,1,-muD,-rhoD) = RD'*Jd*RD, so its optimized
% J-spectral factor is ThetaD = RD*PsiD.
RD = diag([sqrt(muDval), 1, ...
           sqrt(muDval), sqrt(rhoDval)]);

% Close the dual filtered graph with the same K and construct G_0^T.
% This maps w_bar -> [z_tilde_bar; w_tilde_bar]
%                 = D(Theta)*[P_K^T; I]*w_bar.
GDcl = ss(Ad + K'*Cy, ...
          Bd + K'*Dzu', ...
          Cd, Dd);
GDclScaled = RD*GDcl;
G0T = normalized_graph_map(GDclScaled,nwJ,nzJ);

if ~isstable(G0) || ~isstable(G0T)
    error('G_0 or G_0^T is unstable; its induced L2 gain is infinite.');
end

[gainG0,peakFreqG0]   = norm(G0,inf);
[gainG0T,peakFreqG0T] = norm(G0T,inf);

% These factors use independently optimized primal and dual scalings, so
% G0T need not equal G0.' as a transfer matrix.
gainRelativeError = abs(gainG0-gainG0T)/max([1,gainG0,gainG0T]);
%% =========================================================
% RESULTS
% ==========================================================

fprintf('\n====================================================\n');
fprintf('DUAL SYNTHESIS / PRIMAL ANALYSIS COMPARISON\n');
fprintf('====================================================\n');

fprintf('\nK =\n');
disp(K);

fprintf('Dual:\n');
fprintf('  rho_D     = %.10e\n',rhoDval);
fprintf('  mu_D      = %.10e\n',muDval);

fprintf('\nPrimal:\n');
fprintf('  mu_P      = %.10e\n',muPval);
fprintf('  rho_P     = %.10e\n',rhoPval);

fprintf('\nNormalized filtered-graph gains:\n');
fprintf('  primal spectral-factor mu_P  = %.10e\n',muPval);
fprintf('  primal spectral-factor rho_P = %.10e (sqrt(rho_P) = %.10e)\n', ...
    rhoPval,sqrt(rhoPval));
fprintf('  dual spectral-factor mu_D    = %.10e\n',muDval);
fprintf('  dual spectral-factor rho_D   = %.10e (sqrt(rho_D) = %.10e)\n', ...
    rhoDval,sqrt(rhoDval));
fprintf('  ||G_0||_inf       = %.10e  (peak at %.6g rad/s)\n', ...
    gainG0,peakFreqG0);
fprintf('  ||G_0^T||_inf     = %.10e  (peak at %.6g rad/s)\n', ...
    gainG0T,peakFreqG0T);
fprintf('  relative gain gap = %.3e\n',gainRelativeError);

LD_eps_val = value(LD_rho);
LP_eps_val = value(LP_eps);

fprintf('\nFinal epsilon-stage LMI residuals:\n');

fprintf('  Dual max eig   = %.3e\n', ...
    max(eig((LD_eps_val+LD_eps_val')/2)));

fprintf('  Primal max eig = %.3e\n', ...
    max(eig((LP_eps_val+LP_eps_val')/2)));

fprintf('====================================================\n');

%% =========================================================
% SIMULATE NONLINEAR CLOSED LOOP
% ==========================================================

F = ss(PsiP([1 3], [1 3]));

Af = F.A;
Bf = F.B;

nz = 1;
Bz = Bf(:,1:nz);
Bw = Bf(:,nz+1:end);

nf = size(Af,1);

% Controller partition
Kp   = K(:,1:2);
Kpsi = K(:,3:end);

% Initial condition
theta0 = 0.5;       % rad
dtheta0 = 0;

x0 = [theta0;
      dtheta0;
      zeros(nf,1)];

tspan = [0 10];

% Simulate
[t,x] = ode45(@(t,x) dynamics(x,Af,Bz,Bw,Kp,Kpsi,g,b), ...
              tspan,x0);

theta  = x(:,1);
dtheta = x(:,2);

% Compute control signal
u = zeros(length(t),1);

for i = 1:length(t)
    xp   = x(i,1:2)';
    xpsi = x(i,3:end)';
    u(i) = Kp*xp + Kpsi*xpsi;
end


%% Plot
figure;

subplot(3,1,1)
plot(t,theta,'LineWidth',1.5)
grid on
ylabel('\theta [rad]')

subplot(3,1,2)
plot(t,dtheta,'LineWidth',1.5)
grid on
ylabel('d\theta/dt')

subplot(3,1,3)
plot(t,u,'LineWidth',1.5)
grid on
ylabel('u')
xlabel('Time [s]')

function dx = dynamics(x,Af,Bz,Bw,Kp,Kpsi,g,b)

theta  = x(1);
dtheta = x(2);
xpsi   = x(3:end);

% Actual nonlinear uncertainty
w = theta - sin(theta);

% Loop-shifted uncertainty output
zhat = theta + dtheta;

% Controller
xp = [theta; dtheta];

u = Kp*xp + Kpsi*xpsi;

% Nonlinear pendulum
dxp = [dtheta;
       g*sin(theta) - b*dtheta + u];

% Primal IQC-filter dynamics
dxpsi = Af*xpsi + Bz*zhat + Bw*w;

dx = [dxp;
      dxpsi];

end

function G = normalized_graph_map(filteredGraph,nz,nw)
%NORMALIZED_GRAPH_MAP Convert [N; Gamma] into N*Gamma^(-1).
% The filtered graph must map an nw-dimensional original input to nz+nw
% outputs ordered as [z_tilde; w_tilde]. The inverse realization below is
% valid when Gamma has nonsingular feedthrough, as required by bounded
% causal invertibility for a proper finite-dimensional LTI system.

tol = 1e-10;

assert(size(filteredGraph,1) == nz+nw, ...
    'Filtered graph outputs must be ordered as [z_tilde; w_tilde].');
assert(size(filteredGraph,2) == nw, ...
    'The lower filtered-graph block must be square.');

N = filteredGraph(1:nz,:);
Gamma = filteredGraph(nz+(1:nw),:);

[Ag,Bg,Cg,Dg] = ssdata(Gamma);
if rcond(Dg) <= tol
    error(['Gamma has singular or ill-conditioned feedthrough; ', ...
           'a proper bounded causal inverse cannot be formed.']);
end

DgInv = Dg\eye(nw);
GammaInv = ss(Ag-Bg*DgInv*Cg, ...
              Bg*DgInv, ...
              -DgInv*Cg, ...
              DgInv);

if ~isstable(GammaInv)
    error('Gamma does not have a stable causal inverse.');
end

G = minreal(N*GammaInv,1e-8);
end
