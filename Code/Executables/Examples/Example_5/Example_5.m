clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE));
addpath(genpath('C:\Program Files\Mosek\11.0\toolbox\r2019b'));
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Settings
analysisMode = 'dual';       % 'primal' or 'dual'
lambdaLower = 0;
lambdaUpper = 12.3;            % Diseased wGG value
lambdaSearchLimit = 12.3;
lambdaTolerance = 2e-2;
runSimulation = true;
plotSimulation = true;
simulationFinalTime = 0.5;

settings = lpisettings('veryheavy');
settings.sos_opts.solver = 'mosek';
settings.ddM = 4;
settings.multiplierUpper = 1e4;
settings.inverseFloor = 1e-8;
settings.kypMarginUpper = 100;
settings.kypSlackMode = 'normal';
settings.options1.sep = 0;
settings.options12.sep = 0;

%% Reduced GPe model and fixed uncertainty description
% lambda=wGG is varied in the known plant, while Delta_G and its IQC remain
% fixed. The original uncertainty interconnection is
%
%   xGdot        = (Delta_G(zDelta)-xG)/tauG,
%   zDelta       = -lambda*psiGG(t,1),
%   psiGG(t,0)   = xG.
tauG = 14e-3;
tauGG = 4e-3;
betaG = 1;                     % Selected global slope bound
zGEquilibrium = -186.4043087303;
maximumFiringRate = 400;

lambdaSector = 0;
lambdaZF = 1;
epsilonIQC = 1e-8;
multiplier = zf_multiplier(betaG,lambdaSector,lambdaZF,epsilonIQC);

%% Find the largest certified open-loop lambda in the search interval
trialLog = zeros(0,6);
bestTest = struct([]);
lowerTest = analyze_lambda(lambdaLower,tauG,tauGG,analysisMode, ...
    settings,multiplier);
trialLog(end+1,:) = trial_row(lowerTest); %#ok<SAGROW>

if lowerTest.feasible
    bestTest = lowerTest;
    upperTest = analyze_lambda(lambdaUpper,tauG,tauGG,analysisMode, ...
        settings,multiplier);
    trialLog(end+1,:) = trial_row(upperTest); %#ok<SAGROW>
    while upperTest.feasible && lambdaUpper<lambdaSearchLimit
        lambdaLower = lambdaUpper;
        bestTest = upperTest;
        lambdaUpper = min(2*lambdaUpper,lambdaSearchLimit);
        upperTest = analyze_lambda(lambdaUpper,tauG,tauGG,analysisMode, ...
            settings,multiplier);
        trialLog(end+1,:) = trial_row(upperTest);
    end
    searchBoundReached = upperTest.feasible;
    if searchBoundReached
        lambdaLower = lambdaUpper;
        bestTest = upperTest;
    else
        while lambdaUpper-lambdaLower > lambdaTolerance
            lambdaTrial = 0.5*(lambdaLower+lambdaUpper);
            trial = analyze_lambda(lambdaTrial,tauG,tauGG,analysisMode, ...
                settings,multiplier);
            trialLog(end+1,:) = trial_row(trial); %#ok<SAGROW>
            if trial.feasible
                lambdaLower = lambdaTrial;
                bestTest = trial;
            else
                lambdaUpper = lambdaTrial;
            end
        end
    end
else
    searchBoundReached = false;
end

%% Simulate the original nonlinear open loop at the last certificate
simulation = struct([]);
if runSimulation && ~isempty(bestTest)
    deltaG = @(z) centered_sigmoid(zGEquilibrium+z,maximumFiringRate) ...
        -centered_sigmoid(zGEquilibrium,maximumFiringRate);
    Psimulation = gpe_plant(lambdaLower,tauG,tauGG,false);
    simulation = simulate_nonlinear_plant(Psimulation,deltaG, ...
        simulationFinalTime,5);
    if plotSimulation
        plot_open_loop_simulation(simulation,lambdaLower);
    end
end

