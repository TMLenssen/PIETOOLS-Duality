clear; clc; close all; clear stateNameGenerator
echo off

% Paper-to-code map for the robust-stability part of the Section 8 example:
%   stn_gpe_plant                 -> Eq. (21), with wp omitted
%   factor_uncertainty_multiplier -> Eqs. (23)-(26)
%   ThetaDelta.primal/dual        -> Theta_Delta and D(Theta_Delta)
%   PIETOOLS_IQC_*_graph          -> filtered systems, Eqs. (3) and (6)
%   PIETOOLS_IQC_controller_synthesis -> Eq. (7)

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE));
addpath(genpath('C:\Program Files\Mosek\11.0\toolbox\r2019b'));
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Settings
controlLocation = 'xS';       % 'xS', 'xG', or 'both'
Kd = 1;                       % Diseased endpoint
runSimulation = true;
plotSimulation = true;
simulationFinalTime = 0.5;
simulationInitialState = [1;-1];
betaBarMaximum = 1;
betaBarTolerance = 1e-2;

settings = lpisettings('veryheavy');
settings.sos_opts.solver = 'mosek';
settings.multiplierUpper = 1e8;
settings.inverseFloor = 1e-8;
settings.kypMarginUpper = 100;
settings.kypSlackMode = 'normal';
settings.controllerCleanTol = 1e-10;
settings.options1.sep = 1;
settings.options12.sep = 1;
analysisSettings = lpisettings("veryheavy");
analysisSettings.inverseFloor = 1e-6;
analysisSettings.options1.sep = 0;
analysisSettings.options12.sep = 0;

%% Physical STN--GPe time constants
tau.tauS = 6e-3;
tau.tauG = 14e-3;
tau.tauGS = 6e-3;
tau.tauSG = 6e-3;
tau.tauGG = 4e-3;

%% Two-channel sector and Zames--Falb multiplier settings
% Pole rates follow population relaxation and recurrent-delay time scales.
% Normalized synaptic strengths define a heuristic multiplier shape.
lambdaSector = 1;
lambdaZF = 0;
epsilonIQC = 1e-8;
poleScale = [1,1];              % Independent [S,G] time-scale factors
kernelNorm = 10/15;             % Sum(kappa./a), independent of pole rates
poleRates = [1/tau.tauG,1/tau.tauS,1/tau.tauGG];
synapticWeights = stn_gpe_weights(Kd);
synapticWeights = abs(synapticWeights([2,1,3])); % [wGS,wSG,wGG]
kernelWeights = kernelNorm*synapticWeights/sum(synapticWeights);
aS = poleScale(1)*poleRates;
aG = poleScale(2)*poleRates;
kappaS = kernelWeights.*aS;
kappaG = kernelWeights.*aG;

%% Eq. (18): bisection over the common betaBar
betaBarLower = 0;
betaBarUpper = betaBarMaximum;
synthesis = struct([]);
ThetaDelta = struct([]);
bisectionHistory = struct([]);
while betaBarUpper-betaBarLower>betaBarTolerance
    betaBarTrial = 0.5*(betaBarLower+betaBarUpper);
    betaBarChannels = betaBarTrial*[1,1];
    ThetaDeltaTrial = factor_uncertainty_multiplier(betaBarChannels, ...
        aS,kappaS,aG,kappaG,lambdaSector,lambdaZF,epsilonIQC);
    trial = synthesize_disease_level(Kd,controlLocation, ...
        tau,settings,ThetaDeltaTrial);
    trial.betaBar = betaBarTrial;
    historyEntry = struct('betaBar',betaBarTrial, ...
        'feasible',trial.feasible, ...
        'residual',trial.residual,'feasratio',trial.feasratio, ...
        'numerr',trial.numerr);
    if isempty(bisectionHistory)
        bisectionHistory = historyEntry;
    else
        bisectionHistory(end+1) = historyEntry;
    end
    if trial.feasible
        betaBarLower = betaBarTrial;
        synthesis = trial;
        ThetaDelta = ThetaDeltaTrial;
    else
        betaBarUpper = betaBarTrial;
    end
