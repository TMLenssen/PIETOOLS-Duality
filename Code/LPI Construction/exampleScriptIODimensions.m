clear; clc; close all; clear stateNameGenerator
echo on

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
pvar s t;
echo off;

a = 0;
b= 1;

x1 = pde_var('state',1); x2 = pde_var('state',1); x3 = pde_var(1,s,[a,b]); x4 = pde_var(1,s,[a,b]);
zd1 = pde_var('output', 1, s, [a,b]); wd1 = pde_var('input', 1, s, [a,b]);
w = pde_var('input',1);
z1 = pde_var('output',1); z2 = pde_var('output',1);
y1 = pde_var('sense',1); y2 = pde_var('sense',1);
tau = 0.5;%

% %---------------------------------------------------------------------% %
% % Example DDE from  K. Gu, J. Chen, and V. L. Kharitonov, Stability of Time-Delay Systems example 5.11:
% % DDE             x_{tt}(t) = 0.1*x_{t}(t) -2*x(t) - x(t-tau)
% % Conversion to ODE-PDE:
% % ODE             x1_{t}(t) = x_2(t)
% %                 x2_{t}(t) = -2*x1(t) + 0.1*x2(t) + x3(t,1)
% % PDE             x3_{t}(t,s) = -tau^-1*x3_s(t,s)
% % with SC         x3(t,0) = x1(t);
% %
% % Then we construct the LFR
% % ODE             x1_{t}(t) = x_2(t)
% %                 x2_{t}(t) = -2*x1(t) + 0.1*x2(t) + x3(t,1)
% % PDE             x3_{t}(t,s) = -tau^-1*x3_{s}(t,s) + wd
% %                 zd(t,s) = x3_{s}(t,s)
% %                 with wd = \delta zd, \delta \in [-\gamma^-1, \gamma^-1]
% % with SC         x3(t,0) = x1(t);
% %
% % then            \tau_{max} = (\tau^-1 + \gamma^-1), \tau_{min} =
% (\tau^-1 - \gamma^-1)
% %---------------------------------------------------------------------% %
PDE = [diff(x1,t) == x2;
    diff(x2,t) == -2*x1 + 0.1*x2 + subs(x3,s,b) + 0.1*w;
    diff(x3,t) == -tau^-1*diff(x3,s,1) + wd1;
    zd1 == diff(x3,s,1);
    z1 == int(x3,s,[a,b]);
    subs(x3,s,a) == x1]


PIE = convert(PDE, 'pie');
data = struct();

data.misc = PIE.misc;
data.dim = PIE.dim;
data.dom = PIE.dom;
data.vars = PIE.vars;
data.T = PIE.T;
data.A = PIE.A; data.Bw = PIE.B1(:,1); data.Bd = PIE.B1(:,2);
data.Cd = PIE.C1(2,:); data.Dd = PIE.D11(2,2); data.Ddw = PIE.D11(2,1);
data.Cz = PIE.C1(1,:); data.Dzd = PIE.D11(1,2); data.Dzw = PIE.D11(1,1);

% 2. Convert it to a upie
uPIE = upie(data);

% Create manager instance
inputDimensions = ioDimensions();

% Add some variables
inputDimensions.add("wd", uPIE.nwd);
inputDimensions.add("w", uPIE.nw);
inputDimensions.add("u", uPIE.nu);

% Display current list
inputDimensions.display();

% Try to add duplicate with same dimensions (warning)
fprintf('\n--- Adding duplicate with same dimensions ---\n');
inputDimensions.add("wd", uPIE.nwd);

% Try to add duplicate with different dimensions (error)
fprintf('\n--- Adding duplicate with different dimensions ---\n');
try
    inputDimensions.add("wd", uPIE.nw);
catch ME
    fprintf('Error caught: %s\n', ME.message);
end


% Display updated list
fprintf('\n--- Updated list ---\n');
inputDimensions.display();

% Get specific variable dimensions
fprintf('\n--- Get specific variable dimensions ---\n');
try
    dims = inputDimensions.dimension('wd');
    fprintf('Uncertainty Input dimensions: [%d, %d]\n', dims(1), dims(2));
catch ME
    fprintf('Error: %s\n', ME.message);
end

% Get variable count
fprintf('\nTotal variables: %d\n', inputDimensions.count());

% Test non-existent variable
fprintf('\n--- Testing non-existent variable ---\n');
try
    dims = inputDimensions.dimension('nonexistent');
catch ME
    fprintf('Error: %s\n', ME.message);
end

% Clear list
fprintf('\n--- Clearing list ---\n');
inputDimensions.clear();
inputDimensions.display();