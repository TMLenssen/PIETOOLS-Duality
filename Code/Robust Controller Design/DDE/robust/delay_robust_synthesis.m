
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
zd = pde_var('output', 2);
wd1 = pde_var('input');
wd2 = pde_var('input');
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
    diff(x4,t) == -wd1 - wd2 -(k2/m2)*x3 - (c2/m2)*x4 - (kc/m2)*(x3-x1)-(cc/m2)*(x4-x2) - (kt/m2)*(subs(ph2,s,b) - subs(ph1,s,b)) - (ct/m2)*(subs(ph4,s,b) - subs(ph3,s,b)) + (1/m2)*w;
    diff(ph1,t) == -(1/tau)*diff(ph1,s);
    diff(ph2,t) == -(1/tau)*diff(ph2,s);
    diff(ph3,t) == -(1/tau)*diff(ph3,s);
    diff(ph4,t) == -(1/tau)*diff(ph4,s);
    z  == [x3;x4;0.05*u];
    zd == [(0.2)*(kt/m2)*(subs(ph2,s,b) - subs(ph1,s,b)); (0.2)*(ct/m2)*(subs(ph4,s,b) - subs(ph3,s,b))];
    subs(ph1,s,a) == x1;
    subs(ph2,s,a) == x3;
    subs(ph3,s,a) == x2;
    subs(ph4,s,a) == x4];

display_PDE(PDE);

PIE = convert(PDE);
data = struct();
data.misc = PIE.misc;
data.dim = PIE.dim;
data.dom = PIE.dom;
data.vars = PIE.vars;
data.T = PIE.T;
data.A = PIE.A;             data.Bd = PIE.B1(:,1:2);        data.Bw = PIE.B1(:,3);      data.Bu = PIE.B2;
data.Cd = PIE.C1(4:5,:);    data.Dd = PIE.D11(4:5,1:2);     data.Ddw = PIE.D11(4:5,3);  data.Ddu = PIE.D12(4:5,:);
data.Cz = PIE.C1(1:3,:);    data.Dzd = PIE.D11(1:3,1:2);    data.Dzw = PIE.D11(1:3,3);  data.Dzu = PIE.D12(1:3,:);
data.Cy = PIE.C2;           data.Dyd = PIE.D21(:,1:2);      data.Dyw = PIE.D21(:,3);    data.Dyu = PIE.D22;

% 2. Convert it to a upie
uPIE = upie(data);
nx = uPIE.nx; nwd = uPIE.nwd; nw = uPIE.nw; nzd = uPIE.nzd; nz = uPIE.nz;
ny = uPIE.ny; nu = uPIE.nu;
Zero = @(r,c) zerosPI(r,c, uPIE.vars, uPIE.dom);
Eye = @(n)    eyePI(n, uPIE.vars, uPIE.dom);

%% Controller synthesis
settings = lpisettings('veryheavy');
settings.sos_settings.solver = 'mosek';
% settings.options1.sep  = true;
% settings.options12.sep = true;

% Edit these grids to trade multiplier richness against solve time.
rho_grid = -logspace(-3,3, 100);
r_grid = 0:3;

coercive = true;
alpha = 2;
tol = 1e-4;

if any(nwd ~= nzd)
    error('The current dynamic multiplier construction assumes nwd = nzd.');
end

num_rho = numel(rho_grid);
num_r = numel(r_grid);
gamma_grid = nan(num_rho, num_r);
feasible_grid = false(num_rho, num_r);
evaluated_grid = false(num_rho, num_r);
feasratio_grid = nan(num_rho, num_r);
pinf_grid = false(num_rho, num_r);
dinf_grid = false(num_rho, num_r);
message_grid = strings(num_rho, num_r);
K_grid = cell(num_rho, num_r);
Psol_grid = cell(num_rho, num_r);
Zsol_grid = cell(num_rho, num_r);

for i_rho = 1:num_rho
    rho = rho_grid(i_rho);
    for i_r = 1:num_r
        r = r_grid(i_r);

        if r == 0 && i_rho > 1
            gamma_grid(i_rho, i_r) = gamma_grid(1, i_r);
            feasible_grid(i_rho, i_r) = feasible_grid(1, i_r);
            feasratio_grid(i_rho, i_r) = feasratio_grid(1, i_r);
            pinf_grid(i_rho, i_r) = pinf_grid(1, i_r);
            dinf_grid(i_rho, i_r) = dinf_grid(1, i_r);
            K_grid{i_rho, i_r} = K_grid{1, i_r};
            Psol_grid{i_rho, i_r} = Psol_grid{1, i_r};
            Zsol_grid{i_rho, i_r} = Zsol_grid{1, i_r};
            message_grid(i_rho, i_r) = "Skipped: r = 0 is independent of rho; copied first rho result.";
            fprintf('\n- Skipping rho = %g, r = 0; static multiplier does not depend on rho.\n', rho);
            continue
        end

        fprintf('\n- Solving robust synthesis LPI for rho = %g, r = %d...\n', rho, r);

        prog = lpiprogram(PIE.vars(:,1), PIE.vars(:,2), PIE.dom);
        evaluated_grid(i_rho, i_r) = true;

        try
            V = construct_basis_multiplier(prog, r, nwd, settings);
            prog = V.prog;

            dpvar gam_dec
            prog = lpidecvar(prog, gam_dec);
            prog = lpi_ineq(prog, gam_dec);
            prog = lpisetobj(prog, gam_dec);

            [prog, Zdec, Pdec] = PIETOOLS_Construct_Robust_Controller_Gain(...
                prog, uPIE, V.multiplier, gam_dec, settings, coercive, alpha, rho, r);

            prog = lpisolve(prog, settings.sos_opts);
            [is_feasible, pinf_grid(i_rho, i_r), dinf_grid(i_rho, i_r), ...
                feasratio_grid(i_rho, i_r)] = solved_feasible(prog);

            if is_feasible
                gam_val = double(lpigetsol(prog, gam_dec));
                gamma_grid(i_rho, i_r) = gam_val;
                feasible_grid(i_rho, i_r) = true;

                Psol = lpigetsol(prog, Pdec);
                Zsol = lpigetsol(prog, Zdec);
                Psol_grid{i_rho, i_r} = Psol;
                Zsol_grid{i_rho, i_r} = Zsol;
                K_grid{i_rho, i_r} = recover_controller_gain(PIE, Psol, Zsol, r, nzd, nwd, tol);

                fprintf('  feasible, gamma = %.6g\n', gam_val);
            else
                message_grid(i_rho, i_r) = "Solver reported infeasible or unreliable status.";
                fprintf('  not accepted: pinf = %d, dinf = %d, feasratio = %.4g\n', ...
                    pinf_grid(i_rho, i_r), dinf_grid(i_rho, i_r), feasratio_grid(i_rho, i_r));
            end
        catch ME
            message_grid(i_rho, i_r) = string(ME.message);
            fprintf('  failed: %s\n', ME.message);
        end
    end