end
if isempty(synthesis)
    error('No feasible synthesis point was found for beta in [0,%.6g].', ...
        betaBarMaximum);
end
betaBar = synthesis.betaBar*[1,1];
K = synthesis.K;

%% Independent primal and dual KYP analyses; Eq. (4)
analysis = analyze_closed_loop_stability(synthesis.P,K,analysisSettings, ...
    ThetaDelta);

%% Simulate the original nonlinear open and controlled systems
simOpen = struct([]);
simClosed = struct([]);
parameters = struct([]);
localInputUpperBounds = [NaN,NaN];
if runSimulation
    [~,~,~,parameters] = stn_gpe_equilibrium(Kd);
    localInputUpperBounds = local_slope_upper_bounds( ...
        parameters,betaBar);
    delta = @(z) equilibrium_centered_sigmoid(z,parameters);
    ThetaPrimal = factor_box(ThetaDelta.primal,2, ...
        synthesis.P.vars,synthesis.P.dom);
    simOpen = simulate_open_loop(synthesis.P,delta,simulationFinalTime, ...
        simulationInitialState);
    simClosed = simulate_controlled_loop(synthesis.P,ThetaPrimal, ...
        K,delta,simulationFinalTime,simulationInitialState);
    if plotSimulation
        plot_closed_loop_simulation(simOpen,simClosed, ...
            Kd,localInputUpperBounds,betaBar);
        plot_local_slope_restriction(parameters, ...
            localInputUpperBounds,betaBar,Kd);
    end
end

%% Results overview
fprintf('\nExample 4: STN--GPe robust-stability synthesis\n');
fprintf('Nonlinearity channels:               [wS;wG] = [deltaS(zS);deltaG(zG)]\n');
fprintf('Disease level Kd:                    %.4g\n',Kd);
fprintf('Control location:                    %s\n',controlLocation);
fprintf('Requested beta-bar interval:         [0, %.6g]\n',betaBarMaximum);
fprintf('Certified beta-bar interval:         [%.6g, %.6g]\n', ...
    betaBarLower,betaBarUpper);
fprintf('Slope bounds [betaS,betaG]:          [%.4g, %.4g]\n',betaBar);
fprintf('Multiplier weights [sec,ZF]:         [%.4g, %.4g]\n', ...
    lambdaSector,lambdaZF);
fprintf('ZF-S pole frequencies aS/(2pi) [Hz]:[%.3g, %.3g, %.3g]\n', ...
    aS/(2*pi));
fprintf('ZF-G pole frequencies aG/(2pi) [Hz]:[%.3g, %.3g, %.3g]\n', ...
    aG/(2*pi));
fprintf('ZF kernel L1 norms [S,G]:            [%.10g, %.10g]\n', ...
    ThetaDelta.hNormL1);
fprintf('ZF norm conditions <= 1:             [%d, %d]\n', ...
    ThetaDelta.hNormL1<=1);
fprintf('Synthesis feasible:                  %d\n',synthesis.feasible);
fprintf('Synthesis residual:                  %.3e\n',synthesis.residual);
fprintf('Synthesis feasratio:                 %.6g\n',synthesis.feasratio);
fprintf('Synthesis numerr:                    %g\n',synthesis.numerr);
fprintf('Multiplier scalings [muS,muG]:      [%.6g, %.6g]\n',synthesis.mu);
fprintf('Primal analysis feasible:            %d\n',analysis.primal.feasible);
fprintf('Primal analysis residual:            %.3e\n',analysis.primal.residual);
fprintf('Primal analysis feasratio:           %.6g\n',analysis.primal.feasratio);
fprintf('Primal analysis numerr:              %g\n',analysis.primal.numerr);
fprintf('Primal multiplier scales [muS,muG]: [%.6g, %.6g]\n', ...
    analysis.primal.mu);
fprintf('Dual analysis feasible:              %d\n',analysis.dual.feasible);
fprintf('Dual analysis residual:              %.3e\n',analysis.dual.residual);
fprintf('Dual analysis feasratio:             %.6g\n',analysis.dual.feasratio);
fprintf('Dual analysis numerr:                %g\n',analysis.dual.numerr);
fprintf('Dual multiplier scales [muS,muG]:   [%.6g, %.6g]\n', ...
    analysis.dual.mu);
