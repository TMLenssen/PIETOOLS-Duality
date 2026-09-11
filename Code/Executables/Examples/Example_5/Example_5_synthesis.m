clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE));
addpath(genpath('C:\Program Files\Mosek\11.0\toolbox\r2019b'));
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Settings
lambdaLower = 0;
lambdaUpper = 12.3;            % Diseased wGG value
lambdaSearchLimit = 123;
lambdaTolerance = 1e-1;
runSimulation = true;
plotSimulation = true;
simulationFinalTime = 0.5*1e-1;

settings = lpisettings('light');
settings.sos_opts.solver = 'mosek';
settings.ddM = 2;
settings.multiplierUpper = 1e4;
settings.inverseFloor = 1e-8;
settings.kypMarginUpper = 100;
settings.kypSlackMode = 'normal';
settings.kmax = 1e4;
settings.controllerCleanTol = 1e-10;
settings.options1.sep = 1;
settings.options12.sep = 1;

%% Reduced GPe model, control channel, and fixed uncertainty description
% The control input enters only the lumped state equation:
%
%   xGdot        = (Delta_G(zDelta)-xG)/tauG + u,
%   zDelta       = -lambda*psiGG(t,1),
%   psiGG(t,0)   = xG.
%
% In particular, the transport boundary contains no input.
tauG = 14e-3;
tauGG = 4e-3;
betaG = 1;                     % Selected global slope bound
zGEquilibrium = -186.4043087303;
maximumFiringRate = 400;

lambdaSector = 1;
lambdaZF = 0;
epsilonIQC = 1e-8;
multiplier = zf_multiplier(betaG,lambdaSector,lambdaZF,epsilonIQC);

%% Find the largest certified closed-loop lambda in the search interval
trialLog = zeros(0,6);
bestTest = struct([]);
lowerTest = synthesize_lambda(lambdaLower,tauG,tauGG,settings,multiplier);
trialLog(end+1,:) = trial_row(lowerTest); %#ok<SAGROW>

if lowerTest.feasible
    bestTest = lowerTest;
    upperTest = synthesize_lambda(lambdaUpper,tauG,tauGG,settings,multiplier);
    trialLog(end+1,:) = trial_row(upperTest); %#ok<SAGROW>
    while upperTest.feasible && lambdaUpper<lambdaSearchLimit
        lambdaLower = lambdaUpper;
        bestTest = upperTest;
        lambdaUpper = min(2*lambdaUpper,lambdaSearchLimit);
        upperTest = synthesize_lambda(lambdaUpper,tauG,tauGG,settings,multiplier);
        trialLog(end+1,:) = trial_row(upperTest);
    end
    searchBoundReached = upperTest.feasible;
    if searchBoundReached
        lambdaLower = lambdaUpper;
        bestTest = upperTest;
    else
        while lambdaUpper-lambdaLower > lambdaTolerance
            lambdaTrial = 0.5*(lambdaLower+lambdaUpper);
            trial = synthesize_lambda(lambdaTrial,tauG,tauGG,settings,multiplier);
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

%% Simulate the original nonlinear open and controlled systems
simOpen = struct([]);
simClosed = struct([]);
if runSimulation && ~isempty(bestTest)
    deltaG = @(z) centered_sigmoid(zGEquilibrium+z,maximumFiringRate) ...
        -centered_sigmoid(zGEquilibrium,maximumFiringRate);
    Psimulation = gpe_plant(lambdaLower,tauG,tauGG,true);
    ThetaPrimal = factor_box(multiplier.PsiPrimal, ...
        Psimulation.vars,Psimulation.dom);
    simOpen = simulate_open_loop(Psimulation,deltaG, ...
        simulationFinalTime,5);
    simClosed = simulate_controlled_loop(Psimulation,ThetaPrimal, ...
        bestTest.K,deltaG,simulationFinalTime,5);
    if plotSimulation
        plot_closed_loop_simulation(simOpen,simClosed,lambdaLower);
    end
end