end

gamma_for_min = gamma_grid;
gamma_for_min(~feasible_grid) = inf;
[best_gamma, best_idx] = min(gamma_for_min(:));
if isempty(best_gamma) || ~isfinite(best_gamma)
    error('No feasible robust controller was found on the selected rho/r grid.');
end

[best_rho_idx, best_r_idx] = ind2sub(size(gamma_grid), best_idx);
best = struct();
best.rho = rho_grid(best_rho_idx);
best.r = r_grid(best_r_idx);
best.gamma = best_gamma;
best.Kval = K_grid{best_rho_idx, best_r_idx};
best.Psol = Psol_grid{best_rho_idx, best_r_idx};
best.Zsol = Zsol_grid{best_rho_idx, best_r_idx};
best.feasratio = feasratio_grid(best_rho_idx, best_r_idx);

Kval = best.Kval;
fprintf('\nBest feasible controller: rho = %g, r = %d, gamma = %.6g\n', ...
    best.rho, best.r, best.gamma);

results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
%% 

figure;
for i = 1:numel(r_grid)
subplot(1,numel(r_grid), i)
semilogx(rho_grid, gamma_grid(:,i));
ylim([1,3]);
end
%% 
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
gamma_file = fullfile(results_dir, ['delay_robust_gamma_grid_', timestamp, '.mat']);
controller_file = fullfile(results_dir, ['delay_robust_best_controller_', timestamp, '.mat']);
save(gamma_file, 'rho_grid', 'r_grid', 'gamma_grid', 'feasible_grid', ...
    'evaluated_grid', 'feasratio_grid', 'pinf_grid', 'dinf_grid', ...
    'message_grid', 'gamma_for_min', '-v7.3');
save(controller_file, 'best', 'Kval', 'PIE', 'uPIE', '-v7.3');

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

function Vdata = construct_basis_multiplier(prog, r, nwd, settings)
n_delta = finite_channel_count(nwd, 'nwd');
basis_dim = [r+1, r+1; 0, 0];
P_blocks = cell(n_delta, 1);
R_blocks = cell(n_delta, 1);

for k = 1:n_delta
    [prog, P_blocks{k}] = poslpivar(prog, basis_dim, 4, settings.options1);
end
Pmult = blkdiag(P_blocks{:});

for k = 1:n_delta
    [prog, R_blocks{k}] = lpivar(prog, basis_dim, 4, settings.options1);
end
Rmult = blkdiag(R_blocks{:});

Vdata.prog = prog;
Vdata.multiplier = multiplier(Pmult, (Rmult - Rmult'), (Rmult' - Rmult), -Pmult);
end

function Kval = recover_controller_gain(PIE, Psol, Zsol, r, nzd, nwd, tol)
nx = PIE.A.dim(:,1);
nu = PIE.B2.dim(:,2);
dimu = ioDimensions("u", nu');

if r == 0
    dimx = ioDimensions("x", nx');
else
    n_v1 = finite_channel_count(nzd, 'nzd');
    n_v2 = finite_channel_count(nwd, 'nwd');
    nxpsiz = [r*n_v1; 0];
    nxpsiw = [r*n_v2; 0];
    dimx = ioDimensions(["x", "xpsiz", "xpsiw"], [nx'; nxpsiz'; nxpsiw']);
end

Pgrid = gridBuilder(Psol, dimx, dimx);
Zgrid = gridBuilder(Zsol, dimu, dimx);
P11 = Pgrid(1,1);
Z11 = Zgrid(1,1);

Kval = Z11 * inv_opvar_2(P11);
Kval = clean_opvar(Kval, tol);
end

function [is_feasible, pinf, dinf, feasratio] = solved_feasible(prog)
info = prog.solinfo.info;
pinf = read_solver_flag(info, 'pinf');
dinf = read_solver_flag(info, 'dinf');
feasratio = nan;
if isfield(info, 'feasratio')
    feasratio = info.feasratio;
end

is_feasible = ~pinf && ~dinf;
if ~isnan(feasratio)
    is_feasible = is_feasible && abs(feasratio - 1) <= 0.1;
end
end

function flag = read_solver_flag(info, field_name)
flag = false;
if isfield(info, field_name)
    value = info.(field_name);
    if ~isempty(value)
        flag = logical(value);
    end
end
end

function n = finite_channel_count(dim, name)
if isscalar(dim)
    n = dim;
    return
end

if numel(dim) ~= 2 || dim(2) ~= 0
    error('%s must contain only finite-dimensional channels for this multiplier construction.', name);
end
n = dim(1);
end