fprintf('Bisection trials [betaBar feasible residual feasratio numerr]:\n');
for index = 1:numel(bisectionHistory)
    item = bisectionHistory(index);
    fprintf('  %.6g  %d  %.3e  %.6g  %g\n',item.betaBar,item.feasible, ...
        item.residual,item.feasratio,item.numerr);
end
if ~isempty(simClosed)
    initialNorm = max(hypot(simOpen.xS(1),simOpen.xG(1)),eps);
    openRatio = hypot(simOpen.xS(end),simOpen.xG(end))/initialNorm;
    closedRatio = hypot(simClosed.xS(end),simClosed.xG(end))/initialNorm;
    fprintf('Simulation equilibrium [STN,GPe]:     [%.6g, %.6g]\n', ...
        parameters.xS0,parameters.xG0);
    fprintf('Equilibrium sigmoid slopes [S,G]:     [%.6g, %.6g]\n', ...
        parameters.slopeS,parameters.slopeG);
    fprintf('Local upper bounds [zS,zG]:           [%.6g, %.6g]\n', ...
        localInputUpperBounds);
    fprintf('Open loop inside local slope domain:  [%d, %d]\n', ...
        max(simOpen.zDelta,[],1)<=localInputUpperBounds);
    fprintf('Closed loop inside local slope domain:[%d, %d]\n', ...
        max(simClosed.zDelta,[],1)<=localInputUpperBounds);
    fprintf('Open-loop max zDelta [S,G]:           [%.6g, %.6g]\n', ...
        max(simOpen.zDelta,[],1));
    fprintf('Closed-loop max zDelta [S,G]:         [%.6g, %.6g]\n', ...
        max(simClosed.zDelta,[],1));
    fprintf('Open-loop final/initial state norm:   %.6g\n',openRatio);
    fprintf('Closed-loop final/initial state norm: %.6g\n',closedRatio);
    fprintf('Maximum absolute controller input:   ');
    fprintf(' %.6g',max(abs(simClosed.u),[],1));
    fprintf('\n');
end
Results = struct('Kd',Kd, ...
    'controlLocation',controlLocation,'synthesis',synthesis,'K',K, ...
    'analysis',analysis, ...
    'betaBarInterval',[betaBarLower,betaBarUpper], ...
    'bisectionHistory',bisectionHistory, ...
    'parameters',parameters, ...
    'localInputUpperBounds',localInputUpperBounds, ...
    'simOpen',simOpen,'simClosed',simClosed, ...
    'aS',aS,'kappaS',kappaS,'aG',aG,'kappaG',kappaG, ...
    'zfKernelL1Norm',ThetaDelta.hNormL1);

function result = analyze_closed_loop_stability(P,K,settings,ThetaDelta)
% Use the primal factor returned by jfactor directly; no refactorization.
ThetaPrimal = factor_box(ThetaDelta.primal,2,P.vars,P.dom);
ThetaDual = factor_box(ThetaDelta.dual,2,P.vars,P.dom);
Gprimal = PIETOOLS_IQC_primal_graph(P,ThetaPrimal,K);
Gdual = PIETOOLS_IQC_dual_graph(P,ThetaDual,K);
result.primal = analyze_stability_graph(Gprimal,settings,P.vars,P.dom);
result.dual = analyze_stability_graph(Gdual,settings,P.vars,P.dom);
end

function result = analyze_stability_graph(G,settings,vars,dom)
prog = lpiprogram(vars(:,1),vars(:,2),dom);
[prog,muS] = poslpivar(prog,[1;0],0);
[prog,muG] = poslpivar(prog,[1;0],0);
muS = muS+settings.inverseFloor*eyePI([1;0],vars,dom);
muG = muG+settings.inverseFloor*eyePI([1;0],vars,dom);
Mu = blkdiag(muS,muG);
% V=diag(Mu,-Mu) in the filtered order [zDelta;wDelta] (or its dual).
V = blkdiag(Mu,-Mu);
[storage,prog] = PIETOOLS_IQC_analysis(prog,settings,G,V);
result = certificate(prog);
result.mu = [solution_scalar(prog,muS),solution_scalar(prog,muG)];
result.storage = storage;
end

