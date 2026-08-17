clearvars; close all; clc; yalmip('clear');
s = tf('s');

%% IQCs
beta = 1.217234; hatbeta = 2; epsIQC = 1e-2;

L = blkdiag(1/(s+1),1);
M = 1 - 1/(s+1);
Pid = diag([1,-1/beta^2]);

Pi{1} = L'*[0 beta; beta -2]*L + epsIQC*Pid;
Pi{2} = L'*[0 -s; s 0]*L + epsIQC*Pid;
Pi{3} = L'*[0 hatbeta*M'; hatbeta*M -(M+M')]*L + epsIQC*Pid;

%% Primal and dual J-factorizations
PsiP = [];
PsiD = [];

for i = 1:3
    [ThP,ThD] = jfactor(minreal(ss(Pi{i})),1,1);
    PsiP = [PsiP; ThP];
    PsiD = [PsiD; ThD];
end

J = diag([1 -1]);

%% Pendulum
g = 9.81; b = 0.2;

Ap = [0 1;
      g -b];

Bp = [0;-g];
Bu = [0;1];

Cp  = [1 1];
Dp  = 0;
Dzu = 0;

np = size(Ap,1);

opts = sdpsettings('solver','mosek','verbose',0);

%% =========================================================
% DUAL SYNTHESIS
% ==========================================================

plantD = ss(Ap',Cp',Bp',Dp');
GD = augment(plantD,PsiD);

Ad = GD.A; Bd = GD.B;
Cd = GD.C; Dd = GD.D;

nxD = size(Ad,1);
nwD = size(Bd,2);

PD  = sdpvar(nxD,nxD,'symmetric');
Z   = sdpvar(nxD,1);
muD = sdpvar(3,1);

Cy = [Bu', zeros(1,nxD-np)];

X = PD*Ad + Z*Cy;
Y = PD*Bd + Z*Dzu';

VD = blkdiag(muD(1)*J, ...
             muD(2)*J, ...
             muD(3)*J);

LD = [X+X' Y;
      Y' 1e-6*eye(nwD)] ...
     + [Cd Dd]'*VD*[Cd Dd];

conD = [PD >= 1e-3*eye(nxD), ...
        LD <= 0, ...
        muD >= 1e-4];

solD = optimize(conD,sum(muD),opts);
if solD.problem
    error('Dual failed: %s',solD.info);
end

muDval = value(muD);
K = value(Z)'/value(PD);

%% =========================================================
% PRIMAL WITH FIXED K
% ==========================================================

plantP = ss(Ap,Bp,Cp,Dp);
GP = augment(plantP,PsiP);

A0 = GP.A; B0 = GP.B;
C0 = GP.C; D0 = GP.D;

nxP = size(A0,1);
nwP = size(B0,2);

assert(size(K,2) == nxP, ...
    'Primal and dual augmented state dimensions differ.');

BuAug = [Bu;
         zeros(nxP-np,1)];

Acl = A0 + BuAug*K;

%% =========================================================
% INDEPENDENT PRIMAL mu
% ==========================================================

PP  = sdpvar(nxP,nxP,'symmetric');
muP = sdpvar(3,1);

VP = blkdiag(muP(1)*J, ...
             muP(2)*J, ...
             muP(3)*J);

LP = [Acl'*PP + PP*Acl, PP*B0;
      B0'*PP,           1e-6*eye(nwP)] ...
     + [C0 D0]'*VP*[C0 D0];

conP = [PP >= 1e-3*eye(nxP), ...
        LP <= 0, ...
        muP >= 1e-4];

solP = optimize(conP,sum(muP),opts);
if solP.problem
    error('Primal failed: %s',solP.info);
end

muPval = value(muP);

%% =========================================================
% RESULTS
% ==========================================================

fprintf('\nK =\n');
disp(K);

fprintf('             mu_D        mu_P       1/mu_D     muP*muD\n');
disp([muDval, muPval, muPval.*muDval]);

fprintf('Dual max eig LMI   = %.3e\n', ...
    max(eig((value(LD)+value(LD)')/2)));

fprintf('Primal max eig LMI = %.3e\n', ...
    max(eig((value(LP)+value(LP)')/2)));

%% =========================================================
% SIMULATE NONLINEAR CLOSED LOOP
% ==========================================================

F = ss(PsiP);

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

%% Animate pendulum
l = 1;

figure;
axis equal
axis([-1.2*l 1.2*l -1.2*l 1.2*l])
grid on
hold on

% Ground / pivot
plot([-0.3 0.3],[0 0],'k','LineWidth',2);
plot(0,0,'ko','MarkerFaceColor','k');

% Initial pendulum
xp = l*sin(theta(1));
yp = l*cos(theta(1));

rod = plot([0 xp],[0 yp],'-o', ...
    'LineWidth',3, ...
    'MarkerSize',12, ...
    'MarkerFaceColor','auto');

titleText = title('');

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