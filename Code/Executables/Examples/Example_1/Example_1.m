clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Example 1: robust L2-gain synthesis with parametric uncertainty
pvar t s
a = 0;
b = 1;
reactionRate = 5;
uncertaintyGain = 10;

runSimulation = true;
plotSettings.showPreview = true;
plotSettings.saveImages = true; % Set true to export the PDF figures.
plotSettings.openLoopTransform = 'none';
plotOpenLoop = false;       % The open loop grows rapidly for positive delta.
uncertaintyValue = 0.99;    % Repeated scalar delta, with |delta|<1.
simulationFinalTime = 35;
paperFigureDir = fullfile(fileparts(codeRoot),'Documentation', ...
    'Robust_Control_of_PIE_Systems_using_IQC_based_on_Duality','Figures');
simulationDataFile = fullfile(fileparts(mfilename('fullpath')), ...
    'Example_1_L2_simulation.mat');

settings = lpisettings('veryheavy');
settings.dd1 = 2;
settings.dd12 = 2;
settings.ddZ = 2;
settings.sos_opts.solver = 'mosek';
settings.ddM = 2;
settings.multiplierUpper = 1e4;
settings.inverseFloor = 1e-8;
settings.kypSlackMode = 'normal';
settings.controllerCleanTol = 1e-10;
settings.kmax = 10000;
settings.options1.sep = 1;
settings.options12.sep = 1;

%% Synthesize the robust-performance controller
synthesis = synthesize_gain( ...
    reactionRate,uncertaintyGain,a,b,settings,t,s);
K = synthesis.K;
if isempty(K)
    error('No feasible synthesis point was found.');
end

%% Analyze the synthesized controller with independent multipliers
analysisSettings = lpisettings('veryheavy');
analysisSettings.sos_opts.solver = 'mosek';
analysisSettings.ddM = 2;
analysisSettings.multiplierUpper = 1e4;
analysisSettings.inverseFloor = 1e-8;
analysisSettings.kypSlackMode = 'normal';
analysisSettings.controllerCleanTol = 1e-10;
analysisSettings.options1.sep = 0;
analysisSettings.options12.sep = 0;
analysis = analyze_closed_loop_gain(reactionRate,uncertaintyGain,K,a,banalysisSettings,t,s);
warn_if_infeasible(analysis.primal,'primal analysis');
warn_if_infeasible(analysis.dual,'dual analysis');

%% Simulate the original parametric-uncertainty interconnection
if runSimulation
    if isempty(K)
        error('Example_1:MissingController', ...
            'A controller is required for the closed-loop simulation.');
    end
    [simOpen,simClosed] = simulate_controller( ...
        reactionRate,uncertaintyGain,uncertaintyValue,K, ...
        a,b,t,s,simulationFinalTime,plotOpenLoop);
    plotData = compact_plot_data( ...
        simOpen,simClosed,plotOpenLoop,uncertaintyValue);
    save(simulationDataFile,'plotData','-v7.3');
    if plotSettings.showPreview || plotSettings.saveImages
        files = plot_Example_L2_gain( ...
            1,simulationDataFile,paperFigureDir,plotSettings);
    end
end

%% Results overview
fprintf('\nExample 1 results overview\n');
fprintf('Synthesis rho:                     % .6e\n',synthesis.rho);
fprintf('Synthesis induced-L2-gain bound:   %.10e\n',synthesis.gamma);
fprintf('Synthesis feasible:                %d\n',synthesis.feasible);
fprintf('Synthesis residual:                %.3e\n',synthesis.residual);
fprintf('Synthesis feasibility ratio:       %.10g\n',synthesis.feasratio);
fprintf('Synthesis numerical error:         %g\n',synthesis.numerr);
fprintf('Primal analysis feasibility ratio: %.10g\n', ...
    analysis.primal.feasratio);
fprintf('Dual analysis feasibility ratio:   %.10g\n', ...
    analysis.dual.feasratio);
fprintf('Primal optimized induced-L2 gain:  %.10e\n', ...
    analysis.primal.gamma);
fprintf('Dual optimized induced-L2 gain:    %.10e\n', ...
    analysis.dual.gamma);
if runSimulation
    fprintf('Simulation uncertainty delta:       %.6g\n',uncertaintyValue);
    if plotOpenLoop
        fprintf('Open-loop simulated L2 ratio:  %.10e\n',simOpen.gamma);
    end
    fprintf('Closed-loop simulated L2 ratio: %.10e\n',simClosed.gamma);
    fprintf('Saved plotting data to: %s\n',simulationDataFile);
    if plotSettings.showPreview
        fprintf('Interactive plot preview: enabled\n');
    end
    if plotSettings.saveImages
        fprintf('Simulation figures written to: %s\n',paperFigureDir);
        disp(files)
    end
end

function result = analyze_closed_loop_gain( ...
        reactionRate,uncertaintyGain,K,a,b,settings,t,s)