%% Results overview
fprintf('\nExample 5: reduced GPe robust-stability synthesis\n');
fprintf('Uncertainty interconnection:         wDelta = Delta_G(zDelta)\n');
fprintf('Searched parameter:                  lambda = wGG\n');
fprintf('Control location:                    xGdot equation only\n');
fprintf('Fixed slope bound betaG:             %.10g\n',betaG);
fprintf('Zames--Falb kernel L1 norm:          %.10g\n',multiplier.hNormL1);
fprintf('Zames--Falb norm condition <= 1:     %d\n',multiplier.hNormL1<=1);
fprintf('Controller norm bound:               %.6g\n',settings.kmax);
fprintf('Number of PIETOOLS IQC tests:        %d\n',size(trialLog,1));
fprintf('\n  lambda      feasible      residual       feasratio   numerr          mu\n');
fprintf('  %8.4f       %d          %9.2e       %8.4f      %g      %9.3e\n', ...
    trialLog.');

if isempty(bestTest)
    fprintf('\nNo feasible controller was found at lambda = %.6g.\n',lambdaLower);
elseif searchBoundReached
    fprintf('\nCertified closed-loop stability for all tested lambda in [0, %.6g].\n', ...
        lambdaLower);
    fprintf('The search cap lambdaSearchLimit = %.6g was reached.\n', ...
        lambdaSearchLimit);
else
    fprintf('\nCertified closed-loop transition interval: [%.6g, %.6g]\n', ...
        lambdaLower,lambdaUpper);
end
if ~isempty(simClosed)
    fprintf('Open-loop final/initial |xG| ratio:  %.6g\n', ...
        abs(simOpen.xG(end))/max(abs(simOpen.xG(1)),eps));
    fprintf('Closed-loop final/initial |xG| ratio: %.6g\n', ...
        abs(simClosed.xG(end))/max(abs(simClosed.xG(1)),eps));
end

if isempty(bestTest)
    K = [];
else
    K = bestTest.K;
end
Results = struct('certifiedLower',lambdaLower, ...
    'infeasibleUpper',lambdaUpper,'searchBoundReached',searchBoundReached, ...
    'betaG',betaG,'zfKernelL1Norm',multiplier.hNormL1, ...
    'controllerNormBound',settings.kmax,'trials',trialLog, ...
    'bestTest',bestTest,'K',K,'simOpen',simOpen,'simClosed',simClosed, ...
    'PiDelta',multiplier.PiDelta,'PsiPrimal',multiplier.PsiPrimal, ...
    'PsiDual',multiplier.PsiDual);

function result = synthesize_lambda(lambda,tauG,tauGG,settings,multiplier)
P = gpe_plant(lambda,tauG,tauGG,true);
Theta.dual = factor_box(multiplier.PsiDual,P.vars,P.dom);

prog = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,mu] = poslpivar(prog,[1;0],0);
mu = mu+settings.inverseFloor*eyePI([1;0],P.vars,P.dom);
Vdual = blkdiag(mu,-mu);
[K,Z,storage,prog] = PIETOOLS_IQC_controller_synthesis(prog,settings,P,Theta,Vdual);

result = certificate(prog);
result.lambda = lambda;
result.mu = solution_scalar(prog,mu);
result.K = K;
result.Z = Z;
result.P = P;
result.storage = storage;
result.program = prog;
if ~result.feasible
    result.K = [];
end
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

function sim = simulate_open_loop(P,deltaG,tFinal,initialDeviation)
tgrid = linspace(0,tFinal,1001).';
x0.ode = initialDeviation;
x0.pde = {initialDeviation};
opts = simulation_options();
sim = PIE_sim_nl(P,deltaG,tgrid,x0,opts);
sim = reconstruct_gpe_state(sim,1,1);
end

function sim = simulate_controlled_loop(P,Theta,K,deltaG,tFinal,initialDeviation)
G = PIETOOLS_IQC_primal_graph(P,Theta,K);
zeroTheta = matrix_operator(zeros(sum(P.C1.dim(:,1)), ...
    sum(Theta.T.dim(:,2))),P.vars,P.dom);
Cz = block_hcat(P.C1,zeroTheta,P.vars,P.dom)+P.D12*K;

