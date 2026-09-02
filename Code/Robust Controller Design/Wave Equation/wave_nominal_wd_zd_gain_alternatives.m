clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));

%% Induced L2 gain from wDelta to zDelta for all wave realizations
pvar t s
a = 0;
b = 1;
d = 1;
lam = s*(1-s);
damp = 2;

% Global bounds for wDelta = sin(zDelta).
alpha = -0.217234;
beta = 1;
hatalpha = -1;
hatbeta = 1;
sectorGain = max(abs([alpha,beta]));
slopeGain = max(abs([hatalpha,hatbeta]));

% For wDelta = sin(zDelta), ||wDelta||_2 <= ||zDelta||_2.
% Hence a certified gain below one satisfies the small-gain condition.
formulations = ["standard"; "eta_v"; "phi"];
gamma = nan(size(formulations));
feasible = false(size(formulations));
controller = cell(size(formulations));

for k = 1:numel(formulations)
    clear stateNameGenerator
    name = formulations(k);
    fprintf('\n--- %s formulation ---\n',name);

    PIE = wave_gain_plant(name,a,b,d,lam,damp,t,s);

    settings = lpisettings('veryheavy');
    settings.sos_opts.solver = 'mosek';
    settings.options1.sep = 1;
    settings.options12.sep = 1;

    [prog,controller{k},gamma(k)] = PIETOOLS_Hinf_control(PIE,settings);
    info = prog.solinfo.info;
    feasible(k) = info.pinf==0 && info.dinf==0 ...
        && info.numerr<=1 && abs(info.feasratio-1)<=0.3;

    fprintf('feasible = %d, gamma(wDelta -> zDelta) = %.10g\n', ...
        feasible(k),gamma(k));
end

sectorProduct = gamma*sectorGain;
slopeProduct = gamma*slopeGain;
sectorTest = feasible & sectorProduct<1;
slopeTest = feasible & slopeProduct<1;
results = table(formulations,gamma,feasible,sectorProduct,slopeProduct, ...
    sectorTest,slopeTest, ...
    'VariableNames',{'Formulation','Gamma','Feasible', ...
    'GammaTimesSector','GammaTimesSlope','SectorTest','SlopeTest'});

fprintf('\n');
disp(results)


function PIE = wave_gain_plant(formulation,a,b,d,lam,damp,t,s)
% All formulations describe
%   z_tt = d*z_ss - damp*z_t + lam*wDelta,
%   zDelta = z,
% with z(t,0)=0, z_s(t,1)=x(t), and x_t=u.

switch formulation
    case "standard"
        x = pde_var('state',1,[],[]);
        z = pde_var(s,[a,b]);
        zt = pde_var(s,[a,b]);
        zDelta = pde_var('output',1,s,[a,b]);
        wDelta = pde_var('input',1,s,[a,b]);
        u = pde_var('control',1);

        PDE = [diff(z,t) == zt;
            diff(zt,t) == d*diff(z,s,2)-damp*zt+lam*wDelta;
            diff(x,t) == u;
            zDelta == z;
            subs(z,s,a) == 0;
            subs(zt,s,a) == 0;
            subs(diff(z,s),s,b) == x];

    case "eta_v"
        x = pde_var('state',1,[],[]);
        eta = pde_var(s,[a,b]);
        v = pde_var(s,[a,b]);
        zDelta = pde_var('output',1,s,[a,b]);
        wDelta = pde_var('input',1,s,[a,b]);
        u = pde_var('control',1);

        PDE = [diff(x,t) == u;
            diff(eta,t) == diff(eta,s)+v;
            diff(v,t) == (d-1)*diff(eta,s,2)-diff(v,s) ...
                -damp*(diff(eta,s)+v)+lam*wDelta;
            zDelta == eta;
            subs(diff(eta,s),s,b) == x;
            subs(eta,s,a) == 0;
            subs(v,s,a) == -subs(diff(eta,s),s,a)];

    case "phi"
        x = pde_var('state',1,[],[]);
        phi = pde_var('state',2,s,[a,b]);
        zDelta = pde_var('output',1,s,[a,b]);
        wDelta = pde_var('input',1,s,[a,b]);
        u = pde_var('control',1);

        zRecovered = int([1 0]*phi,s,[a,s]);
        PDE = [diff(x,t) == u;
            diff(phi,t) == [0 1;d 0]*diff(phi,s) ...
                -[0;damp]*([0 1]*phi)+[0;lam]*wDelta;
            zDelta == zRecovered;
            [0 1]*subs(phi,s,a) == 0;
            [1 0]*subs(phi,s,b) == x];

    otherwise
        error('Unknown formulation: %s',formulation);
end

PIE = convert(PDE);
end