function result = synthesize_disease_level(Kd,controlLocation, ...
        tau,settings,ThetaDelta)
% Construct D(ThetaDelta)*[(K star P)^T;I] for the dual synthesis LPI.
P = stn_gpe_plant(Kd,controlLocation,tau);
Theta.dual = factor_box(ThetaDelta.dual,2,P.vars,P.dom);

prog = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,muS] = poslpivar(prog,[1;0],0);
[prog,muG] = poslpivar(prog,[1;0],0);
muS = muS+settings.inverseFloor*eyePI([1;0],P.vars,P.dom);
muG = muG+settings.inverseFloor*eyePI([1;0],P.vars,P.dom);
Mu = blkdiag(muS,muG);
% underline V_Delta=diag(Mu,-Mu), with Mu=diag(muS,muG).
Vdual = blkdiag(Mu,-Mu);
[K,~,~,prog] = PIETOOLS_IQC_controller_synthesis(prog,settings,P,Theta,Vdual);

result = certificate(prog);
result.Kd = Kd;
result.mu = [solution_scalar(prog,muS),solution_scalar(prog,muG)];
result.K = K;
result.P = P;
if ~result.feasible
    result.K = [];
end
end

function P = stn_gpe_plant(Kd,controlLocation,tau)
weights = stn_gpe_weights(Kd);
wSG = weights(1);
wGS = weights(2);
wGG = weights(3);

pvar t s
xS = pde_var('state');
xG = pde_var('state');
phiGS = pde_var(s,[0,1]);
phiSG = pde_var(s,[0,1]);
phiGG = pde_var(s,[0,1]);
zS = pde_var('output',1);
zG = pde_var('output',1);
wS = pde_var('input',1);
wG = pde_var('input',1);

switch lower(controlLocation)
    case 'xs'
        u = pde_var('control',1);
        xSEquation = diff(xS,t) == (1/tau.tauS)*(wS-xS)+4.6e+3*u;
        xGEquation = diff(xG,t) == (1/tau.tauG)*(wG-xG);
        numberOfControls = 1;
    case 'xg'
        u = pde_var('control',1);
        xSEquation = diff(xS,t) == (1/tau.tauS)*(wS-xS);
        xGEquation = diff(xG,t) == (1/tau.tauG)*(wG-xG)+4.6e+3*u;
        numberOfControls = 1;
    case 'both'
        uS = pde_var('control',1);
        uG = pde_var('control',1);
        xSEquation = diff(xS,t) == (1/tau.tauS)*(wS-xS)+4.6e+3*uS;
        xGEquation = diff(xG,t) == (1/tau.tauG)*(wG-xG)+4.6e+3*uG;
        numberOfControls = 2;
    otherwise
        error('controlLocation must be ''xS'', ''xG'', or ''both''.');
end

PDE = [xSEquation;
       xGEquation;
       diff(phiGS,t) == -(1/tau.tauGS)*diff(phiGS,s);
       diff(phiSG,t) == -(1/tau.tauSG)*diff(phiSG,s);
       diff(phiGG,t) == -(1/tau.tauGG)*diff(phiGG,s);
       zS == -wGS*subs(phiGS,s,1);
       zG == wSG*subs(phiSG,s,1)-wGG*subs(phiGG,s,1);
       subs(phiGS,s,0) == xG;
       subs(phiSG,s,0) == xS;
       subs(phiGG,s,0) == xG];

PDE = initialize(PDE,true);
[~,order] = reorder_comps(PDE,'all',true);
assert(isequal(order.z(:),(1:2).') && isequal(order.w(:),(1:2).'), ...
    'Unexpected uncertainty-channel ordering.');
