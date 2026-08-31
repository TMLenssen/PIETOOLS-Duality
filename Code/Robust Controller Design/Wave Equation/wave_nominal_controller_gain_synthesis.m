clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b")) 
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
% =============================================
% === Declare the system of interest

% % Declare system as PDE
% Declare independent variables (time and space)
pvar t s
a=0;
b=1;
d = 1;
lam = 3;
damp = 0.2;
wscale = 0.1*s;
% Standard implementation using v1 = z and v2 = z_t.
% Nominal shifted sine-Gordon model about v = pi:
%   z_tt = d*z_ss + lam*z - damp*z_t + s*(s-1)*w.
% This nominal formulation sets z_delta = 0 and w_delta = 0.
x = pde_var('state',1,[],[]);
v1 = pde_var(s,[a,b]);
v2 = pde_var(s,[a,b]);
z1 = pde_var('output',1);
z2 = pde_var('output',1);
w = pde_var('input',1);
u = pde_var('control',1);
PDE = [diff(v1,t) == v2;    % PDE
    diff(v2,t) == d*diff(v1,s,2) + lam*v1 - damp*v2 + wscale*w;
    diff(x,t) == u;
    z1 == x;
    z2 == int(v1,s,[a,b]);
    subs(v1,s,a) == 0;
    subs(v2,s,a) == 0;
    subs(diff(v1,s),s,1)==x];

% Alternative implementation using eta = z and v = z_t-z_s.
% This block is equivalent to the nominal shifted sine-Gordon model:
%   z_tt = d*z_ss + lam*z - damp*z_t + s*(s-1)*w.
% For d ~= 1, the term (d-1)*eta_ss appears explicitly.
% xo = pde_var('state',1,[],[]);
% eta = pde_var('state',1,s,[0,1]);
% v = pde_var('state',1,s,[0,1]);
% z = pde_var('output',2);        w = pde_var('input',1);
% u = pde_var('control',1);
% PDE = [diff(xo,t)==u;
%        diff(eta,t)==diff(eta,s)+v;
%        diff(v,t)==(d-1)*diff(eta,s,2)-diff(v,s) ...
%            + lam*eta-damp*(diff(eta,s)+v)+wscale*w;
%        z==[xo;int(eta,s,[0,1])];
%        subs(diff(eta,s),s,1)==xo;
%        subs(eta,s,0)==0;
%        subs(v,s,0)==-subs(diff(eta,s),s,0)];

% Alternative implementation, using phi = [z_{s}; z_{t}]
% Nominal shifted sine-Gordon dynamics about v = pi:
  % z_tt = d*z_ss + lam*z - damp*z_t + s*(s-1)*w.
% This nominal formulation sets z_delta = 0 and w_delta = 0.
% phi = pde_var('state',2,s,[0,1]);   x = pde_var('state',1,[],[]);
% w = pde_var('input',1);             r = pde_var('output',2);
% u = pde_var('control');   
% zrec = int([1 0]*phi,s,[0,s]);
% eq_dyn = [diff(x,t,1)==u
%           diff(phi,t,1)==[0 1; d 0]*diff(phi,s,1) + [0;1]*(lam*zrec-damp*([0 1]*phi)) + [0;wscale]*w];
% eq_out= r ==[x;int((1-s)*([1 0]*phi),s,[0,1])];
% bc1 = [0 1]*subs(phi,s,0)==0;   
% bc2 = [1 0]*subs(phi,s,1)==x;
% PDE = [eq_dyn;eq_out;bc1;bc2];

% % Convert PDE to PIE
PIE = convert(PDE);
misc = PIE.misc;
dim = PIE.dim;
dom = PIE.dom;
vars = PIE.vars;
T = PIE.T;      Tw = PIE.Tw;    Tu = PIE.Tu;
A = PIE.A;      Bw = PIE.B1;    Bu = PIE.B2;
Cz = PIE.C1;    Dzw = PIE.D11;  Dzu = PIE.D12;



%%



