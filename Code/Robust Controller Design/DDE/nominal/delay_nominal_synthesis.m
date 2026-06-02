clearvars; clc; clear stateNameGenerator; close all;
echo off

%% Paths
path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));

%% Declare PDE / PIE for controller synthesis
pvar t s
a = 0;
b = 1;
x1 = pde_var('state');
x2 = pde_var('state');
x3 = pde_var('state');
x4 = pde_var('state');

ph1 = pde_var('state', 1, s);
ph2 = pde_var('state', 1, s);
ph3 = pde_var('state', 1, s);
ph4 = pde_var('state', 1 ,s);

z  = pde_var('output',3);
w  = pde_var('input',1);
u = pde_var('control',1);

m1 = 1.0;
k1 = 2.0;
c1 = 0.25;

m2 = 1.2;
k2 = 1.5;
c2 = 0.20;

kc = 0.8;
cc = 0.12;

% Delayed coupling gains.
kt = 0.5;
ct = 0.05;
tau = 0.2;

% Keep synthesis and simulation PDE definitions identical
PDE = [diff(x1,t) ==x2;
    diff(x2,t) == -(k1/m1)*x1 - (c1/m1)*x2 - (kc/m1)*(x1-x3)-(cc/m1)*(x2-x4) - (kt/m1)*(subs(ph1,s,b) - subs(ph2,s,b)) - (ct/m1)*(subs(ph3,s,b) - subs(ph4,s,b)) + (1/m1)*u;
    diff(x3,t) == x4;
    diff(x4,t) == -(k2/m2)*x3 - (c2/m2)*x4 - (kc/m2)*(x3-x1)-(cc/m2)*(x4-x2) - (kt/m2)*(subs(ph2,s,b) - subs(ph1,s,b)) - (ct/m2)*(subs(ph4,s,b) - subs(ph3,s,b)) + (1/m2)*w;
    diff(ph1,t) == -(1/tau)*diff(ph1,s);
    diff(ph2,t) == -(1/tau)*diff(ph2,s);
    diff(ph3,t) == -(1/tau)*diff(ph3,s);
    diff(ph4,t) == -(1/tau)*diff(ph4,s);
    z  == [x3;x4;0.05*u];
    subs(ph1,s,a) == x1;
    subs(ph2,s,a) == x3;
    subs(ph3,s,a) == x2;
    subs(ph4,s,a) == x4];

display_PDE(PDE);

PIE = convert(PDE);
Eye = @(n) eyePI(n, PIE.vars, PIE.dom);

%% Controller synthesis
prog = lpiprogram(PIE.vars(:,1), PIE.vars(:,2), PIE.dom);

settings = lpisettings('veryheavy');
settings.sos_settings.solver = 'mosek';
% settings.options1.sep  = true;
% settings.options12.sep = true;

dpvar gam_dec
prog = lpidecvar(prog, gam_dec);
prog = lpi_ineq(prog, gam_dec);
prog = lpisetobj(prog, gam_dec);

coercive = true;
[prog, Z, P] = PIETOOLS_Construct_Nominal_Controller_Gain( ...
    prog, PIE, settings, coercive, gam_dec, 2);

disp('- Solving the LPI using the specified SDP solver...');
prog = lpisolve(prog, settings.sos_opts);

gam_val = double(lpigetsol(prog, gam_dec));
disp('Closed-loop H-infinity upper bound gamma =');
disp(gam_val);

Psol = lpigetsol(prog, P);
Zsol = lpigetsol(prog, Z);

% For validation, do not clean first
Kval = Zsol * inv_opvar_2(Psol);

% % Optional:
tol = 1e-4;
Kval = clean_opvar(Kval, tol);

PIE_CL = stateFeedbackCL(PIE, Kval);

% % Declare initial values and disturbance
syms st sx real
uinput.ic = [0.5;0;-1;0; zeros(4,1)];    % estimated initial PIE state value
% w3 = (heaviside(st-0.5)-heaviside(st-0.75));
% wsinc = 2*(sin(2*pi*st)/2*pi*st);
% uinput.w(1) = wsinc;

% % Set options for discretization and simulation
opts.plot = 'yes';  % plot solution
opts.N = 8;         % expand using 8 Chebyshev polynomials
opts.tf = 10;        % simulate up to t = 2
opts.dt = 1e-2;     % use time step of 10^-3
ndiff = [0,4];    % PDE state involves 2 second order differentiable state variables

% % Simulate solution to the PIE with estimator.
[solution,~] = PIESIM(PIE_CL,opts,uinput,ndiff);
% % Extract actual and estimated state and output at each time step.
tval = solution.timedep.dtime;
x_act = reshape(solution.timedep.pde(:,1,:),opts.N+1,[]);
x_est = reshape(solution.timedep.pde(:,2,:),opts.N+1,[]);
z_act = solution.timedep.regulated(1,:);