assert(isequal(order.u(:),(1:numberOfControls).'), ...
    'Unexpected control-channel ordering.');
P = convert_PIETOOLS_PDE(PDE,order,{'silent'});
end

function weights = stn_gpe_weights(Kd)
healthyWeights = [19.0,1.12,6.60,2.42,15.1];
diseasedWeights = [20.0,10.7,12.3,9.20,139.4];
weights = healthyWeights+Kd*(diseasedWeights-healthyWeights);
end

function ThetaDelta = factor_uncertainty_multiplier( ...
        betaBar,aS,kappaS,aG,kappaG,lambdaSector,lambdaZF,epsilonIQC)
[PsiS,DPsiS,hNormS] = scalar_zf_multiplier( ...
    betaBar(1),aS,kappaS,lambdaSector,lambdaZF,epsilonIQC);
[PsiG,DPsiG,hNormG] = scalar_zf_multiplier( ...
    betaBar(2),aG,kappaG,lambdaSector,lambdaZF,epsilonIQC);

% Reorder from [zS,wS,zG,wG] to [zS,zG,wS,wG]. The same permutation
% changes the dual input order from [wS,zS,wG,zG] to [wS,wG,zS,zG].
channelOrder = [1,3,2,4];
primalRaw = blkdiag(PsiS,PsiG);
dualRaw = blkdiag(DPsiS,DPsiG);
ThetaDelta.primal = minreal( ...
    primalRaw(channelOrder,channelOrder),1e-9);
ThetaDelta.dual = minreal(dualRaw(channelOrder,channelOrder),1e-9);
ThetaDelta.hNormL1 = [hNormS,hNormG];
end

function [PsiPrimal,PsiDual,hNormL1] = ...
        scalar_zf_multiplier(betaBar,a,kappa, ...
        lambdaSector,lambdaZF,epsilonIQC)
assert(all(a>0) && all(kappa>=0), ...
    'The analytic L1-norm check requires nonnegative exponential kernels.');
q = tf('s');
H = 0;
for i = 1:numel(a)
    H = H+kappa(i)/(q+a(i));
end
hNormL1 = sum(kappa./a);
assert(hNormL1<=1+1e-12, ...
    'Invalid Zames--Falb kernel: ||H||_1 = %.6g exceeds one.',hNormL1);
M = minreal(ss(1-H),1e-9);

T = [betaBar,-1;0,1];
PiSector = T'*[0,1;1,0]*T;
PiZF = [0,betaBar*M';betaBar*M,-(M+M')];
PiNorm = diag([1,-1]);
% Retain both the static sector IQC and the dynamic Zames--Falb IQC.
PiChannel = minreal(ss(lambdaSector*PiSector+lambdaZF*PiZF+ ...
    epsilonIQC*PiNorm),1e-9);
[PsiPrimal,PsiDual] = jfactor(PiChannel,1,1);
end

function sim = simulate_open_loop(P,delta,tFinal,initialState)
tgrid = linspace(0,tFinal,1001).';
x0.ode = initialState(:);
x0.pde = {initialState(2),initialState(1),initialState(2)};
opts = simulation_options();
sim = PIE_sim_nl(P,delta,tgrid,x0,opts);
sim.zDelta = sim.zFinite(:,1:2);
sim = reconstruct_stn_gpe_state(sim,2);
end

function sim = simulate_controlled_loop(P,Theta,K,delta,tFinal,initialState)
G = PIETOOLS_IQC_primal_graph(P,Theta,K);
zeroTheta = matrix_operator(zeros(sum(P.C1.dim(:,1)), ...
    sum(Theta.T.dim(:,2))),P.vars,P.dom);
Cz = block_hcat(P.C1,zeroTheta,P.vars,P.dom)+P.D12*K;

% Keep the two original nonlinear outputs first and append u=K*x as an
% additional regulated output so PIESIM reconstructs the applied input.
zeroControlFeedthrough = zero_operator(K.dim(:,1),P.D11.dim(:,2), ...
    G.vars,G.dom);
