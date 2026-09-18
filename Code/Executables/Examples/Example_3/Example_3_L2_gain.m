clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Example 5: robust L2-gain synthesis at fixed lambda
%
%   q_tt = q_ss - damping*q_t + lambda*sin(q) + J*wp,
%   q(0,t)=0, q_s(1,t)=xb(t), xb_dot=u,
%   zp = [xb; int_0^1 q(s)ds].
%
% Synthesis uses the equivalent dual-friendly uncertainty LFR
%
%   q_tt = q_ss - damping*q_t + lambda*J*wd + J*wp,
%   zd = q_s,  wd = cos(J*zd).*zd,
%
% where (J*wp)(s)=(s-a)*wp for the scalar performance input. Thus both
% exogenous inputs enter through the q_s coordinate. The transformed
% uncertainty is sector bounded in [-1,1]. The dual
% performance multiplier is ordered [wp;zp] and is separate from the
% uncertainty multiplier.
pvar t s
a = 0;
b = 1;
lambda = 3;
damping = 2;

runSimulation = true;
plotSettings.showPreview = false;
plotSettings.saveImages = false; % Set true to export the PDF figures.
plotOpenLoop = true;       % true also simulates and plots the open loop
simulationFinalTime = 35;
paperFigureDir = fullfile(fileparts(codeRoot),'Documentation', ...
    'Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations','Figures');
simulationDataFile = fullfile(fileparts(mfilename('fullpath')), ...
    'Example_3_L2_simulation.mat');

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
bestTest = synthesize_gain(lambda,damping,a,b,settings,t,s);
K = bestTest.K;
if isempty(K)
    error('No feasible synthesis point was found.');
end

%% Analyze the synthesized controller with independent multipliers
% Use the original, non-filtered LFR for primal analysis and the equivalent
% J-filtered LFR for dual analysis.
analysisSettings = lpisettings('veryheavy');
analysisSettings.sos_opts.solver = 'mosek';
analysisSettings.ddM = 10;
analysisSettings.multiplierUpper = 1e4;
analysisSettings.inverseFloor = 1e-8;
analysisSettings.kypSlackMode = 'normal';
analysisSettings.controllerCleanTol = 1e-10;
analysisSettings.options1.sep = 0;
analysisSettings.options12.sep = 0;
analysis = analyze_closed_loop_gain( ...
    lambda,K,damping,a,b,analysisSettings,t,s);
warn_if_infeasible(analysis.primal,'primal analysis');
warn_if_infeasible(analysis.dual,'dual analysis');

%% Old finite-horizon simulation setup
if runSimulation
    [simOpen,simClosed] = simulate_controller( ...
        lambda,K,damping,a,b,t,s,simulationFinalTime,plotOpenLoop);
    plotData = compact_plot_data(simOpen,simClosed,plotOpenLoop);
    save(simulationDataFile,'plotData','-v7.3');
    if plotSettings.showPreview || plotSettings.saveImages
        files = plot_Example_L2_gain( ...
            3,simulationDataFile,paperFigureDir,plotSettings);
    end
end

%% Results overview
fprintf('\nExample 5 results overview, lambda = %.6g\n',lambda);
fprintf('Damping:                          %.6g\n',damping);
fprintf('Synthesis rho:                     % .6e\n',bestTest.rho);
fprintf('Synthesis induced-L2-gain bound:   %.10e\n',bestTest.gamma);
fprintf('Synthesis feasible:                %d\n',bestTest.feasible);
fprintf('Synthesis residual:                %.3e\n',bestTest.residual);
fprintf('Synthesis feasibility ratio:       %.10g\n',bestTest.feasratio);
fprintf('Synthesis numerical error:         %g\n',bestTest.numerr);
fprintf('Primal analysis feasibility ratio: %.10g\n', ...
    analysis.primal.feasratio);
fprintf('Dual analysis feasibility ratio:   %.10g\n', ...
    analysis.dual.feasratio);
fprintf('Primal optimized induced-L2 gain:  %.10e\n', ...
    analysis.primal.gamma);
fprintf('Dual optimized induced-L2 gain:    %.10e\n', ...
    analysis.dual.gamma);
if runSimulation
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
        lambda,K,damping,a,b,settings,t,s)
Pprimal = synthesis_plant(lambda,damping,a,b,t,s);
Pdual = synthesis_plant(lambda,damping,a,b,t,s);
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
[prog,V] = PIETOOLS_IQC_sector( ...
    prog,positiveDim,negativeDim,-1,1,settings,vars,dom);
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
        lambda,damping,a,b,settings,t,s)
P = synthesis_plant(lambda,damping,a,b,t,s);
wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);
wpDim = wDim(1);
zpDim = zDim(1);