Pprimal = simulation_plant(reactionRate,uncertaintyGain,a,b,t,s);
Pdual = synthesis_plant(reactionRate,uncertaintyGain,a,b,t,s);
wDimPrimal = Pprimal.B1.dim(:,2);
zDimPrimal = Pprimal.C1.dim(:,1);
wDimDual = Pdual.B1.dim(:,2);
zDimDual = Pdual.C1.dim(:,1);

Psi = id_filter(zDimPrimal,wDimPrimal,Pprimal.vars,Pprimal.dom);
DPsi = id_filter(wDimDual,zDimDual,Pdual.vars,Pdual.dom);
GP = PIETOOLS_IQC_primal_graph(Pprimal,Psi,K);
GD = PIETOOLS_IQC_dual_graph(Pdual,DPsi,K);

result.primal = analyze_graph_gain( ...
    GP,zDimPrimal,wDimPrimal,settings,Pprimal.vars,Pprimal.dom);
result.dual = analyze_graph_gain( ...
    GD,wDimDual,zDimDual,settings,Pdual.vars,Pdual.dom);
end

function result = analyze_graph_gain( ...
        G,positiveDim,negativeDim,settings,vars,dom)
prog = lpiprogram(vars(:,1),vars(:,2),dom);
[prog,rho] = lpidecvar(prog,'rhoAnalysis');
prog = lpi_ineq(prog,rho);
[prog,V] = PIETOOLS_IQC_parametric( ...
    prog,positiveDim,negativeDim,settings,vars,dom);
V.P = blkdiag(eye(positiveDim(1)),-rho*eye(negativeDim(1)));
prog = lpisetobj(prog,rho);
[storage,prog] = PIETOOLS_IQC_analysis(prog,settings,G,V);

result = certificate(prog);
result.rho = double(lpigetsol(prog,rho));
result.gamma = sqrt(max(result.rho,0));
result.storage = storage;
result.multiplier = lpigetsol(prog,V);
result.program = prog;
result.feasible = result.feasible && isfinite(result.rho) && result.rho>=0;
end

function result = synthesize_gain( ...
        reactionRate,uncertaintyGain,a,b,settings,t,s)
P = synthesis_plant(reactionRate,uncertaintyGain,a,b,t,s);
wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);
wpDim = wDim(1);
zpDim = zDim(1);
if ~isequal(wDim,[1;1]) || ~isequal(zDim,[2;1])
    error('Expected w=[wp;wd] with [1;1] and z=[zp;zd] with [2;1].');
end

DPsi = id_filter(wDim,zDim,P.vars,P.dom);
prog = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,rho] = lpidecvar(prog,'rhoSynthesis');
prog = lpi_ineq(prog,rho);
[prog,Vd] = PIETOOLS_IQC_parametric( ...
    prog,wDim,zDim,settings,P.vars,P.dom);
Vd.P = blkdiag(eye(wpDim),-rho*eye(zpDim));
prog = lpisetobj(prog,rho);
[K,~,~,prog] = PIETOOLS_IQC_controller_synthesis( ...
    prog,settings,P,DPsi,Vd);

result = certificate(prog);
result.rho = double(lpigetsol(prog,rho));
result.gamma = sqrt(max(result.rho,0));
result.feasible = result.feasible && isfinite(result.rho) && result.rho>=0;
result.K = K;
if ~result.feasible
    result.K = [];
end
end

function P = synthesis_plant(reactionRate,uncertaintyGain,a,b,t,s)
x = pde_var(s,[a,b]);
xb = pde_var('state');
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
zp1 = pde_var('output',1);
zp2 = pde_var('output',1);
wp = pde_var('input',1);
u = pde_var('control',1);

PDE = [diff(x,t) == diff(x,s,2) + reactionRate*x + wd + (s-a)*wp;
       diff(xb,t) == u;
       zd == diff(x,s);
       zp1 == xb;
       zp2 == int(x,s,[a,b]);
       subs(x,s,a) == 0;
       subs(diff(x,s),s,b) == xb];
P = convert(PDE);

% Replace the pointwise wd input by uncertaintyGain*J*wd.
inputDirection = P.B1.R.R0;
P.B1.R.R0 = 0*inputDirection;
P.B1.R.R1 = uncertaintyGain*inputDirection;
P.B1.R.R2 = 0*inputDirection;
end

function P = simulation_plant(reactionRate,uncertaintyGain,a,b,t,s)
x = pde_var(s,[a,b]);
xb = pde_var('state');
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
zp1 = pde_var('output',1);
zp2 = pde_var('output',1);
wp = pde_var('input',1);
u = pde_var('control',1);

PDE = [diff(x,t) == diff(x,s,2) + reactionRate*x ...
       + uncertaintyGain*wd + (s-a)*wp;
       diff(xb,t) == u;
       zd == x;
       zp1 == xb;
       zp2 == int(x,s,[a,b]);
       subs(x,s,a) == 0;
       subs(diff(x,s),s,b) == xb];
P = convert(PDE);
end