%% Results overview
fprintf('\nExample 5: reduced GPe open-loop robust-stability analysis\n');
fprintf('Analysis mode:                       %s\n',analysisMode);
fprintf('Uncertainty interconnection:         wDelta = Delta_G(zDelta)\n');
fprintf('Searched parameter:                  lambda = wGG\n');
fprintf('Fixed slope bound betaG:             %.10g\n',betaG);
fprintf('Zames--Falb kernel L1 norm:          %.10g\n',multiplier.hNormL1);
fprintf('Zames--Falb norm condition <= 1:     %d\n',multiplier.hNormL1<=1);
fprintf('Number of PIETOOLS IQC tests:        %d\n',size(trialLog,1));
fprintf('\n  lambda      feasible      residual       feasratio   numerr          mu\n');
fprintf('  %8.4f       %d          %9.2e       %8.4f      %g      %9.3e\n', ...
    trialLog.');

if isempty(bestTest)
    fprintf('\nNo feasible certificate was found at lambda = %.6g.\n',lambdaLower);
elseif searchBoundReached
    fprintf('\nCertified for all tested lambda in [0, %.6g].\n',lambdaLower);
    fprintf('The search cap lambdaSearchLimit = %.6g was reached.\n', ...
        lambdaSearchLimit);
else
    fprintf('\nCertified open-loop transition interval: [%.6g, %.6g]\n', ...
        lambdaLower,lambdaUpper);
end
if ~isempty(simulation)
    fprintf('Simulated final/initial |xG| ratio:  %.6g\n', ...
        abs(simulation.xG(end))/max(abs(simulation.xG(1)),eps));
end

Results = struct('certifiedLower',lambdaLower, ...
    'infeasibleUpper',lambdaUpper,'searchBoundReached',searchBoundReached, ...
    'analysisMode',analysisMode,'betaG',betaG, ...
    'zfKernelL1Norm',multiplier.hNormL1,'trials',trialLog, ...
    'bestTest',bestTest,'simulation',simulation, ...
    'PiDelta',multiplier.PiDelta,'PsiPrimal',multiplier.PsiPrimal, ...
    'PsiDual',multiplier.PsiDual);

function result = analyze_lambda(lambda,tauG,tauGG,analysisMode,settings,multiplier)
P = gpe_plant(lambda,tauG,tauGG,false);
Theta.primal = factor_box(multiplier.PsiPrimal,P.vars,P.dom);
Theta.dual = factor_box(multiplier.PsiDual,P.vars,P.dom);
switch lower(analysisMode)
    case 'primal'
        G = PIETOOLS_IQC_primal_graph(P,Theta.primal);
    case 'dual'
        G = PIETOOLS_IQC_dual_graph(P,Theta.dual);
    otherwise
        error('analysisMode must be ''primal'' or ''dual''.');
end

prog = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,mu] = poslpivar(prog,[1;0],0);
mu = mu+settings.inverseFloor*eyePI([1;0],P.vars,P.dom);
V = blkdiag(mu,-mu);
[storage,prog] = PIETOOLS_IQC_analysis(prog,settings,G,V);

result = certificate(prog);
result.lambda = lambda;
result.mu = solution_scalar(prog,mu);
result.P = P;
result.graph = G;
result.storage = storage;
result.program = prog;
end

function P = gpe_plant(lambda,tauG,tauGG,withControl)
pvar t s
xG = pde_var('state');
psiGG = pde_var(s,[0,1]);
zDelta = pde_var('output',1);
wDelta = pde_var('input',1);
if withControl
    u = pde_var('control',1);
    xEquation = diff(xG,t) == (1/tauG)*(wDelta-xG)+u;
else
    xEquation = diff(xG,t) == (1/tauG)*(wDelta-xG);
end
PDE = [xEquation;
       diff(psiGG,t) == -(1/tauGG)*diff(psiGG,s);
       zDelta == -lambda*subs(psiGG,s,1);
       subs(psiGG,s,0) == xG];
PDE = initialize(PDE,true);
[~,order] = reorder_comps(PDE,'all',true);
assert(isequal(order.z(:),1) && isequal(order.w(:),1), ...
    'Unexpected uncertainty-channel ordering.');
P = convert_PIETOOLS_PDE(PDE,order,{'silent'});
end

function multiplier = zf_multiplier(beta,lambdaSector,lambdaZF,epsilonIQC)
q = tf('s');
b = [50,150,500];
k = [20,40,100];
assert(all(b>0) && all(k>=0), ...
    'The analytic L1-norm check requires nonnegative exponential kernels.');
H = 0;
for i = 1:numel(b)
    H = H+k(i)/(q+b(i));
end
multiplier.hNormL1 = sum(k./b);
assert(multiplier.hNormL1<=1+1e-12, ...
    'Invalid Zames--Falb kernel: ||H||_1 = %.6g exceeds one.', ...
    multiplier.hNormL1);
M = minreal(ss(1-H),1e-9);

alpha = 0;
T = [beta,-1;-alpha,1];
PiSector = T'*[0,1;1,0]*T;
PiZF = [0,beta*M';beta*M,-(M+M')];
PiNorm = diag([1,-1]);
multiplier.PiDelta = minreal(ss(lambdaSector*PiSector+ ...
    lambdaZF*PiZF+epsilonIQC*PiNorm),1e-9);
