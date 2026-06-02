clear; clc; close all; clear stateNameGenerator
echo on

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
pvar s t;
echo off;
a=0;
b=1;
% Declare state, input, and output variables
x = pde_var(1,s,[a,b]);
zd1 = pde_var('output',1,s,[a,b]); wd1 = pde_var('input',1,s,[a,b]);
zd2 = pde_var('output',1,s,[a,b]); wd2 = pde_var('input',1,s,[a,b]);
z = pde_var('out');    w = pde_var('in');
y = pde_var('sense');
lam = 1;
% Declare the sytem equations
PDE = [diff(x,t) == diff(x,s,2) + lam*x + 0.5*w + wd1 + wd2;    % PDE
    zd1 == diff(x,s,2);
    zd2 == x;
    z == int(x,s,[a,b]);                 % regulated output
    y == subs(x,s,b);                        % observed output
    subs(x,s,a) == 0;                        % first boundary condition
    subs(diff(x,s),s,b) == 0];               % second boundary condition

display_PDE(PDE);

% % Convert PDE to PIE
PIE = convert(PDE);
data = struct();
data.misc = PIE.misc;
data.dim = PIE.dim;
data.dom = PIE.dom;
data.vars = PIE.vars;
data.T = PIE.T;
data.A = PIE.A; data.Bw = PIE.B1(1,1); data.Bd = PIE.B1(1,2:3);
data.Cd = PIE.C1(2:3,1); data.Dd = PIE.D11(2:3,2:3); data.Ddw = PIE.D22;
data.Cz = PIE.C1(1,1); data.Dzd = PIE.D22; data.Dzw = PIE.D11(1,1);
data.Cy = PIE.C2; data.Dyd = PIE.D22; data.Dyw = PIE.D21(1,1);
data.Dyd.dim = [1,0;0,2];
data.Ddw.dim = [0,1;2,0];
data.Dzd.dim = [1,0;0,2];
% 2. Convert it to a upie
uPIE = upie(data);
nx = uPIE.nx; nwd = uPIE.nwd; nw = uPIE.nw; nzd = uPIE.nzd; nz = uPIE.nz;
ny = uPIE.ny; nu = uPIE.nu;
Zero = @(r,c) zerosPI(uPIE,r,c);
Eye = @(n)    eyePI(uPIE, n);
%%
% Example: use bisection on gamma
gam_min = 0;       % set lower bound for gamma
gam_max = 100;       % set upper bound for gamma
gam =0.5 * (gam_min + gam_max);
% dpvar gamV gamVhat;

while (gam_max - gam_min) > 1e-3
    prog = lpiprogram(uPIE.vars(:, 1), uPIE.vars(:, 2), uPIE.dom);
    settings = lpisettings('light');
    settings.sos_settings.solver = 'mosek';

    % Construction of multipliers, should later be implemented in the
    % multiplier class by first constructing a Delta block and supplying this
    % to the constructor of the multiplier class.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for k = 1:2
        % V_opts.exclude = [0,0,1,1];
        [prog, P_blocks{k}] = poslpivar(prog, [0, 0; 1, 1], 3, settings.options1);
    end
    P = blkdiag(P_blocks{:});
    for k = 1:2
        % V_opts.exclude = [0,0,1,1];
        [prog, R_blocks{k}] = lpivar(prog, [0, 0; 1, 1], 3, settings.options1);
    end
    R = blkdiag(R_blocks{:});
    V = multiplier(P, gam*(R - R'), gam*(R' - R), -gam^2*P);
    Vhat = multiplier(Eye(uPIE.nz), Zero(uPIE.nz, uPIE.nw), Zero(uPIE.nw, uPIE.nz), -Eye(uPIE.nw));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    [prog, Dop, Z, Q] = PIETOOLS_Construct_SSV_Observer_LPI_Builder(prog, uPIE, V, Vhat, settings);

    prog = PIETOOLS_Solve_LPI(prog, Dop, settings);

    %Feasibility
    is_pinf = prog.solinfo.info.pinf;       % is primal feasible?
    is_dinf = prog.solinfo.info.dinf;       % is dual feasible?
    feasrat = prog.solinfo.info.feasratio;  % ratio should be close to 1

    if is_dinf || is_pinf || abs(feasrat-1)>0.1   % Stability cannot be verified --> decrease value of rho...
        feas = false;
    else
        % The system is stable --> try larger value of rho...
        feas = true;
    end
    if feas
        gam_max = gam;
        validated_gam = gam%(double(lpigetsol(prog,gamV)))
        % validated_V = V11;
        Q1 = lpigetsol(prog,Q1);
        Z = lpigetsol(prog,Z);
        Lval = getObserver(Q1',Z');
    else
        gam_min = gam;
    end
    gam = 0.5 * (gam_min + gam_max);
end