settings = lpisettings('veryheavy');
% settings.dd1 = 2;
% settings.ddZ = 2;
% settings.dd12 = 2;
settings.sos_opts.solver = 'mosek';
settings.options1.sep = 1;
settings.options12.sep = 1;
[prog, Kval, gam_val, Pval, Zval] = PIETOOLS_Hinf_control(PIE, settings);
% 
% %% Simulate the nominal shifted sine-Gordon linearization
% PIE_CL = closedLoopPIE(PIE,Kval);
% 
% %% Primal and dual closed-loop gain analysis
% analysisSettings = settings;
% analysisSettings.options1.sep = 0;
% analysisSettings.options12.sep = 0;
% [prog_primal,R_primal,gam_primal] = PIETOOLS_Hinf_gain(PIE_CL,analysisSettings);
% [prog_dual,R_dual,gam_dual] = PIETOOLS_Hinf_gain_dual(PIE_CL,analysisSettings);
% 
% synInfo = prog.solinfo.info;
% primalInfo = prog_primal.solinfo.info;
% dualInfo = prog_dual.solinfo.info;
% 
% fprintf('\nNominal synthesis feasibility ratio: %.10g\n',synInfo.feasratio);
% fprintf('Nominal synthesis status:             pinf=%g, dinf=%g, numerr=%g\n',synInfo.pinf,synInfo.dinf,synInfo.numerr);
% fprintf('Nominal synthesis gain:               %.10e\n',gam_val);
% fprintf('\nPrimal closed-loop feasibility ratio: %.10g\n',primalInfo.feasratio);
% fprintf('Primal closed-loop status:            pinf=%g, dinf=%g, numerr=%g\n',primalInfo.pinf,primalInfo.dinf,primalInfo.numerr);
% fprintf('Primal closed-loop gain:              %.10e\n',gam_primal);
% fprintf('\nDual closed-loop feasibility ratio:   %.10g\n',dualInfo.feasratio);
% fprintf('Dual closed-loop status:              pinf=%g, dinf=%g, numerr=%g\n',dualInfo.pinf,dualInfo.dinf,dualInfo.numerr);
% fprintf('Dual closed-loop gain:                %.10e\n',gam_dual);
% 
% syms st sx real
% 
% uinput.ic = 0;
% uinput.w = heaviside(st-0.5)-heaviside(st-0.75);
% 
% opts.plot = 'yes';
% opts.N = 16;
% opts.tf = 5;
% opts.dt = 1e-2;
% opts.intScheme = 1;
% opts.Norder = 2;
% opts.ploteig = 'no';
% opts.ifexact = false;
% 
% [solution_OL,~] = PIESIM(PIE,opts,uinput);
% [solution_CL,~] = PIESIM(PIE_CL,opts,uinput);
% 
% tval = solution_OL.timedep.dtime;
% z_OL = solution_OL.timedep.regulated{1};
% z_CL = solution_CL.timedep.regulated{1};
% wval = double(subs(uinput.w,st,tval));
% 
% figure('Color','w');
% subplot(3,1,1);
% plot(tval,z_OL(1,:),'LineWidth',1.4); hold on;
% plot(tval,z_CL(1,:),'LineWidth',1.4);
% grid on;
% ylabel('$x(t)$','Interpreter','latex');
% legend('Open loop','Closed loop','Interpreter','latex','Location','best');
% title('Boundary ODE State','Interpreter','latex');
% 
% subplot(3,1,2);
% plot(tval,z_OL(2,:),'LineWidth',1.4); hold on;
% plot(tval,z_CL(2,:),'LineWidth',1.4);
% grid on;
% ylabel('$\int_0^1 z(t,s)ds$','Interpreter','latex');
% legend('Open loop','Closed loop','Interpreter','latex','Location','best');
% title('Average Displacement','Interpreter','latex');
% 
% subplot(3,1,3);
% plot(tval,wval,'k','LineWidth',1.4);
% grid on;
% xlabel('$t$','Interpreter','latex');
% ylabel('$w(t)$','Interpreter','latex');
% title('Disturbance Input','Interpreter','latex');
% 
% echo off
