clearvars; close all; clc; yalmip('clear');
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"));

m = 1; l = 1; g = 9.81; I = m*l^2; b = 0.2;
A0 = [0 1; g/l -b/I];
Bd = [0; -g/l];
Bw = [0; 1/I];
Bu = Bw;
Cd = [1 0];
Cz = zeros(1,2);
B = [Bd Bw];
C = [Cd; Cz];
D = zeros(2);
Dzu = [0; 1];

nx = size(A0,1); nw = size(B,2); nz = size(C,1);
alpha = 0; beta = 1.217234;
epsDual = 1e-6; tol = 1e-8;
pmin = 1e-3; gammaMax = 1.20;
opts = sdpsettings('solver','mosek','verbose',0);
Tsec = [beta -1; -alpha 1];

%% Dual synthesis
P = sdpvar(nx,nx,'symmetric');
Z = sdpvar(nx,1,'full');
Wbar = sdpvar(1); rho = sdpvar(1); tGain = sdpvar(1);

X = P*A0' + Z*Bu';
Y = P*C' + Z*Dzu';
Vd = Tsec'*[0 Wbar; Wbar 0]*Tsec/(beta-alpha)^2;
Vbar = [blkdiag(Vd(1,1),1), blkdiag(Vd(1,2),0); ...
        blkdiag(Vd(1,2),0), blkdiag(Vd(2,2),-rho)];
Cbar = [B'; zeros(nw,nx)];
Dbar = [D'; eye(nw)];
Ldual = [X+X' Y; Y' epsDual*eye(nz)] ...
      + [Cbar Dbar]'*Vbar*[Cbar Dbar];

base = [P >= pmin*eye(nx), Wbar >= tol, rho >= tol, ...
       Ldual <= 0, tGain >= 0, ...
       [P Z; Z' tGain] >= 0];

%% 1. Minimize tGain
d = optimize([base, rho <= gammaMax^2],tGain,opts);
if d.problem, error('Gain minimization failed: %s',d.info); end
tGainOpt = value(tGain);
K = value(Z)'/value(P);

%% 2. Minimize dual gamma
d = optimize([P >= tol*eye(nx), Wbar >= tol, rho >= tol, ...
              Z == P*K', Ldual <= 0],rho,opts);
if d.problem, error('Gamma minimization failed: %s',d.info); end
rhoD = value(rho); WbarD = value(Wbar); gammaD = sqrt(rhoD);

Acl = A0 + Bu*K;
Ccl = C + Dzu*K;

Riqc = pendulum_multiplier_analysis(K,A0,Bd,Bw,Bu,Cd,beta,opts);


%% 3. Minimize primal gamma
Pp = sdpvar(nx,nx,'symmetric');
Wp = sdpvar(1); rhoP = sdpvar(1);
Vd = Tsec'*[0 Wp; Wp 0]*Tsec;
Vp = [blkdiag(Vd(1,1),1), blkdiag(Vd(1,2),0); ...
      blkdiag(Vd(1,2),0), blkdiag(Vd(2,2),-rhoP)];
Cg = [Ccl; zeros(nw,nx)];
Dg = [D; eye(nw)];
Lp = [Acl'*Pp+Pp*Acl Pp*B; B'*Pp epsDual*eye(nw)] ...
   + [Cg Dg]'*Vp*[Cg Dg];

d = optimize([Pp >= tol*eye(nx), Wp >= tol, rhoP >= tol, Lp <= 0],rhoP,opts);
if d.problem, error('Primal analysis failed: %s',d.info); end
rhoP = value(rhoP); gammaP = sqrt(rhoP);

fprintf('\nK = [%.6g  %.6g]\n',K);
fprintf('||K||_2       = %.6g\n',norm(K));
fprintf('dual gamma     = %.10g (step 2)\n',gammaD);
fprintf('primal gamma   = %.10g (step 3)\n',gammaP);

%% Nonlinear simulation
tspan = [0 10]; x0 = [0.5; 0];
dist = @(t) 0.1*sin(2*t);
f = @(t,x) A0*x + Bd*(x(1)-sin(x(1))) + Bw*dist(t) + Bu*K*x;
[t,x] = ode45(f,tspan,x0,odeset('RelTol',1e-8,'AbsTol',1e-10));
u = x*K'; dsim = arrayfun(dist,t);

figure('Color','w');
tiledlayout(2,1);
nexttile; plot(t,x,'LineWidth',1.2); grid on;
xlabel('Time (s)'); ylabel('State'); legend('\theta','d\theta/dt');
nexttile; plot(t,[u dsim],'LineWidth',1.2); grid on;
xlabel('Time (s)'); ylabel('Torque'); legend('u','d');

Metric = ["gamma_ceiling"; "tGain_step1"; "K_theta"; "K_thetaDot"; "norm(K)"; "gamma_dual_step2"; ...
          "gamma_primal_step3"; "gamma_difference"; ...
          "max_abs_theta"; "max_abs_u"];
Value = [gammaMax; tGainOpt; K(1); K(2); norm(K); gammaD; gammaP; abs(gammaD-gammaP); ...
         max(abs(x(:,1))); max(abs(u))];
Overview = table(Metric,Value);
disp(Overview);
