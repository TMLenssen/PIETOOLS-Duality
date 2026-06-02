clearvars; clc; clear stateNameGenerator;
echo off

%% Paths
path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"))

%% Weights
Wu = makeweight(1, [4*2*pi, db2mag(20)+db2mag(3)], db2mag(60));

dcgain = 1;
Wd = makeweight(dcgain, [2*pi, db2mag(mag2db(dcgain)-3)], ...
                db2mag(mag2db(dcgain)-60));

%% Declare PDE / PIE
pvar t s

x1 = pde_var('state',1,s,[0,1]);
x2 = pde_var('state');
x3 = pde_var('state');
x4 = pde_var('state');

z  = pde_var('output',1);
w  = pde_var('input',1);
u  = pde_var('control',1);

y1 = pde_var('sense');
y2 = pde_var('sense');
y3 = pde_var('sense');
y4 = pde_var('sense');

lam = 5;

PDE = [diff(x1,t) == diff(x1,s,2) + lam*x1 + Wd.C*x4 + Wd.D*w;
       diff(x2,t) == u;
       diff(x3,t) == Wu.A*x3 + Wu.B*x2;
       diff(x4,t) == Wd.A*x4 + Wd.B*w;
       z  == Wu.C*x3 + Wu.D*x2;
       subs(x1,s,0) == 0;
       subs(diff(x1,s),s,1) == x2];

display_PDE(PDE);

PIE = convert(PDE);

%% Build block operator Mop = [-A  -wT;  wT  -A]
nx = PIE.A.dim(:,1); nw = PIE.B1.dim(:,2);
stateDimC = ioDimensions(["xr","xc"], [nx,nx]');
inputDimC = ioDimensions(["wr","wc"], [nw,nw]');
M = gridBuilder(stateDimC, stateDimC, PIE.vars, PIE.dom);
BBig = gridBuilder(stateDimC, inputDimC, PIE.vars, PIE.dom);

wfreq = 1000;

M(1,1) = -PIE.A;
M(1,2) = -wfreq*PIE.T;
M(2,1) =  wfreq*PIE.T;
M(2,2) = -PIE.A;

BBig(1,1) = PIE.B1;
BBig(2,2) = PIE.B1;
Win = mat2opvar([1;0], [2,1;0,0], PIE.vars, PIE.dom);
Mop = M();
b = BBig()*Win;
%% Settings
settings = lpisettings("light");
settings.sosineq_on = 0;
settings.sos_opts.psatz = 0;
%% Fit approximate inverse: choose best of left/right
[xfit, gam_sol, prob] = solve_opvar(Mop, b, settings);
sqrt(gam_sol)

disp('Done.')