% Replace the filtered IQC outputs by the physical zDelta output required
% to close the original nonlinearity during simulation.
G.C1 = Cz;
G.D11 = P.D11;
G.x_tab = P.x_tab;
emptyDimension = [0;0];
G.Tw = zero_operator(G.T.dim(:,1),G.B1.dim(:,2),G.vars,G.dom);
G.B2 = zero_operator(G.T.dim(:,1),emptyDimension,G.vars,G.dom);
G.Tu = zero_operator(G.T.dim(:,1),emptyDimension,G.vars,G.dom);
G.C2 = zero_operator(emptyDimension,G.T.dim(:,2),G.vars,G.dom);
G.D12 = zero_operator(G.C1.dim(:,1),emptyDimension,G.vars,G.dom);
G.D21 = zero_operator(emptyDimension,G.B1.dim(:,2),G.vars,G.dom);
G.D22 = zero_operator(emptyDimension,emptyDimension,G.vars,G.dom);
G.misc = struct();

numberOfFilterStates = sum(Theta.T.dim(:,2));
tgrid = linspace(0,tFinal,1001).';
x0.ode = [initialDeviation;zeros(numberOfFilterStates,1)];
x0.pde = {initialDeviation};
opts = simulation_options();
sim = PIE_sim_nl(G,deltaG,tgrid,x0,opts);
sim = reconstruct_gpe_state(sim,1,1+numberOfFilterStates);
end

function opts = simulation_options()
opts.N = 24;
opts.nwd0 = 1;
opts.splot = linspace(0,1,151).';
opts.ode = odeset('RelTol',1e-7,'AbsTol',1e-9);
end

function sim = reconstruct_gpe_state(sim,xGIndex,numberOfFiniteStates)
primary = sim.Dop.Tcheb_2PDEstate*sim.x.';
sim.xG = primary(xGIndex,:).';
pdeCoefficients = primary(numberOfFiniteStates+1:end,:);
degree = size(pdeCoefficients,1)-1;
E = chebyshev_evaluation(2*sim.splot-1,degree);
sim.psiGG = zeros(numel(sim.t),numel(sim.splot));
for timeIndex = 1:numel(sim.t)
    sim.psiGG(timeIndex,:) = real(E*pdeCoefficients(:,timeIndex)).';
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

function plot_closed_loop_simulation(simOpen,simClosed,lambda)
figure('Color','w','Units','inches','Position',[1,1,8,7]);
layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile(layout,[2,1]);
surf(simClosed.splot,simClosed.t,simClosed.psiGG,'EdgeColor','none');
xlabel('s'); ylabel('t [s]'); zlabel('\psi_{GG}(t,s)');
title(sprintf('Controlled response, \\lambda=%.4g',lambda));
view(40,30); axis tight; colorbar;
nexttile;
plot(simOpen.t,simOpen.xG,'--','LineWidth',1.3); hold on;
plot(simClosed.t,simClosed.xG,'LineWidth',1.5); hold off;
xlabel('t [s]'); ylabel('x_G(t)');
legend('Open loop','Closed loop','Location','best'); grid on;
nexttile;
semilogy(simOpen.t,abs(simOpen.xG)+eps,'--','LineWidth',1.3); hold on;
semilogy(simClosed.t,abs(simClosed.xG)+eps,'LineWidth',1.5); hold off;
xlabel('t [s]'); ylabel('|x_G(t)|');
legend('Open loop','Closed loop','Location','best'); grid on;
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

function op = zero_operator(rowDimension,columnDimension,vars,dom)
op = mat2opvar(zeros(sum(rowDimension),sum(columnDimension)), ...
    [rowDimension,columnDimension],vars,dom);
end

function G = block_hcat(G1,G2,vars,dom)
outDim = ioDimensions("row",G1.dim(:,1).');
inDim = ioDimensions(["plant","filter"], ...
    [G1.dim(:,2).';G2.dim(:,2).']);
grid = gridBuilder(outDim,inDim,vars,dom);
grid(1,1) = G1;
grid(1,2) = G2;
G = grid();
end