G.C1 = block_vcat(Cz,K,G.vars,G.dom);
G.D11 = block_vcat(P.D11,zeroControlFeedthrough,G.vars,G.dom);
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
x0.ode = [initialState(:);zeros(numberOfFilterStates,1)];
x0.pde = {initialState(2),initialState(1),initialState(2)};
opts = simulation_options();
sim = PIE_sim_nl(G,delta,tgrid,x0,opts);
sim.zDelta = sim.zFinite(:,1:2);
sim.u = sim.outputFinite(:,3:end);
sim = reconstruct_stn_gpe_state(sim,2+numberOfFilterStates);
end

function opts = simulation_options()
opts.N = 24;
opts.nwd0 = 2;
opts.splot = linspace(0,1,151).';
opts.ode = odeset('RelTol',1e-7,'AbsTol',1e-9);
end

function sim = reconstruct_stn_gpe_state(sim,numberOfFiniteStates)
primary = sim.Dop.Tcheb_2PDEstate*sim.x.';
sim.xS = primary(1,:).';
sim.xG = primary(2,:).';
pdeCoefficients = primary(numberOfFiniteStates+1:end,:);
numberOfPDEStates = 3;
numberOfCoefficients = size(pdeCoefficients,1)/numberOfPDEStates;
assert(abs(numberOfCoefficients-round(numberOfCoefficients))<1e-12, ...
    'Unexpected PIE simulation state ordering.');
degree = round(numberOfCoefficients)-1;
E = chebyshev_evaluation(2*sim.splot-1,degree);
fieldNames = {'phiGS','phiSG','phiGG'};
for channel = 1:numberOfPDEStates
    rows = (channel-1)*(degree+1)+(1:degree+1);
    field = zeros(numel(sim.t),numel(sim.splot));
    for timeIndex = 1:numel(sim.t)
        field(timeIndex,:) = real(E*pdeCoefficients(rows,timeIndex)).';
    end
    sim.(fieldNames{channel}) = field;
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

function plot_closed_loop_simulation(simOpen,simClosed,Kd, ...
        localInputUpperBounds,betaBar)
figure('Color','w','Units','inches','Position',[1,1,8,8]);
layout = tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
nexttile(layout,[3,1]);
surf(simClosed.splot,simClosed.t,simClosed.phiGG,'EdgeColor','none');
xlabel('$s$','Interpreter','latex');
ylabel('$t\,[\mathrm{s}]$','Interpreter','latex');
zlabel('$\phi_{\mathrm{GG}}(t,s)$','Interpreter','latex');
title(sprintf('Controlled GPe delay, $K_d=%.3g$',Kd), ...
    'Interpreter','latex');
view(40,30); axis tight;
set(gca,'TickLabelInterpreter','latex');
colorScale = colorbar;
colorScale.TickLabelInterpreter = 'latex';
nexttile;
plot(simOpen.t,simOpen.xS,'--','LineWidth',1.3); hold on;
plot(simClosed.t,simClosed.xS,'LineWidth',1.5); hold off;
xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
ylabel('$x_{\mathrm S}(t)$','Interpreter','latex');
legend({'Open loop','Closed loop'},'Location','best', ...
    'Interpreter','latex');
set(gca,'TickLabelInterpreter','latex'); grid on;
nexttile;
plot(simOpen.t,simOpen.xG,'--','LineWidth',1.3); hold on;
plot(simClosed.t,simClosed.xG,'LineWidth',1.5); hold off;
xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
ylabel('$x_{\mathrm G}(t)$','Interpreter','latex');
legend({'Open loop','Closed loop'},'Location','best', ...
    'Interpreter','latex');
set(gca,'TickLabelInterpreter','latex'); grid on;
nexttile;
plot(simClosed.t,simClosed.u,'LineWidth',1.4);
xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
ylabel('$u(t)$','Interpreter','latex');
set(gca,'TickLabelInterpreter','latex'); grid on;
if size(simClosed.u,2)>1
    legend(compose('$u_{%d}$',1:size(simClosed.u,2)), ...
        'Location','best','Interpreter','latex');
end