[multiplier.PsiPrimal,multiplier.PsiDual] = ...
    jfactor(multiplier.PiDelta,1,1);
end

function sim = simulate_nonlinear_plant(P,deltaG,tFinal,initialDeviation)
tgrid = linspace(0,tFinal,1001).';
x0.ode = initialDeviation;
x0.pde = {initialDeviation};
opts.N = 24;
opts.nwd0 = 1;
opts.splot = linspace(0,1,151).';
opts.ode = odeset('RelTol',1e-7,'AbsTol',1e-9);
sim = PIE_sim_nl(P,deltaG,tgrid,x0,opts);
sim = reconstruct_gpe_state(sim,1);
end

function sim = reconstruct_gpe_state(sim,xGIndex)
primary = sim.Dop.Tcheb_2PDEstate*sim.x.';
sim.xG = primary(xGIndex,:).';
numberOfSpatialPoints = numel(sim.splot);
sim.psiGG = zeros(numel(sim.t),numberOfSpatialPoints);
E = chebyshev_evaluation(2*sim.splot-1,size(primary,1)-xGIndex-1);
for timeIndex = 1:numel(sim.t)
    sim.psiGG(timeIndex,:) = ...
        real(E*primary(xGIndex+1:end,timeIndex)).';
end
end

function E = chebyshev_evaluation(points,degree)
points = points(:);
E = zeros(numel(points),degree+1);
E(:,1) = 1;
if degree>=1
    E(:,2) = points;
end
for k = 2:degree
    E(:,k+1) = 2*points.*E(:,k)-E(:,k-1);
end
end

function plot_open_loop_simulation(sim,lambda)
figure('Color','w','Units','inches','Position',[1,1,7,7]);
layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile(layout,[2,1]);
surf(sim.splot,sim.t,sim.psiGG,'EdgeColor','none');
xlabel('s'); ylabel('t [s]'); zlabel('\psi_{GG}(t,s)');
title(sprintf('Open loop, \\lambda=%.4g',lambda));
view(40,30); axis tight; colorbar;
nexttile;
plot(sim.t,sim.xG,'LineWidth',1.4);
xlabel('t [s]'); ylabel('x_G(t)'); grid on;
nexttile;
plot(sim.t,sim.zFinite,'LineWidth',1.4); hold on;
plot(sim.t,sim.wdFinite,'--','LineWidth',1.4); hold off;
xlabel('t [s]'); ylabel('Uncertainty signals');
legend('z_\Delta','w_\Delta','Location','best'); grid on;
end

function value = centered_sigmoid(input,maximumRate)
value = maximumRate./(1+exp(-4*input/maximumRate))-maximumRate/2;
end

function cert = certificate(prog)
info = prog.solinfo.info;
cert.feasratio = double(info.feasratio);
cert.pinf = double(info.pinf);
cert.dinf = double(info.dinf);
cert.numerr = double(info.numerr);
cert.residual = double(prog.solinfo.residual);
cert.feasible = cert.pinf==0 && cert.dinf==0 && cert.numerr<=1 ...
    && isfinite(cert.feasratio) && abs(cert.feasratio-1)<=0.3 ...
    && isfinite(cert.residual);
end

function value = solution_scalar(prog,variable)
value = NaN;
try
    solution = lpigetsol(prog,variable);
    value = double(solution.P);
catch
end
end

function row = trial_row(trial)
row = [trial.lambda,trial.feasible,trial.residual, ...
    trial.feasratio,trial.numerr,trial.mu];
end

function Box = factor_box(sys,vars,dom)
[A,B,C,D] = ssdata(sys);
Box.T = matrix_operator(eye(size(A,1)),vars,dom);
Box.A = matrix_operator(A,vars,dom);
Box.B1 = matrix_operator(B(:,1),vars,dom);
Box.B2 = matrix_operator(B(:,2),vars,dom);
Box.C1 = matrix_operator(C(1,:),vars,dom);
Box.C2 = matrix_operator(C(2,:),vars,dom);
Box.D11 = matrix_operator(D(1,1),vars,dom);
Box.D12 = matrix_operator(D(1,2),vars,dom);
Box.D21 = matrix_operator(D(2,1),vars,dom);
Box.D22 = matrix_operator(D(2,2),vars,dom);
end

function op = matrix_operator(value,vars,dom)
op = mat2opvar(value,[size(value,1),size(value,2)],vars,dom);
end