function [simOpen,simClosed] = simulate_controller( ...
        reactionRate,uncertaintyGain,delta,K,a,b,t,s,tFinal,simulateOpenLoop)
P = simulation_plant(reactionRate,uncertaintyGain,a,b,t,s);
tgrid = linspace(0,tFinal,3000);
splot = linspace(a,b,200).';
wp = @(time) 8*cos(time).*(time>=pi).*(time<=4*pi);
uncertainty = @(z) parametric_uncertainty(z,delta);
x0.ode = 0;
x0.pde = {@(position) zeros(size(position))};

opts.N = 16;
opts.splot = splot;
opts.statePIE = P;
opts.nwd0 = 0;
opts.wp = wp;
opts.ode = odeset('RelTol',1e-6,'AbsTol',1e-8);
simClosed = PIE_sim_nl( ...
    closedLoopPIE(P,K),uncertainty,tgrid,x0,opts);
simClosed.gamma = finite_horizon_gain(simClosed);
if simulateOpenLoop
    simOpen = simulate_open_loop_modal( ...
        reactionRate,uncertaintyGain,delta,a,b,tgrid,splot,wp);
    simOpen.gamma = finite_horizon_gain(simOpen);
else
    simOpen = [];
end
end

function sim = simulate_open_loop_modal( ...
        reactionRate,uncertaintyGain,delta,a,b,tgrid,splot,wp)
% Evaluate the unstable linear open loop in a Laplacian eigenfunction basis.
domainLength = b-a;
modeIndex = 0:63;
waveNumber = (modeIndex+0.5)*pi/domainLength;
growthRate = reactionRate+uncertaintyGain*delta-waveNumber.^2;
inputCoefficient = 2*(-1).^modeIndex./(domainLength*waveNumber.^2);
modeShape = sin((splot-a)*waveNumber);
modeIntegral = 1./waveNumber;

tgrid = tgrid(:);
wpValues = wp(tgrid);
modeState = zeros(numel(tgrid),numel(modeIndex));
for k = 2:numel(tgrid)
    step = tgrid(k)-tgrid(k-1);
    transition = exp(growthRate*step);
    inputFactor = zeros(size(growthRate));
    nonzeroRate = abs(growthRate)>sqrt(eps);
    inputFactor(nonzeroRate) = ...
        expm1(growthRate(nonzeroRate)*step)./growthRate(nonzeroRate);
    inputFactor(~nonzeroRate) = step;
    meanInput = 0.5*(wpValues(k-1)+wpValues(k));
    modeState(k,:) = transition.*modeState(k-1,:) ...
        + meanInput*inputCoefficient.*inputFactor;
end

sim.t = tgrid;
sim.splot = splot;
sim.wp = wpValues;
sim.zPlot = modeState*modeShape.';
sim.outputFinite = [zeros(numel(tgrid),1),modeState*modeIntegral.'];
end

function gamma = finite_horizon_gain(sim)
inputEnergy = trapz(sim.t,sim.wp(:,1).^2);
performance = sim.outputFinite(:,1:2);
outputScale = max(abs(performance),[],'all');
if outputScale == 0
    gamma = 0;
    return
end
scaledEnergy = trapz(sim.t,sum((performance/outputScale).^2,2));
gamma = outputScale*sqrt(scaledEnergy/inputEnergy);
end

function data = compact_plot_data(simOpen,simClosed,plotOpenLoop,delta)
data.s = simClosed.splot;
data.t = simClosed.t;
data.zClosed = simClosed.zPlot;
data.inputSignal = simClosed.wp(:,1);
data.boundarySignal = simClosed.outputFinite(:,1);
data.gammaClosed = simClosed.gamma;
data.plotOpenLoop = plotOpenLoop;
data.uncertaintyValue = delta;
if plotOpenLoop
    data.zOpen = simOpen.zPlot;
    data.gammaOpen = simOpen.gamma;
else
    data.zOpen = [];
    data.gammaOpen = NaN;
end
end

function F = id_filter(d1,d2,vars,dom)
d0 = zeros(size(d1));
F.T = zerosPI(d0,d0,vars,dom);
F.A = zerosPI(d0,d0,vars,dom);
F.B1 = zerosPI(d0,d1,vars,dom);
F.B2 = zerosPI(d0,d2,vars,dom);
F.C1 = zerosPI(d1,d0,vars,dom);
F.C2 = zerosPI(d2,d0,vars,dom);
F.D11 = eyePI(d1,vars,dom);
F.D12 = zerosPI(d1,d2,vars,dom);
F.D21 = zerosPI(d2,d1,vars,dom);
F.D22 = eyePI(d2,vars,dom);
end

function wd = parametric_uncertainty(zd,delta)
wd = delta*zd;
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

function warn_if_infeasible(result,label)
if ~result.feasible
    warning('Example_1:PoorAnalysisCertificate', ...
        '%s has poor feasibility (ratio %.6g, residual %.3e).', ...
        label,result.feasratio,result.residual);
end
end

