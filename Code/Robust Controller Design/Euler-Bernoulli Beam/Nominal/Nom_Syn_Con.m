% DEMO6_Hinf_optimal_control.m
% See Chapter 11.6 of the manual for a description.
%
% This document illustrates how an Hinfty optimal controller can be designed
% for a PDE using the PIE/LPI framework.
% Specifically, we consider the following system:
% PDE:      \dot{x}(t,s) = (d^2/ds^2) x(t,s) + lam x(t,s) + w(t) + u(t),   s in [0,1];
% Outputs:       z(t)    = [int_{0}^{1} x(t,s) ds + w(t); u(t)];
% BCs:                0  = x(t,0) = d/ds x(t,1);
% (unstable for lam > pi^2/4)
% Letting v:=(d^2/ds^2)x, We derive an equivalent PIE of the form:
%   [T \dot{v}](t,s) = [A v](t,s) + [B1 w](t,s) + [B2 u](t,s);
%               z(t) = [C1 v](t)  + [D11 w](t) + [D12 u](t);
% Using a state feedback control u = K*v we get the closed loop PIE
%   [T \dot{v}](t,s) = [(A + B2*K) v](t,s) + [B1 w](t,s);
%               z(t) = [(C1 + D12*K) v](t) + [D11 w](t)
% To compute an operator K that minimizes the L2 gain from disturbance w to
% the output z, we solve the LPI
%   min_{gam,P,Z}   gam
%   s.t.            P>=0,
%       [ -gam*I            D11      (C1*P+D12*Z)*T'            ]
%       [  D11'            -gam*I    B1'                        ] <= 0
%       [  T*(C1*P+D12*Z)   B1       (A*P+B2*Z)*T'+T*(A*P+B2*Z)']
%
% Then, using K = Z*P^{-1}, the closed-loop system with u = K*v satisfies
%   ||z||_{L2}/||w||_{L2} <= gam
% We manually declare this LPI here, but it can also be solved using the
% "PIETOOLS_Hinf_control" executive file.
% We simulate the open loop and closed loop response of the PDE for various
% initial conditions using PIESIM.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS - DEMO6
%
% Copyright (C)2024  PIETOOLS Team
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% If you modify this code, document all changes carefully and include date
% authorship, and a brief description of modifications
%
% MP, SS, DJ, 2022: Initial coding;
% DJ, 10/20/2024: Update to use new LPI programming functions;
% DJ, 11/19/2024: Simplify demo (remove lines of code where possible, get
%                   rid of extra simulations);
% DJ, 12/15/2024: Use PIESIM_plotsolution to plot simulation results;
% DJ, 12/22/2024: Use piess;
% DB, 12/29/2024: Use pde_var objects instead of sys and state;
% YP, 02/17/2026: Renamed solution.final.ode/solution.final.pde into
% solution.final.primary{1,2}; renamed solution.timedep.ode/solution.timedep.pde into
% solution.timedep.primary{1,2}

clear; clc; close all; clear stateNameGenerator
echo off

% =============================================
% === Declare the system of interest
a = 0;
b = 1;
% % Declare system as PDE
% Declare independent variables (time and space)
pvar t s
% Declare state, input, and output variables
x1 = pde_var('state',1,s,[a,b]);
x2 = pde_var('state',1,s,[a,b]);
z = pde_var('output',1);
w = pde_var('input',1);          u = pde_var('control',1, s, [a,b]);
% Declare the sytem equations

PDE = [diff(x1,t) == -0.1*diff(x2,s,2) +u+s^2*w;
    diff(x2,t) == diff(x1, s, 2);
    z == [int((1-s)*x2,s,[a,b])];
    subs(x1,s,a)==0;
    subs(diff(x1,s,1),s,a) == 0;
    subs(x2,s,b) == 0;
    subs(diff(x2,s,1),s,b)==0];

display_PDE(PDE);


% % Convert PDE to PIE
PIE = convert(PDE);

Zero = @(r,c) zerosPI(uPIE,r,c);
Eye = @(n)    eyePI(uPIE, n);
prog = lpiprogram(PIE.vars(:, 1), PIE.vars(:, 2), PIE.dom);
settings = lpisettings('light');
settings.sos_settings.solver = 'mosek';
% settings.eppos2 = 1e-4;
% settings.options1.sep = 1;
% settings.options12.sep = 1;
% settings.ddZ = 2;

dpvar gam;
prog = lpidecvar(prog, gam); % set gam = gamma as decision variable
prog = lpi_ineq(prog, gam);  % enforce gamma>=0
prog = lpisetobj(prog, gam); % set gamma as objective function to minimize

coercive = true;
[prog, Z, P] = PIETOOLS_Construct_Nominal_Controller_Gain(prog, PIE, settings, coercive, gam, 0);

%solving the sos program
disp('- Solving the LPI using the specified SDP solver...');
prog = lpisolve(prog,settings.sos_opts);

disp('The H-infty gain from disturbance to error in estimated state is upper bounded by:')
if ~isreal(gam)
    disp(double(lpigetsol(prog,gam))); % check the Hinf norm, if the solved successfully
else
    disp(gam);
end

gam = double(lpigetsol(prog,gam));

P = lpigetsol(prog,P);
if ~coerciveCheck(P, settings)
    error('P is not coercive');
end
Z = lpigetsol(prog,Z);
% tol = 1e-10;
Kval = (Z*inv_opvar_2(P));

nx = PIE.A.dim(:,1); nw = PIE.B1.dim(:,2); nz = PIE.C1.dim(:,1);
stateDim    = ioDimensions("x1", nx');
inputDim    = ioDimensions("w", nw');
outputDim   = ioDimensions("z", nz');



T  = gridBuilder(stateDim,    stateDim,    PIE.vars, PIE.dom);
A  = gridBuilder(stateDim,    stateDim,    PIE.vars, PIE.dom);
B1  = gridBuilder(stateDim,    inputDim,    PIE.vars, PIE.dom);
C1 = gridBuilder(outputDim,   stateDim,    PIE.vars, PIE.dom);
D11  = gridBuilder(outputDim,   inputDim,    PIE.vars, PIE.dom);

T(1,1) = PIE.T;


A(1,1) = PIE.A + PIE.B2 * Kval;

B1(1,1) = PIE.B1;

C1(1,1) = PIE.C1 + PIE.D12*Kval;

data = struct();
data.misc = PIE.misc;
data.dim = PIE.dim;
data.dom = PIE.dom;
data.vars = PIE.vars;
data.T = T();
data.A = A();
data.B1 = B1();
data.C1 = C1();
data.D11 = PIE.D11;



PIE_CL = pie_struct(data);
PIE_CL = initialize(PIE_CL);


% =============================================
% === Simulate the system

% % Declare initial values and disturbance
syms st sx real
uinput.ic = 0;%sin(sx*pi/2);
uinput.w = sin(3 * (st - 1)) * exp(-(st - 1)) * heaviside(st-1);% heaviside(st-1) - heaviside(st-2);% 

% % Set options for discretization and simulation
opts.plot = 'yes';   % don't plot final solution
opts.N = 16;        % expand using 16 Chebyshev polynomials
opts.tf = 15;        % simulate up to t = 2
opts.dt = 1e-1;     % use time step of 10^-2

% % Perform the actual simulation
% Simulate uncontrolled PIE and extract solution
[solution_OL,grid] = PIESIM(PIE,opts,uinput);
tval = solution_OL.timedep.dtime;
x_OL = reshape(solution_OL.timedep.primary{2}(:,1,:),opts.N+1,[]);
z_OL = solution_OL.timedep.regulated{1}(1,:);
% Simulate controlled PIE and extract solution
[solution_CL,~] = PIESIM(PIE_CL,opts,uinput);
tval = solution_CL.timedep.dtime;
x_CL = reshape(solution_CL.timedep.primary{2}(:,1,:),opts.N+1,[]);
z_CL = solution_CL.timedep.regulated{1}(1,:);
% u_CL = solution_CL.timedep.regulated{1}(2,:);
w = double(subs(uinput.w,st,tval));