figure('Color','w','Units','inches','Position',[1,1,7,7]);
layout = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
channelNames = {'S','G'};
for channel = 1:2
    nexttile(layout);
    hOpen = plot(simOpen.t,simOpen.zDelta(:,channel),'--', ...
        'LineWidth',1.3); hold on;
    hClosed = plot(simClosed.t,simClosed.zDelta(:,channel), ...
        'LineWidth',1.5);
    timeLimits = [min([simOpen.t;simClosed.t]), ...
                  max([simOpen.t;simClosed.t])];
    hBound = plot(timeLimits,localInputUpperBounds(channel)*[1,1], ...
        ':k','LineWidth',1.3);
    hold off;
    xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
    ylabel(sprintf('$z_{\\Delta,\\mathrm{%s}}(t)$', ...
        channelNames{channel}),'Interpreter','latex');
    title(sprintf(['$z_{\\Delta,\\mathrm{%s}}\\leq r_{\\mathrm{%s}},' ...
        '\\quad 0\\leq\\delta_{\\mathrm{%s}}''\\leq %.3g,' ...
        '\\quad K_d=%.3g$'],channelNames{channel},channelNames{channel}, ...
        channelNames{channel},betaBar(channel),Kd), ...
        'Interpreter','latex');
    legend([hOpen,hClosed,hBound],{'Open loop','Closed loop', ...
        sprintf('$r_{\\mathrm{%s}}$',channelNames{channel})}, ...
        'Location','best','Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex'); grid on;
end
end

function plot_local_slope_restriction(parameters,upperBounds,betaBar,Kd)
figure('Color','w','Units','inches','Position',[1,1,7,7]);
layout = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
channelNames = {'S','G'};
inputEquilibria = [parameters.uS0,parameters.uG0];
maximumRates = [parameters.MS,parameters.MG];
baselineRates = [parameters.BS,parameters.BG];
for channel = 1:2
    inputEquilibrium = inputEquilibria(channel);
    M = maximumRates(channel);
    B = baselineRates(channel);
    inflectionInput = (M/4)*log((M-B)/B);
    scale = max([upperBounds(channel), ...
        abs(inflectionInput-inputEquilibrium),1]);
    zLower = -max(1.25*upperBounds(channel),0.25*scale);
    zUpper = max(1.5*upperBounds(channel), ...
        inflectionInput-inputEquilibrium);
    z = linspace(zLower,zUpper,1200);
    output = stn_gpe_sigmoid(inputEquilibrium+z,M,B);
    derivative = 4*(output/M).*(1-output/M);

    nexttile(layout);
    hold on;
    if upperBounds(channel)>0
        hDomain = patch([zLower,upperBounds(channel), ...
            upperBounds(channel),zLower], ...
            [0,0,1.05,1.05],[0.82,0.90,1.00], ...
            'EdgeColor','none','FaceAlpha',0.45);
    else
        hDomain = plot(NaN,NaN,'Color',[0.82,0.90,1.00], ...
            'LineWidth',6);
    end
    hSlope = plot(z,derivative,'LineWidth',1.7);
    hUpper = plot([zLower,zUpper],betaBar(channel)*[1,1], ...
        '--k','LineWidth',1.3);
    if upperBounds(channel)>0
        plot(upperBounds(channel)*[1,1],[0,1.05],':', ...
            'Color',[0.25,0.25,0.25],'LineWidth',1.1, ...
            'HandleVisibility','off');
    end
    hold off;
    xlim([zLower,zUpper]); ylim([0,1.05]); grid on;
    xlabel(sprintf('$z_{\\Delta,\\mathrm{%s}}$', ...
        channelNames{channel}),'Interpreter','latex');
    ylabel(sprintf(['$\\frac{\\mathrm d\\delta_{\\mathrm{%s}}}' ...
        '{\\mathrm d z_{\\Delta,\\mathrm{%s}}}$'], ...
        channelNames{channel},channelNames{channel}),'Interpreter','latex');
    title(sprintf('Local slope restriction for $\\delta_{\\mathrm{%s}}$', ...
        channelNames{channel}),'Interpreter','latex');
    legend([hSlope,hUpper,hDomain],{sprintf('$\\delta_{\\mathrm{%s}}''$', ...
        channelNames{channel}),sprintf('$\\beta_{\\mathrm{%s}}=%.3g$', ...
        channelNames{channel},betaBar(channel)), ...
        sprintf('$z_{\\Delta,\\mathrm{%s}}\\leq r_{\\mathrm{%s}}$', ...
        channelNames{channel},channelNames{channel})}, ...
        'Location','best','Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex');
