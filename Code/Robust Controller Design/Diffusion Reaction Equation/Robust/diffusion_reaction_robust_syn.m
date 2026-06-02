clear; clc; close all; clear stateNameGenerator
echo on

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
% Declare state, input, and output variables
x1 = pde_var(1,s,[a,b]);
x2 = pde_var('state');
zd1 = pde_var('output',1,s,[a,b]); wd1 = pde_var('input',1,s,[a,b]);
zd2 = pde_var('output',1,s,[a,b]); wd2 = pde_var('input',1,s,[a,b]);
z1 = pde_var('out');                w = pde_var('in');
z2 = pde_var('out');
y = pde_var('sense');              u = pde_var('control');
lam = 5;
dev = 0.8;
% Declare the sytem equations
PDE = [ diff(x1,t) == diff(x1,s,2) + lam*x1 + 0.1*w + dev*wd1 + dev*wd2;    % PDE
        diff(x2,t) == u;
        zd1 == diff(x1,s,2);
        zd2 == x1;
        z1 == x2;
        z2 == int(x1,s,[a,b]);                 % regulated output
        subs(x1,s,a) == 0;                        % first boundary condition
        subs(diff(x1,s,1),s,b) == x2];               % second boundary condition

display_PDE(PDE);

% % Convert PDE to PIE
PIE = convert(PDE);
data = struct();
data.misc = PIE.misc;
data.dim = PIE.dim;
data.dom = PIE.dom;
data.vars = PIE.vars;
data.T = PIE.T;
data.A = PIE.A;           data.Bd = PIE.B1(:,2:3);  data.Bw = PIE.B1(:,1); data.Bu = PIE.B2;
data.Cd = PIE.C1(3:4,:); data.Dd = PIE.D11(3:4,2:3); data.Ddw = PIE.D11(3:4,1); data.Ddu = PIE.D12(3:4,1);
data.Cz = PIE.C1(1:2,:);  data.Dzd = PIE.D11(1:2,2:3); data.Dzw = PIE.D11(1:2,1); data.Dzu = PIE.D12(1:2,1);



% 2. Convert it to a upie
uPIE = upie(data);
nx = uPIE.nx; nwd = uPIE.nwd; nw = uPIE.nw; nzd = uPIE.nzd; nz = uPIE.nz;
ny = uPIE.ny; nu = uPIE.nu;
Zero = @(r,c) zerosPI(r,c, uPIE.vars, uPIE.dom);
Eye = @(n)    eyePI(n, uPIE.vars, uPIE.dom);

%%

prog = lpiprogram(uPIE.vars(:, 1), uPIE.vars(:, 2), uPIE.dom);
settings = lpisettings('veryheavy');
% settings.dd1 = 4;
% settings.dd2 = 4;
% settings.dd3 = 4;
% settings.ddZ = 4;
% settings.dd12 = 4;
settings.ddM = 5;
settings.sos_settings.solver = 'mosek';


alpha = 0;
% Construction of multipliers, should later be implemented in the
% multiplier class by first constructing a Delta block and supplying this
% to the constructor of the multiplier class.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for k = 1:2
    % V_opts.exclude = [0,0,1,1];
    [prog, P_blocks{k}] = poslpivar(prog, [0, 0; 1, 1], settings.ddM, settings.options1);
end
P = blkdiag(P_blocks{:});
for k = 1:2
    % V_opts.exclude = [0,0,1,1];
    [prog, R_blocks{k}] = lpivar(prog, [0, 0; 1, 1], settings.ddM, settings.options1);
end
R = blkdiag(R_blocks{:});
V = multiplier(P, (R - R'), (R' - R), -P);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
coercive = 1;
% settings.options1.sep = 1;%coercive;
% settings.options12.sep = 1;%coercive;
settings.eppos2 = 0;%1e-4;
dpvar gam;
prog = lpidecvar(prog, gam); % set gam = gamma as decision variable
prog = lpi_ineq(prog, gam);  % enforce gamma>=0
prog = lpisetobj(prog, gam); % set gamma as objective function to minimize
[prog, Z, P] = PIETOOLS_Construct_Robust_Controller_Gain(prog, uPIE, V, gam, settings, coercive, alpha);

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
feasrat = prog.solinfo.info.feasratio;
P = lpigetsol(prog,P);
if ~coerciveCheck(P, settings)
    error('P is not coercive');
end
Z = lpigetsol(prog,Z);
Kval = (Z*inv_opvar_2(P));
%% 
% Declare the sytem equations
PDE = [ diff(x1,t) == (1-dev)*diff(x1,s,2) + (lam+dev)*x1 + 0.1*w;    % PDE
        diff(x2,t) == u;
        z1 == x2;
        z2 == int(x1,s,[a,b]);                 % regulated output
        subs(x1,s,a) == 0;                        % first boundary condition
        subs(diff(x1,s,1),s,b) == x2];               % second boundary condition

display_PDE(PDE);

% % Convert PDE to PIE
PIE = convert(PDE);
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

C1(1,1) = PIE.C1 + PIE.D11*Kval;

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
uinput.w = heaviside(st-1) - heaviside(st-2);% sin(5 * (st - 1)) * exp(-(st - 1)) * heaviside(st-1);

% % Set options for discretization and simulation
opts.plot = 'yes';   % don't plot final solution
opts.N = 16;        % expand using 16 Chebyshev polynomials
opts.tf = 15;        % simulate up to t = 2
opts.dt = 1e-3;     % use time step of 10^-2

% % Perform the actual simulation
% Simulate uncontrolled PIE and extract solution
[solution_OL,grid] = PIESIM(PIE,opts,uinput);
% tval = solution_OL.timedep.dtime;
x_OL = reshape(solution_OL.timedep.primary{2}(:,1,:),opts.N+1,[]);
z_OL = solution_OL.timedep.regulated{1}(1,:);
% Simulate controlled PIE and extract solution
[solution_CL,~] = PIESIM(PIE_CL,opts,uinput);
tval = solution_CL.timedep.dtime;
x_CL = reshape(solution_CL.timedep.primary{2}(:,1,:),opts.N+1,[]);
z_CL = solution_CL.timedep.regulated{1}(1,:);
u_CL = solution_CL.timedep.regulated{1}(2,:);
wval = double(subs(uinput.w,st,tval));
