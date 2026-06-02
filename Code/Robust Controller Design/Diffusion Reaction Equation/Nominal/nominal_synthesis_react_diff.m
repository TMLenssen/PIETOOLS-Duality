clearvars; clc; clear stateNameGenerator; close all;
echo off

%% Paths
path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));

%% Weights
% Note:
% If you intended 23 dB exactly at 4*2*pi rad/s, replace
%   db2mag(20)+db2mag(3)
% by
%   db2mag(23)
Wu = makeweight(1, [4*2*pi, db2mag(20)+db2mag(3)], db2mag(60));

dcgain = 1;
Wd = makeweight(dcgain, [2*pi, db2mag(mag2db(dcgain)-3)], ...
    db2mag(mag2db(dcgain)-60));

Gbound = inv(Wu)*inv(Wd);

%% Plot weights
wplot = logspace(-2, 6, 800);

Wu_mag = squeeze(abs(freqresp(Wu, wplot)));
Wd_mag = squeeze(abs(freqresp(Wd, wplot)));
G_mag  = squeeze(abs(freqresp(Gbound, wplot)));

Wu_db = mag2db(Wu_mag);
Wd_db = mag2db(Wd_mag);
G_db  = mag2db(G_mag);

figure('Color','w','Position',[50,50,1000,800]);
tl = tiledlayout(3,1,'TileSpacing','none','Padding','tight');

ax1 = nexttile;
semilogx(ax1, wplot, Wu_db, 'LineWidth', 4);
grid on
box(ax1, 'on');
set(ax1, 'FontSize', 20, 'LineWidth', 1.5);
ylabel(ax1, '');
ax1.XTickLabel = [];
t1 = title(ax1, '$|W_u|$', 'Interpreter', 'latex', 'FontSize', 64);
t1.Units = 'normalized';
t1.Position = [0.15, 0.30, 0];
t1.BackgroundColor = 'w';

ax2 = nexttile;
semilogx(ax2, wplot, Wd_db, 'LineWidth', 4);
grid on
box(ax2, 'on');
set(ax2, 'FontSize', 20, 'LineWidth', 1.5);
ylabel(ax2, 'Magnitude (dB)');
ylim(ax2, [-79.999, 0]);
ax2.XTickLabel = [];
t2 = title(ax2, '$|W_d|$', 'Interpreter', 'latex', 'FontSize', 64);
t2.Units = 'normalized';
t2.Position = [0.15, 0.30, 0];
t2.BackgroundColor = 'w';

ax3 = nexttile;
semilogx(ax3, wplot, G_db, 'LineWidth', 4);
grid on
box(ax3, 'on');
set(ax3, 'FontSize', 20, 'LineWidth', 1.5);
ylabel(ax3, '');
xlabel(ax3, 'Frequency (rad/s)');
t3 = title(ax3, '$|W_u^{-1}W_d^{-1}|$', 'Interpreter', 'latex', 'FontSize', 64);
t3.Units = 'normalized';
t3.Position = [0.15, 0.25, 0];
t3.BackgroundColor = 'w';

linkaxes([ax1 ax2 ax3], 'x');

%% Declare PDE / PIE for controller synthesis
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

% Keep synthesis and simulation PDE definitions identical
PDE = [diff(x1,t) == diff(x1,s,2) + lam*x1 + Wd.C*x4 + Wd.D*w;
    diff(x2,t) == u;
    diff(x3,t) == Wu.A*x3 + Wu.B*x2;
    diff(x4,t) == Wd.A*x4 + Wd.B*w;
    z  == Wu.C*x3 + Wu.D*x2;
    % y1 == x2;
    % y2 == Wd.C*x4 + Wd.D*w;
    subs(x1,s,0) == 0;
    subs(diff(x1,s),s,1) == x2];

display_PDE(PDE);

PIE = convert(PDE);
Eye = @(n) eyePI(n, PIE.vars, PIE.dom);
%% Controller synthesis
prog = lpiprogram(PIE.vars(:,1), PIE.vars(:,2), PIE.dom);

settings = lpisettings('veryheavy');
settings.sos_settings.solver = 'mosek';
settings.options1.sep  = true;
settings.options12.sep = true;

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
Kval = Zsol * inv(Psol, 0);

% % Optional:
tol = 1e-4;
Kval = clean_opvar(Kval, tol);

%% Build closed-loop PIE
nx = PIE.A.dim(:,1);
nw = PIE.B1.dim(:,2);
nz = PIE.C1.dim(:,1);

stateDim  = ioDimensions("x1", nx');
inputDim  = ioDimensions("w",  nw');
outputDim = ioDimensions("z",  nz');

Tcl   = gridBuilder(stateDim,  stateDim,  PIE.vars, PIE.dom);
Acl   = gridBuilder(stateDim,  stateDim,  PIE.vars, PIE.dom);
B1cl  = gridBuilder(stateDim,  inputDim,  PIE.vars, PIE.dom);
C1cl  = gridBuilder(outputDim, stateDim,  PIE.vars, PIE.dom);

Tcl(1,1)  = PIE.T;
Acl(1,1)  = PIE.A + PIE.B2*Kval;
B1cl(1,1) = PIE.B1;
C1cl(1,1) = PIE.C1 + PIE.D12*Kval;

data = struct();
data.misc = PIE.misc;
data.dim  = PIE.dim;
data.dom  = PIE.dom;
data.vars = PIE.vars;

data.T   = Tcl();
data.A   = Acl();
data.B1  = B1cl();
data.C1  = C1cl();
data.D11 = PIE.D11;

% Keep sensed outputs available in PIESIM
data.C2  = PIE.C2;
data.D21 = PIE.D21;

PIE_CL = pie_struct(data);
PIE_CL = initialize(PIE_CL);