end
sgtitle(sprintf('Equilibrium-centered nonlinearities, $K_d=%.3g$', ...
    Kd),'Interpreter','latex');
end

function value = equilibrium_centered_sigmoid(input,parameters)
value = [stn_gpe_sigmoid(parameters.uS0+input(1), ...
             parameters.MS,parameters.BS)-parameters.fS0; ...
         stn_gpe_sigmoid(parameters.uG0+input(2), ...
             parameters.MG,parameters.BG)-parameters.fG0];
end

function value = stn_gpe_sigmoid(input,maximumRate,baselineRate)
value = maximumRate./(1+exp(-4*input/maximumRate) ...
    .*((maximumRate-baselineRate)/baselineRate));
end

function upperBounds = local_slope_upper_bounds(parameters,betaBar)
upperBounds = [connected_slope_upper_bound(parameters.uS0,parameters.MS, ...
             parameters.BS,betaBar(1)), ...
         connected_slope_upper_bound(parameters.uG0,parameters.MG, ...
             parameters.BG,betaBar(2))];
end

function upperBound = connected_slope_upper_bound( ...
        inputEquilibrium,M,B,betaBar)
outputEquilibrium = stn_gpe_sigmoid(inputEquilibrium,M,B);
equilibriumSlope = 4*(outputEquilibrium/M)*(1-outputEquilibrium/M);
if betaBar>=1
    upperBound = Inf;
    return
elseif betaBar<=0
    error('The slope upper bound must be positive.');
elseif equilibriumSlope>betaBar+1e-12
    error('The slope bound is violated at the simulated equilibrium.');
end
pLower = 0.5*(1-sqrt(1-betaBar));
inputLower = (M/4)*log(((M-B)/B)*pLower/(1-pLower));
if inputEquilibrium<=inputLower
    upperBound = inputLower-inputEquilibrium;
else
    error(['The one-sided upper-bound description requires the ' ...
        'equilibrium to lie on the lower sigmoid branch.']);
end
end

function cert = certificate(prog)
info = prog.solinfo.info;
cert.feasratio = double(info.feasratio);
cert.pinf = double(info.pinf);
cert.dinf = double(info.dinf);
cert.numerr = double(info.numerr);
cert.residual = double(prog.solinfo.residual);
cert.feasible = cert.pinf==0 && cert.dinf==0 && cert.numerr<=1 ...
    && isfinite(cert.feasratio) && abs(cert.feasratio-1)<=0.4 ...
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

function Box = factor_box(sys,nPositive,vars,dom)
[A,B,C,D] = ssdata(sys);
Box.T = matrix_operator(eye(size(A,1)),vars,dom);
Box.A = matrix_operator(A,vars,dom);
Box.B1 = matrix_operator(B(:,1:nPositive),vars,dom);
Box.B2 = matrix_operator(B(:,nPositive+1:end),vars,dom);
Box.C1 = matrix_operator(C(1:nPositive,:),vars,dom);
Box.C2 = matrix_operator(C(nPositive+1:end,:),vars,dom);
Box.D11 = matrix_operator(D(1:nPositive,1:nPositive),vars,dom);
Box.D12 = matrix_operator(D(1:nPositive,nPositive+1:end),vars,dom);
Box.D21 = matrix_operator(D(nPositive+1:end,1:nPositive),vars,dom);
Box.D22 = matrix_operator(D(nPositive+1:end,nPositive+1:end),vars,dom);
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

function G = block_vcat(G1,G2,vars,dom)
outDim = ioDimensions(["physical","control"], ...
    [G1.dim(:,1).';G2.dim(:,1).']);
inDim = ioDimensions("state",G1.dim(:,2).');
grid = gridBuilder(outDim,inDim,vars,dom);
grid(1,1) = G1;
grid(2,1) = G2;
G = grid();
end
