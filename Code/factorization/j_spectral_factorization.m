clearvars; close all; clc; yalmip('clear');
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"));
s = tf('s');

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

[ThP,ThD] = jfactor(minreal(ss(D)),2,2);


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
          0,       0,       0,         -rhoP ];

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
rhoPval = value(rhoP);
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