DPsi = id_filter(wDim,zDim,P.vars,P.dom);
prog = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,rho] = lpidecvar(prog,'rhoSynthesis');
prog = lpi_ineq(prog,rho);
[prog,Vd] = PIETOOLS_IQC_sector(prog,wDim,zDim,-1,1,settings,P.vars,P.dom);
Vd.P = blkdiag(eye(wpDim),-rho*eye(zpDim));
prog = lpisetobj(prog,rho);
[K,~,~,prog] = PIETOOLS_IQC_controller_synthesis(prog,settings,P,DPsi,Vd);

result = certificate(prog);
result.rho = double(lpigetsol(prog,rho));
result.gamma = sqrt(max(result.rho,0));
result.feasible = result.feasible && isfinite(result.rho) && result.rho>=0;
result.K = K;
% if ~result.feasible
%     result.K = [];
% end
end

function P = synthesis_plant(lambda,damping,a,b,t,s)
q = pde_var(s,[a,b]);
v = pde_var(s,[a,b]);
xb = pde_var('state');
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
zp1 = pde_var('output',1);
zp2 = pde_var('output',1);
wp = pde_var('input',1);
u = pde_var('control',1);

PDE = [diff(q,t) == v;
       diff(v,t) == diff(q,s,2) - damping*v + wd + (s-a)*wp;
       diff(xb,t) == u;
       zd == diff(q,s);
       zp1 == xb;
       zp2 == int(q,s,[a,b]);
       subs(q,s,a) == 0;
       subs(v,s,a) == 0;
       subs(diff(q,s),s,b) == xb];
P = convert(PDE);

% Replace the pointwise wd input by lambda*J*wd.
inputDirection = P.B1.R.R0;
P.B1.R.R0 = 0*inputDirection;
P.B1.R.R1 = lambda*inputDirection;
P.B1.R.R2 = 0*inputDirection;
end

function P = simulation_plant(lambda,damping,a,b,t,s)
q = pde_var(s,[a,b]);
v = pde_var(s,[a,b]);
xb = pde_var('state');
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
zp1 = pde_var('output',1);
zp2 = pde_var('output',1);
wp = pde_var('input',1);
u = pde_var('control',1);

PDE = [diff(q,t) == v;
       diff(v,t) == diff(q,s,2) - damping*v + lambda*wd + (s-a)*wp;
       diff(xb,t) == u;
       zd == q;
       zp1 == xb;
       zp2 == int(q,s,[a,b]);
       subs(q,s,a) == 0;
       subs(v,s,a) == 0;
       subs(diff(q,s),s,b) == xb];
P = convert(PDE);
end

function [simOpen,simClosed] = simulate_controller( ...
        lambda,K,damping,a,b,t,s,tFinal,simulateOpenLoop)
P = simulation_plant(lambda,damping,a,b,t,s);
tgrid = linspace(0,tFinal,30000);
splot = linspace(a,b,200).';
wp = @(time) 8*cos(time).*(time>=pi).*(time<=4*pi);
x0.ode = 0;
% convert() orders the H1 velocity profile before the H2 displacement.
x0.pde = {@(position) zeros(size(position)); ...
          @(position) zeros(size(position))};

opts.N = 16;
opts.splot = splot;
opts.statePIE = P;
opts.nwd0 = 0;
opts.wp = wp;
opts.ode = odeset('RelTol',1e-6,'AbsTol',1e-8);
simClosed = PIE_sim_nl(closedLoopPIE(P,K),@(z) sin(z),tgrid,x0,opts);
simClosed.gamma = finite_horizon_gain(simClosed);
if simulateOpenLoop
    simOpen = PIE_sim_nl(P,@(z) sin(z),tgrid,x0,opts);
    simOpen.gamma = finite_horizon_gain(simOpen);
else
    simOpen = [];
end
end

function gamma = finite_horizon_gain(sim)
inputEnergy = trapz(sim.t,sim.wp(:,1).^2);
performance = sim.outputFinite(:,1:2);
outputEnergy = trapz(sim.t,sum(performance.^2,2));
gamma = sqrt(outputEnergy/inputEnergy);
end

function data = compact_plot_data(simOpen,simClosed,plotOpenLoop)
data.s = simClosed.splot;
data.t = simClosed.t;
data.zClosed = simClosed.zPlot;
data.inputSignal = simClosed.wp(:,1);
data.boundarySignal = simClosed.outputFinite(:,1);
data.gammaClosed = simClosed.gamma;
data.plotOpenLoop = plotOpenLoop;
if plotOpenLoop
    data.zOpen = simOpen.zPlot;
    data.gammaOpen = simOpen.gamma;
else
    data.zOpen = [];
    data.gammaOpen = NaN;
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
    && isfinite(cert.feasratio) && abs(cert.feasratio-1)<=0.3 ...
    && isfinite(cert.residual);
end

function warn_if_infeasible(result,label)
if ~result.feasible
    warning('Example_3:PoorAnalysisCertificate', ...
        '%s has poor feasibility (ratio %.6g, residual %.3e).', ...
        label,result.feasratio,result.residual);
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
