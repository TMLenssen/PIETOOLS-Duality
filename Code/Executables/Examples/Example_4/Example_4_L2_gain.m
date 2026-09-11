clear; clc; close all; clear stateNameGenerator
echo off

% Paper-to-code map for the robust-performance example in Section 8:
%   stn_gpe_plant                 -> generalized plant, Eq. (21)
%   factor_uncertainty_multiplier -> Pi_Delta and Theta_Delta, Eqs. (23)-(26)
%   performance_filter            -> Psi_p structure in Eq. (22)
%   PIETOOLS_IQC_*_graph          -> filtered realizations, Eqs. (3) and (6)
%   PIETOOLS_IQC_controller_synthesis -> dual LPI, Eq. (7)

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE));
addpath(genpath('C:\Program Files\Mosek\11.0\toolbox\r2019b'));
codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(codeRoot));

%% Settings
controlLocation = 'xS';
Kd = 1;
runSimulation = true;
plotSimulation = true;
displayComponents = false;
saveComponentsPDF = true;
saveComponentsLaTeX = true;
simulationFinalTime = 0.5;
disturbanceType = 'sine';       % 'sine' or 'whiteNoise'
disturbanceAmplitude = 2000;
disturbanceFrequency = 20;
disturbanceStartTime = 0.05;
disturbanceEndTime = 0.35;
whiteNoiseRMS = disturbanceAmplitude/sqrt(2);
whiteNoiseSampleRate = 1e3;
whiteNoiseSeed = 4;

% Control presets: 'control3', 'control4', 'control5', 'control6'.
% These raise slack degrees, dd2 and dd3, with dd1=dd12={2,[2,2,3],[2,2,3]}, ddZ=[2,2,2].
% Should give a controller of degree 10. Very heavy yields a polynomial
% degree of 12, this makes primal analysis infeasible but significantly
% increases the admissible sector and slope bounds.
settings = lpisettings('veryheavy');
settings.sos_opts.solver = 'mosek';
settings.multiplierUpper = 1e8;
settings.inverseFloor = 1e-8;
settings.kypMarginUpper = 100;
settings.kypSlackMode = 'normal';
settings.controllerCleanTol = 1e-10;
settings.options1.sep = 1;
settings.options12.sep = 1;
% settings.kmax = 1000;
% Analysis presets: 'veryheavy', 'degree4', 'degree5', 'degree6'.
analysisSettings = lpisettings('veryheavy');
analysisSettings.sos_opts = settings.sos_opts;
analysisSettings.inverseFloor = settings.inverseFloor;
analysisSettings.kypMarginUpper = settings.kypMarginUpper;
analysisSettings.kypSlackMode = settings.kypSlackMode;
analysisSettings.options1.sep = 0;
analysisSettings.options12.sep = 0;

tau.tauS = 6e-3;
tau.tauG = 14e-3;
tau.tauGS = 6e-3;
tau.tauSG = 6e-3;
tau.tauGG = 4e-3;

%% Pi_Delta and (Theta_Delta,D(Theta_Delta)); Eqs. (23)-(26)
betaBar = [0.40,0.40];
lambdaSector = 0;
lambdaZF = 1;
epsilonIQC = 1e-8;
% Match the parameter-dependent multiplier shape used for stability synthesis.
poleScale = [1,1];              % Independent [S,G] time-scale factors
kernelNorm = 13/15;             % Sum(kappa./a), independent of pole rates
poleRates = [1/tau.tauG,1/tau.tauS,1/tau.tauGG];
synapticWeights = stn_gpe_weights(Kd);
synapticWeights = abs(synapticWeights([2,1,3])); % [wGS,wSG,wGG]
kernelWeights = kernelNorm*synapticWeights/sum(synapticWeights);
aS = poleScale(1)*poleRates;
aG = poleScale(2)*poleRates;
kappaS = kernelWeights.*aS;
kappaG = kernelWeights.*aG;
ThetaDelta = factor_uncertainty_multiplier(betaBar, ...
    aS,kappaS,aG,kappaG,lambdaSector,lambdaZF,epsilonIQC);

%% Low-pass performance filter; Psi_p has the structure in Eq. (22)
useLowPassPerformanceFilter = false;
lowPassDCGain = 16;
lowPassFrequency = 35*2*pi;                % rad/s
lowPassMagnitude = db2mag(-3);         % magnitude at lowPassFrequency
lowPassHighFrequencyGain = db2mag(-20);
muControl = 1e-2;
PsiP = performance_filter( ...
    useLowPassPerformanceFilter,lowPassDCGain,lowPassFrequency, ...
    lowPassMagnitude,lowPassHighFrequencyGain,controlLocation);
numberOfControls = 1+strcmpi(controlLocation,'both');
zpDim = 2+numberOfControls;
Psi.primal = combine_factors( ...
    ThetaDelta.primal,PsiP.primal,2,2,zpDim,1);
Psi.dual = combine_factors( ...
    ThetaDelta.dual,PsiP.dual,2,2,1,zpDim);
% eig(Psi.primal)
% eig(Psi.dual)
% The combined primal signal order is [z_Delta;z_p;w_Delta;w_p].
% The combined dual signal order is [w_Delta;w_p;z_Delta;z_p].

%% Dual robust-performance LPI; Eq. (7)
synthesis = synthesize_performance(Kd,controlLocation,tau, ...
    muControl,settings,Psi);
K = synthesis.K;
if isempty(K)
    error('Example_4:NoSynthesisSolution','%s',synthesis.message);
end

%% Independent primal and dual KYP analyses; Eq. (4)
analysis = analyze_closed_loop_performance(synthesis.P,K,synthesis.zpDim, ...
    analysisSettings,Psi.primal,Psi.dual);

%% Nonlinear simulation
simOpen = struct([]);
simClosed = struct([]);
parameters = struct([]);
disturbance = struct([]);
localUpperBounds = [NaN,NaN];
if runSimulation
    [~,~,~,parameters] = stn_gpe_equilibrium(Kd);
    localUpperBounds = local_slope_upper_bounds(parameters,betaBar);
    delta = @(z) equilibrium_centered_sigmoid(z,parameters);
    [wp,disturbance] = performance_disturbance( ...
        disturbanceType,disturbanceAmplitude,disturbanceFrequency, ...
        disturbanceStartTime,disturbanceEndTime,simulationFinalTime, ...
        whiteNoiseRMS,whiteNoiseSampleRate,whiteNoiseSeed);

    ThetaPrimal = factor_box(Psi.primal,2+synthesis.zpDim, ...
        synthesis.P.vars,synthesis.P.dom);
    simOpen = simulate_open_loop(synthesis.P,delta,wp, ...
        simulationFinalTime,synthesis.zpDim,PsiP,muControl);
    simClosed = simulate_controlled_loop(synthesis.P,ThetaPrimal,K, ...
        delta,wp,simulationFinalTime,synthesis.zpDim,PsiP,muControl);
    simOpen.psd = estimate_performance_psd( ...
        simOpen,disturbanceStartTime,disturbanceEndTime);
    simClosed.psd = estimate_performance_psd( ...
        simClosed,disturbanceStartTime,disturbanceEndTime);
    if plotSimulation
        plot_performance_simulation(simOpen,simClosed,Kd);
        plot_local_domain(simOpen,simClosed,localUpperBounds,betaBar);
        plot_local_slope_restriction(parameters,localUpperBounds, ...
            betaBar,Kd);
    end
end

%% Results overview
fprintf('\nExample 4: STN--GPe robust-performance synthesis\n');
fprintf('Disease level Kd:                    %.4g\n',Kd);
fprintf('Control location:                    %s\n',controlLocation);
if ~isempty(disturbance)
    fprintf('Simulation disturbance:              %s\n',disturbance.description);
end
fprintf('Local slope bounds [betaS,betaG]:    [%.4g, %.4g]\n',betaBar);
fprintf('Multiplier weights [sec,ZF]:         [%.4g, %.4g]\n', ...
    lambdaSector,lambdaZF);
fprintf('ZF kernel L1 norms [S,G]:            [%.10g, %.10g]\n', ...
    ThetaDelta.hNormL1);
if useLowPassPerformanceFilter
    fprintf('Performance filter:                  makeweight low pass\n');
    fprintf('Low-pass point [rad/s,dB]:           [%.4g, %.4g]\n', ...
        lowPassFrequency,mag2db(lowPassMagnitude));
    fprintf('Low-pass gains [DC,high-freq] dB:    [%.4g, %.4g]\n', ...
        mag2db(lowPassDCGain),mag2db(lowPassHighFrequencyGain));
else
    fprintf('Performance filter:                  identity\n');
end
fprintf('Control-performance weight mu:       %.4g\n',muControl);
fprintf('Synthesis solution available:                  %d\n',synthesis.solutionAvailable);
fprintf('Synthesis residual:                  %.3e\n',synthesis.residual);
fprintf('Synthesis feasratio:                 %.6g\n',synthesis.feasratio);
fprintf('Synthesis numerr:                    %g\n',synthesis.numerr);
fprintf('Multiplier scalings [muS,muG]:       [%.6g, %.6g]\n',synthesis.mu);
fprintf('Optimized induced L2-gain bound:     %.6g\n',synthesis.gamma);
fprintf('Primal solution available:            %d\n',analysis.primal.solutionAvailable);
fprintf('Primal analysis residual:            %.3e\n',analysis.primal.residual);
fprintf('Primal analysis feasratio:           %.6g\n',analysis.primal.feasratio);
fprintf('Primal analysis numerr:              %g\n',analysis.primal.numerr);
fprintf('Primal optimized induced L2 gain:    %.6g\n',analysis.primal.gamma);
fprintf('Primal multiplier scales [muS,muG]: [%.6g, %.6g]\n', ...
    analysis.primal.mu);
if ~isempty(analysis.primal.message)
    fprintf('Primal analysis message:             %s\n', ...
        analysis.primal.message);
end
fprintf('Dual solution available:              %d\n',analysis.dual.solutionAvailable);
fprintf('Dual analysis residual:              %.3e\n',analysis.dual.residual);
fprintf('Dual analysis feasratio:             %.6g\n',analysis.dual.feasratio);
fprintf('Dual analysis numerr:                %g\n',analysis.dual.numerr);
fprintf('Dual optimized induced L2 gain:      %.6g\n',analysis.dual.gamma);
fprintf('Dual multiplier scales [muS,muG]:   [%.6g, %.6g]\n', ...
    analysis.dual.mu);
if ~isempty(analysis.dual.message)
    fprintf('Dual analysis message:               %s\n', ...
        analysis.dual.message);
end
if ~isempty(simClosed)
    fprintf('Local upper bounds [zS,zG]:          [%.6g, %.6g]\n', ...
        localUpperBounds);
    fprintf('Open loop inside local domain:       [%d, %d]\n', ...
        max(simOpen.zDelta,[],1)<=localUpperBounds);
    fprintf('Closed loop inside local domain:     [%d, %d]\n', ...
        max(simClosed.zDelta,[],1)<=localUpperBounds);
    fprintf('Open-loop simulated L2 ratio:        %.6g\n',simOpen.gamma);
    fprintf('Closed-loop simulated L2 ratio:      %.6g\n',simClosed.gamma);
    zpLabels = performance_output_labels(controlLocation);
    fprintf(['Simulated component L2 ratios ', ...
        '||(zp)_i||_2/||wp||_2:\n']);
    for channelIndex = 1:numel(zpLabels)
        fprintf('  wp -> %-8s: open = %.6g, closed = %.6g\n', ...
            zpLabels{channelIndex}, ...
            simOpen.gammaByOutput(channelIndex), ...
            simClosed.gammaByOutput(channelIndex));
    end
    fprintf('Maximum absolute controller input:  ');
    fprintf(' %.6g',max(abs(simClosed.u),[],1));
    fprintf('\n');
end
componentPDFPath = '';
componentTeXPath = '';
componentCompileMessage = '';
if displayComponents || saveComponentsLaTeX || saveComponentsPDF
    componentLaTeX = iqc_components_latex( ...
        Psi,ThetaDelta,PsiP,synthesis,analysis,K,controlLocation);
    if displayComponents
        fprintf('%s\n',componentLaTeX);
    end
    if saveComponentsLaTeX || saveComponentsPDF
        componentTeXPath = fullfile(fileparts(mfilename('fullpath')), ...
            'Example_4_IQC_components.tex');
        writelines(componentLaTeX,componentTeXPath,'Encoding','UTF-8');
        fprintf('PI-operator LaTeX report:             %s\n',componentTeXPath);
    end
    if saveComponentsPDF
        [componentPDFPath,componentCompileMessage] = ...
            compile_latex_report(componentTeXPath);
        if isempty(componentCompileMessage)
            fprintf('PI-operator PDF report:               %s\n', ...
                componentPDFPath);
        else
            fprintf('PI-operator PDF message:              %s\n', ...
                componentCompileMessage);
        end
    end
end

Results = struct('synthesis',synthesis,'K',K, ...
    'Kd',Kd,'analysis',analysis,'PsiP',PsiP,'ThetaDelta',ThetaDelta, ...
    'lambdaSector',lambdaSector,'lambdaZF',lambdaZF, ...
    'aS',aS,'kappaS',kappaS,'aG',aG,'kappaG',kappaG, ...
    'localUpperBounds',localUpperBounds, ...
    'disturbance',disturbance, ...
    'componentPDFPath',componentPDFPath, ...
    'componentTeXPath',componentTeXPath, ...
    'componentCompileMessage',componentCompileMessage, ...
    'simOpen',simOpen,'simClosed',simClosed);

function result = analyze_closed_loop_performance( ...
        P,K,zpDim,settings,PsiPrimal,PsiDual)
% Theta*[K star P;I] and D(Theta)*[(K star P)^T;I], Eqs. (3) and (6).
ThetaPrimal = factor_box(PsiPrimal,2+zpDim,P.vars,P.dom);
ThetaDual = factor_box(PsiDual,3,P.vars,P.dom);
Gprimal = PIETOOLS_IQC_primal_graph(P,ThetaPrimal,K);
Gdual = PIETOOLS_IQC_dual_graph(P,ThetaDual,K);
result.primal = analyze_performance_graph( ...
    Gprimal,zpDim,1,settings,P.vars,P.dom);
result.dual = analyze_performance_graph( ...
    Gdual,1,zpDim,settings,P.vars,P.dom);
end

function result = analyze_performance_graph( ...
        G,positivePerformanceDim,negativePerformanceDim,settings,vars,dom)
result = failed_analysis_result();
prog = lpiprogram(vars(:,1),vars(:,2),dom);
% rho=gamma^2 is minimized; muS and muG scale the two uncertainty IQCs.
[prog,rho] = lpidecvar(prog,'rhoAnalysis');
prog = lpi_ineq(prog,rho);
[prog,muS] = poslpivar(prog,[1;0],0);
[prog,muG] = poslpivar(prog,[1;0],0);
muS = muS+settings.inverseFloor*eyePI([1;0],vars,dom);
muG = muG+settings.inverseFloor*eyePI([1;0],vars,dom);
Mu = blkdiag(muS,muG);
% Primal: diag(Mu,I_zp,-Mu,-rho*I_wp).
% Dual:   diag(Mu,I_wp,-Mu,-rho*I_zp).
V = blkdiag(Mu,eyePI([positivePerformanceDim;0],vars,dom), ...
    -Mu,-rho*eyePI([negativePerformanceDim;0],vars,dom));
prog = lpisetobj(prog,rho);
try
    [storage,prog] = PIETOOLS_IQC_analysis(prog,settings,G,V);
catch analysisError
    result.message = analysisError.message;
    return
end
solverResult = solver_diagnostics(prog);
if isempty(storage)
    result.solinfo = solverResult.solinfo;
    result.solutionAvailable = solverResult.solutionAvailable;
    result.residual = solverResult.residual;
    result.feasratio = solverResult.feasratio;
    result.pinf = solverResult.pinf;
    result.dinf = solverResult.dinf;
    result.numerr = solverResult.numerr;
    result.message = solverResult.message;
    return
end
result = solverResult;
result.rho = double(lpigetsol(prog,rho));
result.gamma = sqrt(result.rho);

result.mu = [solution_scalar(prog,muS),solution_scalar(prog,muG)];
result.storage = storage;
result.message = '';
end

function result = failed_analysis_result()
result.solutionAvailable = false;
result.residual = NaN;
result.feasratio = NaN;
result.pinf = NaN;
result.dinf = NaN;
result.numerr = NaN;
result.rho = NaN;
result.gamma = NaN;
result.mu = [NaN,NaN];
result.storage = [];
result.message = '';
end

function result = synthesize_performance(Kd,controlLocation,tau, ...
        muControl,settings,Psi)
% P has w=[w_Delta;w_p], z=[z_Delta;z_p], and the state-feedback port u.
[P,numberOfControls] = stn_gpe_plant( ...
    Kd,controlLocation,tau,muControl);
zpDim = 2+numberOfControls;
Theta.dual = factor_box(Psi.dual,3,P.vars,P.dom);

prog = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
% rho=gamma^2 and Mu=diag(muS,muG) parameterize underline V.
[prog,rho] = lpidecvar(prog,'rho');
prog = lpi_ineq(prog,rho);
[prog,muS] = poslpivar(prog,[1;0],0);
[prog,muG] = poslpivar(prog,[1;0],0);
muS = muS+settings.inverseFloor*eyePI([1;0],P.vars,P.dom);
muG = muG+settings.inverseFloor*eyePI([1;0],P.vars,P.dom);
Mu = blkdiag(muS,muG);
% underline V=diag(Mu,I_wp,-Mu,-rho*I_zp), in the dual order above.
Vdual = blkdiag(Mu,eyePI([1;0],P.vars,P.dom),-Mu, ...
    -rho*eyePI([zpDim;0],P.vars,P.dom));
prog = lpisetobj(prog,rho);
[K,Z,storage,prog] = PIETOOLS_IQC_controller_synthesis( ...
    prog,settings,P,Theta,Vdual);
% The executive implements Z=P*[K_P';K_Theta'] and recovers
% K=[K_P,K_Theta]=Z'*P^(-1), exactly as in the state-feedback corollary.

result=solver_diagnostics(prog);
result.rho=NaN; result.gamma=NaN; result.mu=[NaN,NaN];
result.K=[]; result.P=P; result.zpDim=zpDim;
result.storage=storage; result.Z=Z;
if isempty(K)
    result.solutionAvailable=false;
    return;
end
result.rho=double(lpigetsol(prog,rho));
result.mu=[solution_scalar(prog,muS),solution_scalar(prog,muG)];
result.gamma=sqrt(result.rho);
result.K=K;
end
function [P,numberOfControls] = stn_gpe_plant(Kd,controlLocation,tau,muControl)
% PIE realization of Eq. (21).
weights = stn_gpe_weights(Kd);
wSG = weights(1);
wGS = weights(2);
wGG = weights(3);

pvar t s
xS = pde_var('state');
xG = pde_var('state');
% phi_ij(t,s)=x_i(t-tau_ij*s) are the three transport-delay states.
phiGS = pde_var(s,[0,1]);
phiSG = pde_var(s,[0,1]);
phiGG = pde_var(s,[0,1]);
% zDelta=[zS;zG] is the input of delta; wDelta=[wS;wG]=delta(zDelta).
zS = pde_var('output',1);
zG = pde_var('output',1);
wS = pde_var('input',1);
wG = pde_var('input',1);
% wp is the exogenous performance input in Eq. (21).
wp = pde_var('input',1);

switch lower(controlLocation)
    case 'xs'
        u = pde_var('control',1);
        controlSignal = u;
        xSEquation = diff(xS,t) == (1/tau.tauS)*(wS-xS)+4.6e3*u+wp;
        xGEquation = diff(xG,t) == (1/tau.tauG)*(wG-xG);
        numberOfControls = 1;
    case 'xg'
        u = pde_var('control',1);
        controlSignal = u;
        xSEquation = diff(xS,t) == (1/tau.tauS)*(wS-xS)+wp;
        xGEquation = diff(xG,t) == (1/tau.tauG)*(wG-xG)+4.6e3*u;
        numberOfControls = 1;
    case 'both'
        uS = pde_var('control',1);
        uG = pde_var('control',1);
        controlSignal = [uS;uG];
        xSEquation = diff(xS,t) == (1/tau.tauS)*(wS-xS)+4.6e3*uS+wp;
        xGEquation = diff(xG,t) == (1/tau.tauG)*(wG-xG)+4.6e3*uG;
        numberOfControls = 2;
    otherwise
        error('controlLocation must be ''xS'', ''xG'', or ''both''.');
end
zp = pde_var('output',2+numberOfControls);

% First two rows: the equilibrium-shifted firing-rate dynamics.
% Next three rows: the delay transport PDEs. The remaining rows define
% zDelta, zp=[xS;xG;mu*u], and the transport boundary conditions.
PDE = [xSEquation;
       xGEquation;
       diff(phiGS,t) == -(1/tau.tauGS)*diff(phiGS,s);
       diff(phiSG,t) == -(1/tau.tauSG)*diff(phiSG,s);
       diff(phiGG,t) == -(1/tau.tauGG)*diff(phiGG,s);
       zS == -wGS*subs(phiGS,s,1);
       zG == wSG*subs(phiSG,s,1)-wGG*subs(phiGG,s,1);
       zp == [xS;xG;muControl*controlSignal];
       subs(phiGS,s,0) == xG;
       subs(phiSG,s,0) == xS;
       subs(phiGG,s,0) == xG];

PDE = initialize(PDE,true);
% PIETOOLS may reorder channels during conversion. Supplying this order
% preserves w=[wDelta;wp], z=[zDelta;zp], as assumed by the IQC blocks.
[~,order] = reorder_comps(PDE,'all',true);
assert(isequal(order.z(:),(1:3).') ...
        && isequal(order.w(:),(1:3).'), ...
    'Unexpected channel ordering: z=%s, w=%s.', ...
    mat2str(order.z(:).'),mat2str(order.w(:).'));
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
% Each jfactor call returns both factors; the primal factor is retained
% directly and is not reconstructed from the dual factor.
[PsiS,DPsiS,hNormS,multiplierS] = scalar_multiplier( ...
    betaBar(1),aS,kappaS,lambdaSector,lambdaZF,epsilonIQC);
[PsiG,DPsiG,hNormG,multiplierG] = scalar_multiplier( ...
    betaBar(2),aG,kappaG,lambdaSector,lambdaZF,epsilonIQC);
order = [1,3,2,4];
Psi = blkdiag(PsiS,PsiG);
DPsi = blkdiag(DPsiS,DPsiG);
% Per-channel factors are interlaced by blkdiag. Reorder them to the paper
% convention [zS;zG;wS;wG] and [wS;wG;zS;zG], respectively.
ThetaDelta.primal = minreal(Psi(order,order),1e-9);
ThetaDelta.dual = minreal(DPsi(order,order),1e-9);
ThetaDelta.hNormL1 = [hNormS,hNormG];
ThetaDelta.multiplier.S = multiplierS;
ThetaDelta.multiplier.G = multiplierG;
end

function [PsiPrimal,PsiDual,hNormL1,multiplier] = scalar_multiplier( ...
        betaBar,a,kappa,lambdaSector,lambdaZF,epsilonIQC)
assert(all(a>0) && all(kappa>=0));
q = tf('s');
H = 0;
for index = 1:numel(a)
    H = H+kappa(index)/(q+a(index));
end
hNormL1 = sum(kappa./a);
assert(hNormL1<=1+1e-12, ...
    'The Zames--Falb kernel must satisfy ||H||_1 <= 1.');
M = minreal(ss(1-H),1e-9);
% Sector and Zames--Falb multipliers in Eqs. (24) and (25).
T = [betaBar,-1;0,1];
PiSector = T'*[0,1;1,0]*T;
PiZF = [0,betaBar*M';betaBar*M,-(M+M')];
% Combined multiplier in Eq. (26); epsilon enters only in this sum.
Pi = minreal(ss(lambdaSector*PiSector+lambdaZF*PiZF ...
    +epsilonIQC*diag([1,-1])),1e-9);
[PsiPrimal,PsiDual] = jfactor(Pi,1,1);
multiplier.H = minreal(ss(H),1e-9);
multiplier.M = M;
multiplier.PiSector = ss(PiSector);
multiplier.PiZF = minreal(ss(PiZF),1e-9);
multiplier.Pi = Pi;
end

function PsiP = performance_filter(useLowPass,dcGain,frequency, ...
        frequencyMagnitude,highFrequencyGain,controlLocation)
% Replace W_beta in Eq. (22) by the biproper low-pass weight W_p.
if useLowPass
    assert(dcGain>frequencyMagnitude && ...
        frequencyMagnitude>highFrequencyGain && frequency>0);
    Wperformance = minreal(ss(makeweight(dcGain,[frequency,frequencyMagnitude],highFrequencyGain)),1e-9);
else
    Wperformance = ss(1);
end
WperformanceInverse = minreal(1/Wperformance,1e-9);
numberOfControls = 1+strcmpi(controlLocation,'both');
controlFilter = ss(eye(numberOfControls));
Wz = blkdiag(Wperformance,Wperformance,controlFilter);
PsiP.primal = minreal(blkdiag(Wz,ss(1)),1e-9);
PsiP.dual = dual_factor(PsiP.primal,2+numberOfControls,1);
PsiP.Wperformance = Wperformance;
PsiP.WperformanceInverse = WperformanceInverse;
assert(all(real(pole(Wperformance))<0) && ...
    all(real(pole(WperformanceInverse))<0), ...
    'The performance weight and its inverse must be stable.');
end

function PsiDual = dual_factor(PsiPrimal,nPositive,nNegative)
% Definition (J-spectral factorization and dual filter):
% D(Psi)=(Jhat'*Psi^T*Jhat)^(-1), written in state-space form.
Jhat = [zeros(nPositive,nNegative),eye(nPositive); ...
       -eye(nNegative),zeros(nNegative,nPositive)];
[A,B,C,D] = ssdata(PsiPrimal);
Dh = Jhat'*D.'*Jhat;
Dd = Dh\eye(size(Dh));
PsiDual = minreal(ss(A.'-C.'*Jhat*Dd*Jhat'*B.', ...
    C.'*Jhat*Dd,-Dd*Jhat'*B.',Dd),1e-9);
end

function combined = combine_factors(first,second,p1,n1,p2,n2)
% diag(ThetaDelta,PsiP), permuted from two separate [positive;negative]
% pairs to the single [all positive;all negative] convention of Section 3.
raw = blkdiag(first,second);
nFirst = p1+n1;
order = [1:p1,nFirst+(1:p2),p1+(1:n1),nFirst+p2+(1:n2)];
combined = minreal(raw(order,order),1e-9);
end

function sim = simulate_open_loop(P,delta,wp,tFinal,zpDim,PsiP,muControl)
tgrid = linspace(0,tFinal,1001).';
x0.ode = [0;0];
x0.pde = {0,0,0};
opts = simulation_options(wp);
sim = PIE_sim_nl(P,delta,tgrid,x0,opts);
sim.zDelta = sim.zFinite(:,1:2);
sim.u = zeros(numel(sim.t),zpDim-2);
sim = reconstruct_stn_gpe_state(sim,2);
sim = performance_ratio(sim,PsiP.Wperformance,muControl);
end

function sim = simulate_controlled_loop(P,Theta,K,delta,wp,tFinal, ...
        zpDim,PsiP,muControl)
G = PIETOOLS_IQC_primal_graph(P,Theta,K);
% Keep the graph dynamics, but expose the physical outputs because
% PIE_sim_nl must close delta around zDelta rather than the filtered IQC
% output returned in G.C1.
zeroTheta = matrix_operator(zeros(sum(P.C1.dim(:,1)), ...
    sum(Theta.T.dim(:,2))),P.vars,P.dom);
Cplant = block_hcat(P.C1,zeroTheta,P.vars,P.dom)+P.D12*K;
zeroFeedthrough = zero_operator(K.dim(:,1),P.D11.dim(:,2), ...
    G.vars,G.dom);
G.C1 = block_vcat(Cplant,K,G.vars,G.dom);
G.D11 = block_vcat(P.D11,zeroFeedthrough,G.vars,G.dom);
G.x_tab = P.x_tab;
emptyDimension = [0;0];
G.Tw = zero_operator(G.T.dim(:,1),G.B1.dim(:,2),G.vars,G.dom);
G.B2 = zero_operator(G.T.dim(:,1),emptyDimension,G.vars,G.dom);
G.Tu = zero_operator(G.T.dim(:,1),emptyDimension,G.vars,G.dom);
G.D12 = zero_operator(G.C1.dim(:,1),emptyDimension,G.vars,G.dom);
G.D22 = zero_operator(G.C2.dim(:,1),emptyDimension,G.vars,G.dom);
G.misc = struct();

numberOfFilterStates = sum(Theta.T.dim(:,2));
tgrid = linspace(0,tFinal,1001).';
x0.ode = zeros(2+numberOfFilterStates,1);
x0.pde = {0,0,0};
opts = simulation_options(wp);
sim = PIE_sim_nl(G,delta,tgrid,x0,opts);
sim.zDelta = sim.zFinite(:,1:2);
sim.u = sim.outputFinite(:,3+zpDim:end);
sim = reconstruct_stn_gpe_state(sim,2+numberOfFilterStates);
sim = performance_ratio(sim,PsiP.Wperformance,muControl);
end

function opts = simulation_options(wp)
opts.N = 24;
opts.nwd0 = 2;
opts.wp = wp;
opts.splot = linspace(0,1,151).';
opts.ode = odeset('RelTol',1e-7,'AbsTol',1e-9);
end

function sim = performance_ratio(sim,Wperformance,mu)
weightedStates = [lsim(Wperformance,sim.xS,sim.t), ...
    lsim(Wperformance,sim.xG,sim.t)];
weightedOutput = [weightedStates,mu*sim.u];
inputEnergy = trapz(sim.t,sum(sim.wp.^2,2));
outputEnergyByOutput = trapz(sim.t,weightedOutput.^2,1);
outputEnergy = sum(outputEnergyByOutput);
sim.gamma = sqrt(outputEnergy/max(inputEnergy,eps));
sim.gammaByOutput = sqrt(outputEnergyByOutput/max(inputEnergy,eps));
sim.weightedOutput = weightedOutput;
end

function labels = performance_output_labels(controlLocation)
switch lower(controlLocation)
    case 'xs'
        labels = {'x_S','x_G','mu*u_S'};
    case 'xg'
        labels = {'x_S','x_G','mu*u_G'};
    case 'both'
        labels = {'x_S','x_G','mu*u_S','mu*u_G'};
    otherwise
        error('controlLocation must be ''xS'', ''xG'', or ''both''.');
end
end

function [wp,info] = performance_disturbance(type,sineAmplitude, ...
        sineFrequency,startTime,endTime,finalTime,whiteNoiseRMS, ...
        whiteNoiseSampleRate,whiteNoiseSeed)
validateattributes(startTime,{'numeric'},{'scalar','nonnegative'});
validateattributes(endTime,{'numeric'},{'scalar','>',startTime, ...
    '<=',finalTime});
switch lower(strrep(type,'_',''))
    case 'sine'
        wp = @(t) sineAmplitude*sin(2*pi*sineFrequency*t) ...
            .*(t>=startTime & t<=endTime);
        info.type = 'sine';
        info.description = sprintf( ...
            'sine, %.4g Hz, peak %.4g',sineFrequency,sineAmplitude);
        info.sampleRate = NaN;
        info.seed = NaN;
    case {'whitenoise','white'}
        validateattributes(whiteNoiseSampleRate,{'numeric'}, ...
            {'scalar','positive'});
        validateattributes(whiteNoiseRMS,{'numeric'}, ...
            {'scalar','nonnegative'});
        noiseTime = (0:1/whiteNoiseSampleRate:finalTime).';
        if noiseTime(end)<finalTime
            noiseTime(end+1,1) = finalTime;
        end
        active = noiseTime>=startTime & noiseTime<=endTime;
        stream = RandStream('mt19937ar','Seed',whiteNoiseSeed);
        activeNoise = randn(stream,nnz(active),1);
        activeNoise = whiteNoiseRMS*activeNoise/ ...
            max(sqrt(mean(activeNoise.^2)),eps);
        noiseSamples = zeros(size(noiseTime));
        noiseSamples(active) = activeNoise;
        wp = @(t) interp1(noiseTime,noiseSamples,t,'previous',0);
        info.type = 'whiteNoise';
        info.description = sprintf( ...
            'sampled white noise, RMS %.4g, fs %.4g Hz, seed %d', ...
            whiteNoiseRMS,whiteNoiseSampleRate,whiteNoiseSeed);
        info.sampleRate = whiteNoiseSampleRate;
        info.seed = whiteNoiseSeed;
    otherwise
        error('disturbanceType must be ''sine'' or ''whiteNoise''.');
end
info.startTime = startTime;
info.endTime = endTime;
end

function spectrum = estimate_performance_psd(sim,startTime,endTime)
% Welch estimates for wp, z1=xS, z2=xG, and the empirical transfers
% S_{wp,zi}/S_{wp,wp}.  The estimates use only the forced time interval.
sampleMask = sim.t>=startTime & sim.t<=endTime;
time = sim.t(sampleMask);
input = detrend(sim.wp(sampleMask,1),0);
outputs = detrend(sim.weightedOutput(sampleMask,1:2),0);
if numel(time)<32
    error('At least 32 simulation samples are required for the PSD.');
end
sampleRate = 1/median(diff(time));
windowLength = min(256,2^floor(log2(numel(time)/2)));
windowLength = max(windowLength,16);
window = hann(windowLength,'periodic');
overlap = floor(windowLength/2);
nfft = max(512,2^nextpow2(windowLength));
[inputPSD,frequency] = pwelch( ...
    input,window,overlap,nfft,sampleRate,'onesided');
outputPSD = zeros(numel(frequency),2);
crossPSD = zeros(numel(frequency),2);
transfer = zeros(numel(frequency),2);
coherence = zeros(numel(frequency),2);
for channelIndex = 1:2
    outputPSD(:,channelIndex) = pwelch( ...
        outputs(:,channelIndex),window,overlap,nfft,sampleRate,'onesided');
    crossPSD(:,channelIndex) = cpsd( ...
        input,outputs(:,channelIndex),window,overlap,nfft, ...
        sampleRate,'onesided');
    transfer(:,channelIndex) = crossPSD(:,channelIndex)./ ...
        max(inputPSD,eps);
    coherence(:,channelIndex) = mscohere( ...
        input,outputs(:,channelIndex),window,overlap,nfft, ...
        sampleRate,'onesided');
end
spectrum.frequency = frequency;
spectrum.input = inputPSD;
spectrum.output = outputPSD;
spectrum.cross = crossPSD;
spectrum.transfer = transfer;
spectrum.coherence = coherence;
spectrum.sampleRate = sampleRate;
spectrum.windowLength = windowLength;
end

function sim = reconstruct_stn_gpe_state(sim,numberOfFiniteStates)
primary = sim.Dop.Tcheb_2PDEstate*sim.x.';
sim.xS = primary(1,:).';
sim.xG = primary(2,:).';
pdeCoefficients = primary(numberOfFiniteStates+1:end,:);
numberOfCoefficients = size(pdeCoefficients,1)/3;
assert(abs(numberOfCoefficients-round(numberOfCoefficients))<1e-12);
degree = round(numberOfCoefficients)-1;
E = chebyshev_evaluation(2*sim.splot-1,degree);
fieldNames = {'phiGS','phiSG','phiGG'};
for channel = 1:3
    rows = (channel-1)*(degree+1)+(1:degree+1);
    sim.(fieldNames{channel}) = real((E*pdeCoefficients(rows,:)).');
end
end

function E = chebyshev_evaluation(points,degree)
points = points(:);
E = zeros(numel(points),degree+1);
E(:,1) = 1;
if degree>=1
    E(:,2) = points;
end
for index = 2:degree
    E(:,index+1) = 2*points.*E(:,index)-E(:,index-1);
end
end

function plot_performance_simulation(simOpen,simClosed,Kd)
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
colorbar;

nexttile;
plot(simOpen.t,simOpen.xS,'--',simClosed.t,simClosed.xS, ...
    'LineWidth',1.4);
xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
ylabel('$x_{\mathrm S}(t)$','Interpreter','latex');
legend({'Open loop','Closed loop'},'Interpreter','latex','Location','best');
set(gca,'TickLabelInterpreter','latex'); grid on;

nexttile;
plot(simOpen.t,simOpen.xG,'--',simClosed.t,simClosed.xG, ...
    'LineWidth',1.4);
xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
ylabel('$x_{\mathrm G}(t)$','Interpreter','latex');
legend({'Open loop','Closed loop'},'Interpreter','latex','Location','best');
set(gca,'TickLabelInterpreter','latex'); grid on;

nexttile;
plot(simClosed.t,4.6e+3*simClosed.u,'LineWidth',1.4); hold on;
plot(simClosed.t,simClosed.wp,'--k','LineWidth',1.2); hold off;
xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
ylabel('$u(t),\,w_{\mathrm p}(t)$','Interpreter','latex');
legend({'$u$','$w_{\mathrm p}$'},'Interpreter','latex','Location','best');
set(gca,'TickLabelInterpreter','latex'); grid on;
end

function plot_local_domain(simOpen,simClosed,upperBounds,betaBar)
figure('Color','w','Units','inches','Position',[1,1,7,7]);
layout = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
names = {'S','G'};
for channel = 1:2
    nexttile(layout);
    plot(simOpen.t,simOpen.zDelta(:,channel),'--','LineWidth',1.3); hold on;
    plot(simClosed.t,simClosed.zDelta(:,channel),'LineWidth',1.5);
    yline(upperBounds(channel),':k','LineWidth',1.3); hold off;
    xlabel('$t\,[\mathrm{s}]$','Interpreter','latex');
    ylabel(sprintf('$z_{\\Delta,\\mathrm{%s}}(t)$',names{channel}), ...
        'Interpreter','latex');
    title(sprintf(['$z_{\\Delta,\\mathrm{%s}}\\leq r_{\\mathrm{%s}},' ...
        '\\quad 0\\leq\\delta_{\\mathrm{%s}}''\\leq %.3g$'], ...
        names{channel},names{channel},names{channel},betaBar(channel)), ...
        'Interpreter','latex');
    legend({'Open loop','Closed loop','Upper threshold'}, ...
        'Interpreter','latex','Location','best');
    set(gca,'TickLabelInterpreter','latex'); grid on;
end
end

function plot_local_slope_restriction(parameters,upperBounds,betaBar,Kd)
figure('Color','w','Units','inches','Position',[1,1,7,7]);
layout = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
names = {'S','G'};
equilibria = [parameters.uS0,parameters.uG0];
maximumRates = [parameters.MS,parameters.MG];
baselineRates = [parameters.BS,parameters.BG];
for channel = 1:2
    zLower = -1.25*upperBounds(channel);
    zUpper = 1.5*upperBounds(channel);
    z = linspace(zLower,zUpper,1200);
    output = stn_gpe_sigmoid(equilibria(channel)+z, ...
        maximumRates(channel),baselineRates(channel));
    derivative = 4*(output/maximumRates(channel)) ...
        .*(1-output/maximumRates(channel));
    nexttile(layout); hold on;
    patch([zLower,upperBounds(channel),upperBounds(channel),zLower], ...
        [0,0,1.05,1.05],[0.82,0.90,1.00], ...
        'EdgeColor','none','FaceAlpha',0.45);
    plot(z,derivative,'LineWidth',1.7);
    yline(betaBar(channel),'--k','LineWidth',1.3);
    xline(upperBounds(channel),':k','LineWidth',1.1);
    hold off; xlim([zLower,zUpper]); ylim([0,1.05]); grid on;
    xlabel(sprintf('$z_{\\Delta,\\mathrm{%s}}$',names{channel}), ...
        'Interpreter','latex');
    ylabel(sprintf('$\\delta_{\\mathrm{%s}}''$',names{channel}), ...
        'Interpreter','latex');
    title(sprintf('Local slope restriction for $\\delta_{\\mathrm{%s}}$', ...
        names{channel}),'Interpreter','latex');
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

function upperBound = connected_slope_upper_bound(inputEquilibrium,M,B,beta)
equilibriumOutput = stn_gpe_sigmoid(inputEquilibrium,M,B);
equilibriumSlope = 4*(equilibriumOutput/M)*(1-equilibriumOutput/M);
assert(beta>0 && beta<1 && equilibriumSlope<=beta+1e-12);
pLower = 0.5*(1-sqrt(1-beta));
inputLower = (M/4)*log(((M-B)/B)*pLower/(1-pLower));
assert(inputEquilibrium<=inputLower, ...
    'The equilibrium must lie on the lower sigmoid branch.');
upperBound = inputLower-inputEquilibrium;
end

function [pdfPath,message] = compile_latex_report(texPath)
% Compile twice so all report references are resolved, while retaining TeX.
[reportDirectory,reportName] = fileparts(texPath);
pdfPath = fullfile(reportDirectory,[reportName,'.pdf']);
message = '';
command = sprintf(['pdflatex -interaction=nonstopmode -halt-on-error ', ...
    '-output-directory="%s" "%s"'],reportDirectory,texPath);
for compilePass = 1:2
    [status,compilerOutput] = system(command);
    if status~=0
        pdfPath = '';
        outputLines = splitlines(strtrim(string(compilerOutput)));
        outputLines = outputLines(max(1,numel(outputLines)-7):end);
        message = sprintf('pdflatex pass %d failed: %s', ...
            compilePass,strjoin(outputLines,' '));
        warning('%s',message);
        return
    end
end
if ~isfile(pdfPath)
    message = 'pdflatex completed without producing the expected PDF.';
    pdfPath = '';
    warning('%s',message);
end
end

function latexText = iqc_components_latex(Psi,ThetaDelta,PsiP,synthesis,analysis,K,controlLocation)
% Standalone LaTeX report of the actual solved PI operators.  Every entry
% is represented by its Pi_4 kernels (P,Q1,Q2,R0,R1,R2), not by a PIE
% differential realization.
P = synthesis.P;
zpDim = synthesis.zpDim;
ThetaPrimal = factor_box(Psi.primal,2+zpDim,P.vars,P.dom);
ThetaDual = factor_box(Psi.dual,3,P.vars,P.dom);
Gprimal = PIETOOLS_IQC_primal_graph(P,ThetaPrimal,K);
Gdual = PIETOOLS_IQC_dual_graph(P,ThetaDual,K);

lines = [
    "\documentclass{article}"
    "\usepackage[a3paper,landscape,margin=10mm]{geometry}"
    "\usepackage{amsmath,amssymb}"
    "\setlength{\parindent}{0pt}"
    "\newcommand{\PIop}[6]{\mathcal P\!\left[\begin{array}{c|c}#1&#2\\\hline#3&\{#4,#5,#6\}\end{array}\right]}"
    "\begin{document}"
    "\scriptsize"
    "\section*{Example 4: solved system components}"
    "Plant, controller, and augmented-graph components are displayed as PI operators through the six $\Pi_4$ kernels $(P,Q_1,Q_2,R_0,R_1,R_2)$. Dynamic filters are displayed as Laplace-domain transfer matrices. Omitted polynomial terms have zero coefficient."
    iqc_signal_ordering_latex(controlLocation)
    ];

lines = [lines; pi_operator_group_latex( ...
    "Generalized plant operator tuple", ...
    ["\mathcal T_P","\mathcal A_P","\mathcal B_P", ...
     "\mathcal B_u","\mathcal C_P","\mathcal D_P", ...
     "\mathcal D_{zu}"], ...
    {P.T,P.A,P.B1,P.B2,P.C1,P.D11,P.D12})];

lines = [lines; transfer_matrix_group_latex( ...
    "Laplace-domain multiplier and performance filters", ...
    ["H_S(s)","M_S(s)","H_G(s)","M_G(s)", ...
     "\Theta_\Delta(s)","\mathbf D(\Theta_\Delta)(s)", ...
     "W_{\mathrm p}(s)","W_{\mathrm p}^{-1}(s)", ...
     "\Theta_{\mathrm p}(s)", ...
     "\mathbf D(\Theta_{\mathrm p})(s)", ...
     "\Theta(s)","\mathbf D(\Theta)(s)"], ...
    {ThetaDelta.multiplier.S.H,ThetaDelta.multiplier.S.M, ...
     ThetaDelta.multiplier.G.H,ThetaDelta.multiplier.G.M, ...
     ThetaDelta.primal,ThetaDelta.dual, ...
     PsiP.Wperformance,PsiP.WperformanceInverse, ...
     PsiP.primal,PsiP.dual,Psi.primal,Psi.dual})];

lines = [lines; pi_operator_group_latex( ...
    "Recovered controller", "\mathcal K=[\mathcal K_P\;\mathcal K_\Theta]", ...
    {K})];

lines = [lines; pi_operator_group_latex( ...
    "Primal augmented graph $\Theta[(K\star P);I]$", ...
    ["\mathcal T","\mathcal A","\mathcal B", ...
     "\mathcal C_z","\mathcal C_w", ...
     "\mathcal D_z","\mathcal D_w"], ...
    {Gprimal.T,Gprimal.A,Gprimal.B1,Gprimal.C1,Gprimal.C2, ...
     Gprimal.D11,Gprimal.D21})];

lines = [lines; pi_operator_group_latex( ...
    "Dual augmented graph $\mathbf D(\Theta)[(K\star P)^*;I]$", ...
    ["\underline{\mathcal T}_{\rm cl}", ...
     "\underline{\mathcal A}_{\rm cl}", ...
     "\underline{\mathcal B}_{\rm cl}", ...
     "\underline{\mathcal C}_z", ...
     "\underline{\mathcal C}_w", ...
     "\underline{\mathcal D}_z", ...
     "\underline{\mathcal D}_w"], ...
    {Gdual.T,Gdual.A,Gdual.B1,Gdual.C1,Gdual.C2, ...
     Gdual.D11,Gdual.D21})];

lines = [lines
    "\section*{Solved performance signatures}"
    "\[\displaystyle " + ...
        "\underline V_{\rm syn}=" + ...
        polynomial_matrix_latex(dual_signature( ...
            synthesis.mu,synthesis.rho,zpDim)) + "\]"
    ];
if analysis.primal.solutionAvailable
    lines = [lines
        "\[\displaystyle V_{\rm ana}=" + ...
            polynomial_matrix_latex(primal_signature( ...
                analysis.primal.mu,analysis.primal.rho,zpDim)) + "\]"
        ];
else
    lines = [lines; "The primal analysis did not return a solution."];
end
if analysis.dual.solutionAvailable
    lines = [lines
        "\[\displaystyle " + ...
            "\underline V_{\rm ana}=" + ...
            polynomial_matrix_latex(dual_signature( ...
                analysis.dual.mu,analysis.dual.rho,zpDim)) + "\]"
        ];
end
lines = [lines
    "\paragraph{Controller location.} \texttt{" + ...
        latex_escape_text(controlLocation) + "}."
    "\end{document}"
    ];
latexText = strjoin(lines,newline);
end

function lines = iqc_signal_ordering_latex(controlLocation)
% State the row/column order used by the plant, filters, and graph blocks.
switch lower(controlLocation)
    case 'xs'
        controlEntries = "u_{\mathrm S}";
    case 'xg'
        controlEntries = "u_{\mathrm G}";
    case 'both'
        controlEntries = ["u_{\mathrm S}","u_{\mathrm G}"];
    otherwise
        error('controlLocation must be ''xS'', ''xG'', or ''both''.');
end
zpEntries = ["x_{\mathrm S}","x_{\mathrm G}","\mu "+controlEntries];
zEntries = ["z_{\mathrm S}","z_{\mathrm G}",zpEntries];
wEntries = ["w_{\mathrm S}","w_{\mathrm G}","w_{\mathrm p}"];
zpDimension = numel(zpEntries);
zDimension = numel(zEntries);
lines = [
    "\subsection*{Signal ordering: rows and columns}"
    "All vectors below are column vectors. The plant has $n_z="+zDimension+"$ regulated outputs, $n_w=3$ exogenous inputs, and $n_u="+numel(controlEntries)+"$ control inputs."
    "\[u=["+strjoin(controlEntries,",")+"]^\top,\qquad z_\Delta=[z_{\mathrm S},z_{\mathrm G}]^\top,\qquad w_\Delta=[w_{\mathrm S},w_{\mathrm G}]^\top=\delta(z_\Delta),\qquad z_{\mathrm p}=["+strjoin(zpEntries,",")+"]^\top.\]"
    "\[z=\begin{bmatrix}z_\Delta\\z_{\mathrm p}\end{bmatrix}=["+strjoin(zEntries,",")+"]^\top,\qquad w=\begin{bmatrix}w_\Delta\\w_{\mathrm p}\end{bmatrix}=["+strjoin(wEntries,",")+"]^\top.\]"
    "\paragraph{Primal filter.} The columns of $\Theta$ are ordered by $[z^\top,w^\top]^\top$; its rows are ordered by $[\widetilde z^\top,\widetilde w^\top]^\top$. Explicitly,"
    "\[\begin{bmatrix}\widetilde z_\Delta\\\widetilde z_{\mathrm p}\\\widetilde w_\Delta\\\widetilde w_{\mathrm p}\end{bmatrix}=\Theta\begin{bmatrix}z_\Delta\\z_{\mathrm p}\\w_\Delta\\w_{\mathrm p}\end{bmatrix},\qquad [z^\top,w^\top]^\top=["+strjoin([zEntries,wEntries],",")+"]^\top,\qquad\text{block sizes }(2,"+zpDimension+",2,1).\]"
    "\paragraph{Dual filter.} Dual channel positions correspond to $[w^\top,z^\top]^\top$: the dual plant output $\underline z\in\mathbb R^3$ has the channel order of $w$, and its input $\underline w\in\mathbb R^{"+zDimension+"}$ has the channel order of $z$. Underlined signals belong to the dual system."
    "\[\begin{bmatrix}\widetilde{\underline z}_\Delta\\\widetilde{\underline z}_{\mathrm p}\\\widetilde{\underline w}_\Delta\\\widetilde{\underline w}_{\mathrm p}\end{bmatrix}=\mathbf D(\Theta)\begin{bmatrix}\underline z_\Delta\\\underline z_{\mathrm p}\\\underline w_\Delta\\\underline w_{\mathrm p}\end{bmatrix},\qquad\text{channel positions }["+strjoin([wEntries,zEntries],",")+"]^\top,\qquad\text{block sizes }(2,1,2,"+zpDimension+").\]"
    "The scalar factors $H_i,M_i,W_{\mathrm p}$ act on their named channels. The uncertainty-factor row/column orders are $(z_{\mathrm S},z_{\mathrm G},w_{\mathrm S},w_{\mathrm G})$ for $\Theta_\Delta$ and $(w_{\mathrm S},w_{\mathrm G},z_{\mathrm S},z_{\mathrm G})$ for $\mathbf D(\Theta_\Delta)$. The performance-factor orders are $(z_{\mathrm p},w_{\mathrm p})$ for $\Theta_{\mathrm p}$ and $(w_{\mathrm p},z_{\mathrm p})$ for $\mathbf D(\Theta_{\mathrm p})$, with the same orders for their corresponding filtered outputs."
    "\paragraph{Graph and signature blocks.} In the primal graph, $(\mathcal C_z,\mathcal D_z)$ produce $\widetilde z$ ("+zDimension+" rows), while $(\mathcal C_w,\mathcal D_w)$ produce $\widetilde w$ (3 rows); both feedthrough blocks have input $w$ (3 columns). In the dual graph, $(\underline{\mathcal C}_z,\underline{\mathcal D}_z)$ produce $\widetilde{\underline z}$ (3 rows), while $(\underline{\mathcal C}_w,\underline{\mathcal D}_w)$ produce $\widetilde{\underline w}$ ("+zDimension+" rows); both feedthrough blocks have input $\underline w$ ("+zDimension+" columns)."
    "The primal signature $V$ uses the primal filtered order $(\widetilde z_\Delta,\widetilde z_{\mathrm p},\widetilde w_\Delta,\widetilde w_{\mathrm p})$. The dual signatures $\underline V$ use $(\widetilde{\underline z}_\Delta,\widetilde{\underline z}_{\mathrm p},\widetilde{\underline w}_\Delta,\widetilde{\underline w}_{\mathrm p})$."
    ];
end
function lines = transfer_matrix_group_latex(titleText,names,systems)
lines = "\section*{" + titleText + "}";
for systemIndex = 1:numel(systems)
    representation = names(systemIndex) + "=" + ...
        transfer_matrix_latex(systems{systemIndex});
    lines = [lines
        "\paragraph{$" + names(systemIndex) + "$}"
        "\[\displaystyle " + representation + "\]"
        ];
end
end

function text = transfer_matrix_latex(system)
transfer = minreal(tf(system),1e-9);
[numberOfOutputs,numberOfInputs] = size(transfer);
entries = strings(numberOfOutputs,numberOfInputs);
for outputIndex = 1:numberOfOutputs
    for inputIndex = 1:numberOfInputs
        [numerator,denominator] = tfdata( ...
            transfer(outputIndex,inputIndex),'v');
        numeratorText = laplace_polynomial_latex(numerator);
        denominatorText = laplace_polynomial_latex(denominator);
        if numeratorText=="0" || denominatorText=="1"
            entries(outputIndex,inputIndex) = numeratorText;
        else
            entries(outputIndex,inputIndex) = ...
                "\frac{" + numeratorText + "}{" + denominatorText + "}";
        end
    end
end
rows = strings(numberOfOutputs,1);
for outputIndex = 1:numberOfOutputs
    rows(outputIndex) = strjoin(entries(outputIndex,:)," & ");
end
if numberOfOutputs==1 && numberOfInputs==1
    text = rows(1);
else
    text = "\begin{bmatrix}" + strjoin(rows,"\\") + "\end{bmatrix}";
end
end

function expression = laplace_polynomial_latex(coefficients)
coefficients = coefficients(:).';
if isempty(coefficients)
    expression = "0";
    return
end
coefficientTolerance = 1e-12*max([1,abs(coefficients)]);
coefficients(abs(coefficients)<=coefficientTolerance) = 0;
firstNonzero = find(coefficients~=0,1,'first');
if isempty(firstNonzero)
    expression = "0";
    return
end
coefficients = coefficients(firstNonzero:end);
degree = numel(coefficients)-1;
expression = "";
for coefficientIndex = 1:numel(coefficients)
    coefficient = coefficients(coefficientIndex);
    if coefficient==0
        continue
    end
    exponent = degree-coefficientIndex+1;
    magnitude = abs(coefficient);
    if exponent==0
        term = number_latex(magnitude);
    elseif exponent==1
        if abs(magnitude-1)<=coefficientTolerance
            term = "s";
        else
            term = number_latex(magnitude) + "\,s";
        end
    elseif abs(magnitude-1)<=coefficientTolerance
        term = "s^{" + string(exponent) + "}";
    else
        term = number_latex(magnitude) + "\,s^{" + ...
            string(exponent) + "}";
    end
    if strlength(expression)==0
        if coefficient<0
            expression = "-" + term;
        else
            expression = term;
        end
    elseif coefficient<0
        expression = expression + "-" + term;
    else
        expression = expression + "+" + term;
    end
end
end

function lines = pi_operator_group_latex(titleText,names,operators)
lines = "\section*{" + titleText + "}";
for operatorIndex = 1:numel(operators)
    lines = [lines; pi_operator_latex( ...
        names(operatorIndex),operators{operatorIndex})];
end
end

function lines = pi_operator_latex(name,operator)
if ~isa(operator,'opvar')
    error('The LaTeX component exporter requires solved opvar objects.');
end
dimensions = operator.dim;
representation = name + "=" + ...
    "\PIop{" + polynomial_matrix_latex(operator.P) + "}" + ...
    "{" + polynomial_matrix_latex(operator.Q1) + "}" + ...
    "{" + polynomial_matrix_latex(operator.Q2) + "}" + ...
    "{" + polynomial_matrix_latex(operator.R.R0) + "}" + ...
    "{" + polynomial_matrix_latex(operator.R.R1) + "}" + ...
    "{" + polynomial_matrix_latex(operator.R.R2) + "}";
dimensionText = "$[" + string(dimensions(1,1)) + ";" + ...
    string(dimensions(2,1)) + "]\leftarrow[" + ...
    string(dimensions(1,2)) + ";" + string(dimensions(2,2)) + "]$";
lines = [
    "\paragraph{$" + name + "$}\hfill dimensions " + dimensionText
    "\[\displaystyle " + representation + "\]"
    ];
end

function text = polynomial_matrix_latex(value)
if isempty(value)
    text = "0";
    return
end
numberOfRows = size(value,1);
numberOfColumns = size(value,2);
rows = strings(numberOfRows,1);
for rowIndex = 1:numberOfRows
    entries = strings(1,numberOfColumns);
    for columnIndex = 1:numberOfColumns
        entries(columnIndex) = polynomial_scalar_latex( ...
            value(rowIndex,columnIndex));
    end
    rows(rowIndex) = strjoin(entries," & ");
end
if numberOfRows==1 && numberOfColumns==1
    text = rows(1);
else
    text = "\begin{bmatrix}" + strjoin(rows,"\\") + "\end{bmatrix}";
end
end

function text = polynomial_scalar_latex(value)
if isnumeric(value)
    if ~isscalar(value)
        error('A scalar matrix entry was expected.');
    end
    text = number_latex(value);
    return
end
if ~isa(value,'polynomial')
    try
        value = double(value);
        text = number_latex(value);
        return
    catch
        error('Unsupported PI-kernel coefficient type: %s.',class(value));
    end
end
coefficients = full(value.coefficient(:,1));
degrees = full(value.degmat);
variableNames = value.varname;
coefficientTolerance = 1e-12*max([1;abs(coefficients)]);
signedTerms = strings(0,1);
for termIndex = 1:numel(coefficients)
    coefficient = coefficients(termIndex);
    if abs(coefficient)<=coefficientTolerance
        continue
    end
    monomial = "";
    if ~isempty(degrees)
        for variableIndex = 1:numel(variableNames)
            exponent = degrees(termIndex,variableIndex);
            if exponent==0
                continue
            end
            variable = polynomial_variable_latex(variableNames{variableIndex});
            if exponent>1
                variable = variable + "^{" + string(exponent) + "}";
            end
            if strlength(monomial)>0
                monomial = monomial + "\,";
            end
            monomial = monomial + variable;
        end
    end
    magnitude = abs(coefficient);
    if strlength(monomial)==0
        term = number_latex(magnitude);
    elseif abs(magnitude-1)<=coefficientTolerance
        term = monomial;
    else
        term = number_latex(magnitude) + "\," + monomial;
    end
    if isempty(signedTerms)
        if coefficient<0
            signedTerm = "-" + term;
        else
            signedTerm = term;
        end
    elseif coefficient<0
        signedTerm = "-" + term;
    else
        signedTerm = "+" + term;
    end
    signedTerms(end+1,1) = signedTerm; %#ok<AGROW>
end
if isempty(signedTerms)
    text = "0";
elseif numel(signedTerms)<=4
    text = strjoin(signedTerms,"");
else
    termsPerLine = 4;
    numberOfLines = ceil(numel(signedTerms)/termsPerLine);
    polynomialLines = strings(numberOfLines,1);
    for lineIndex = 1:numberOfLines
        indices = (lineIndex-1)*termsPerLine+1: ...
            min(lineIndex*termsPerLine,numel(signedTerms));
        polynomialLines(lineIndex) = "&" + ...
            strjoin(signedTerms(indices),"");
    end
    text = "\begin{aligned}" + strjoin(polynomialLines,"\\") + ...
        "\end{aligned}";
end
end

function text = polynomial_variable_latex(name)
switch name
    case {'s','s1'}
        text = "s";
    case {'theta','s1_dum'}
        text = "\theta";
    otherwise
        text = "\mathrm{" + latex_escape_text(name) + "}";
end
end

function text = number_latex(value)
if isnan(value)
    text = "\mathrm{NaN}";
    return
elseif isinf(value)
    if value<0
        text = "-\infty";
    else
        text = "\infty";
    end
    return
elseif abs(value)<=1e-14
    text = "0";
    return
end
if abs(value)>=1e4 || abs(value)<1e-2
    raw = sprintf('%.2e',value);
else
    raw = sprintf('%.2f',value);
    raw = regexprep(raw,'(\.[0-9]*?)0+$','$1');
    raw = regexprep(raw,'\.$','');
end
token = regexp(raw,'^([+-]?[0-9.]+)e([+-]?[0-9]+)$', ...
    'tokens','once');
if isempty(token)
    text = string(raw);
else
    exponent = str2double(token{2});
    text = string(token{1}) + "\times10^{" + string(exponent) + "}";
end
end

function text = latex_escape_text(value)
text = string(value);
text = replace(text,"\","\textbackslash{}");
text = replace(text,"_","\_");
text = replace(text,"%","\%");
text = replace(text,"&","\&");
text = replace(text,"#","\#");
end

function display_iqc_components(Psi,ThetaDelta,PsiP,synthesis,analysis,K)
% Explicit command-window map of every plant/filter/multiplier component
% entering synthesis and the two post-synthesis analyses.
P = synthesis.P;
zpDim = synthesis.zpDim;
fprintf('\n============================================================\n');
fprintf('COMPONENTS USED IN SYNTHESIS AND ANALYSIS\n');
fprintf('============================================================\n');
fprintf('Generalized plant P, Eq. (21):\n');
fprintf('  realization: T*xdot=A*x+B1*w+B2*u\n');
fprintf('               z=C1*x+D11*w+D12*u\n');
fprintf('  inputs:          w = [wS;wG;wp], u\n');
fprintf('  outputs:         z = [zS;zG;zp]\n');
fprintf('  zp:              [xS;xG;mu*u]\n');
fprintf('  state dimension: %s [finite; distributed]\n', ...
    mat2str(P.T.dim(:,2).'));
fprintf('  w dimension:     %s [finite; distributed]\n', ...
    mat2str(P.B1.dim(:,2).'));
fprintf('  u dimension:     %s [finite; distributed]\n', ...
    mat2str(P.B2.dim(:,2).'));
fprintf('  z dimension:     %s [finite; distributed]\n', ...
    mat2str(P.C1.dim(:,1).'));
fprintf('  K=[K_P,K_Theta]: %s -> %s [finite; distributed]\n', ...
    mat2str(K.dim(:,2).'),mat2str(K.dim(:,1).'));
fprintf('  synthesized controller K=[K_P,K_Theta]:\n');
disp(K);

fprintf('\nSYNTHESIS -- dual LPI, Eq. (7)\n');
fprintf('  graph:  D(Psi)*[(K star P)^T;I]\n');
fprintf('  input order to D(Psi):  [wDelta;wp;zDelta;zp]\n');
fprintf('  rho=gamma^2: %.10g\n',synthesis.rho);
display_signature('  underline V used for synthesis', ...
    dual_signature(synthesis.mu,synthesis.rho,zpDim));

fprintf('\nPRIMAL ANALYSIS -- primal KYP inequality in Eq. (4)\n');
fprintf('  graph:  Psi*[K star P;I]\n');
fprintf('  input order to Psi:     [zDelta;zp;wDelta;wp]\n');
if analysis.primal.solutionAvailable
    fprintf('  rho=gamma^2: %.10g\n',analysis.primal.rho);
    display_signature('  V used for primal analysis', ...
        primal_signature(analysis.primal.mu,analysis.primal.rho,zpDim));
else
    fprintf('  solution unavailable: %s\n',analysis.primal.message);
end

fprintf('\nDUAL ANALYSIS -- dual KYP inequality in Eq. (4)\n');
fprintf('  graph:  D(Psi)*[(K star P)^T;I]\n');
fprintf('  input order to D(Psi):  [wDelta;wp;zDelta;zp]\n');
if analysis.dual.solutionAvailable
    fprintf('  rho=gamma^2: %.10g\n',analysis.dual.rho);
    display_signature('  underline V used for dual analysis', ...
        dual_signature(analysis.dual.mu,analysis.dual.rho,zpDim));
else
    fprintf('  solution unavailable: %s\n',analysis.dual.message);
end

fprintf('\nMULTIPLIER AND FILTER TRANSFER FUNCTIONS\n');
display_transfer('H_S(s)',ThetaDelta.multiplier.S.H);
display_transfer('M_S(s)=1-H_S(s)',ThetaDelta.multiplier.S.M);
display_transfer('Pi_sec,S(s)',ThetaDelta.multiplier.S.PiSector);
display_transfer('Pi_ZF,S(s)',ThetaDelta.multiplier.S.PiZF);
display_transfer('Pi_Delta,S(s)',ThetaDelta.multiplier.S.Pi);
display_transfer('H_G(s)',ThetaDelta.multiplier.G.H);
display_transfer('M_G(s)=1-H_G(s)',ThetaDelta.multiplier.G.M);
display_transfer('Pi_sec,G(s)',ThetaDelta.multiplier.G.PiSector);
display_transfer('Pi_ZF,G(s)',ThetaDelta.multiplier.G.PiZF);
display_transfer('Pi_Delta,G(s)',ThetaDelta.multiplier.G.Pi);
display_transfer('Theta_Delta(s)',ThetaDelta.primal);
display_transfer('D(Theta_Delta)(s)',ThetaDelta.dual);
display_transfer('W_p(s)',PsiP.Wperformance);
display_transfer('W_p^{-1}(s)',PsiP.WperformanceInverse);
display_transfer('Psi_p(s)',PsiP.primal);
display_transfer('D(Psi_p)(s)',PsiP.dual);
fprintf('\nFull factor: Theta combines Theta_Delta and Psi_p in the\n');
fprintf('paper signal order [z_Delta;z_p;w_Delta;w_p].\n');
display_transfer('Theta(s)',Psi.primal);
display_transfer('D(Theta)(s)',Psi.dual);
fprintf('============================================================\n');
end

function V = primal_signature(mu,rho,zpDim)
% diag(Mu,I_zp,-Mu,-rho*I_wp), ordered [zDelta;zp;wDelta;wp].
V = diag([mu(:);ones(zpDim,1);-mu(:);-rho]);
end

function V = dual_signature(mu,rho,zpDim)
% diag(Mu,I_wp,-Mu,-rho*I_zp), ordered [wDelta;wp;zDelta;zp].
V = diag([mu(:);1;-mu(:);-rho*ones(zpDim,1)]);
end

function display_signature(name,V)
fprintf('%s =\n',name);
disp(V);
end

function display_transfer(name,system)
% Compact transfer-matrix display with each entry written as N(s)/D(s).
transfer = minreal(tf(system),1e-9);
[numberOfOutputs,numberOfInputs] = size(transfer);
entries = cell(numberOfOutputs,numberOfInputs);
for outputIndex = 1:numberOfOutputs
    for inputIndex = 1:numberOfInputs
        [numerator,denominator] = tfdata( ...
            transfer(outputIndex,inputIndex),'v');
        numeratorText = laplace_polynomial(numerator);
        denominatorText = laplace_polynomial(denominator);
        if strcmp(numeratorText,'0') || strcmp(denominatorText,'1')
            entries{outputIndex,inputIndex} = numeratorText;
        else
            entries{outputIndex,inputIndex} = sprintf( ...
                '(%s)/(%s)',numeratorText,denominatorText);
        end
    end
end
fprintf('\n%s  [%d-by-%d] =\n',name,numberOfOutputs,numberOfInputs);
for outputIndex = 1:numberOfOutputs
    if outputIndex==1
        fprintf('  [ ');
    else
        fprintf('    ');
    end
    for inputIndex = 1:numberOfInputs
        fprintf('%s',entries{outputIndex,inputIndex});
        if inputIndex<numberOfInputs
            fprintf(',  ');
        end
    end
    if outputIndex<numberOfOutputs
        fprintf(';\n');
    else
        fprintf(' ]\n');
    end
end
end

function expression = laplace_polynomial(coefficients)
% Convert descending polynomial coefficients to an explicit expression in s.
coefficients = coefficients(:).';
if isempty(coefficients)
    expression = '0';
    return
end
coefficientScale = max(abs(coefficients));
zeroTolerance = 1e-12*max(1,coefficientScale);
coefficients(abs(coefficients)<=zeroTolerance) = 0;
firstNonzero = find(coefficients~=0,1,'first');
if isempty(firstNonzero)
    expression = '0';
    return
end
coefficients = coefficients(firstNonzero:end);
degree = numel(coefficients)-1;
expression = '';
for coefficientIndex = 1:numel(coefficients)
    coefficient = coefficients(coefficientIndex);
    if coefficient==0
        continue
    end
    exponent = degree-coefficientIndex+1;
    magnitude = abs(coefficient);
    if exponent==0
        term = sprintf('%.12g',magnitude);
    elseif exponent==1
        if abs(magnitude-1)<=1e-12
            term = 's';
        else
            term = sprintf('%.12g s',magnitude);
        end
    elseif abs(magnitude-1)<=1e-12
        term = sprintf('s^%d',exponent);
    else
        term = sprintf('%.12g s^%d',magnitude,exponent);
    end
    if isempty(expression)
        if coefficient<0
            expression = ['-',term]; %#ok<AGROW>
        else
            expression = term;
        end
    elseif coefficient<0
        expression = [expression,' - ',term]; %#ok<AGROW>
    else
        expression = [expression,' + ',term]; %#ok<AGROW>
    end
end
end

function export_component_pdf(componentText,pdfPath)
% Write the matrix-form command-window report to a paginated vector PDF.
lines = splitlines(string(componentText));
if ~isempty(lines) && strlength(lines(end))==0
    lines(end) = [];
end
linesPerPage = 48;
numberOfPages = max(1,ceil(numel(lines)/linesPerPage));
pageSize = [16.54,11.69];             % A3 landscape, in inches
for pageIndex = 1:numberOfPages
    firstLine = (pageIndex-1)*linesPerPage+1;
    lastLine = min(pageIndex*linesPerPage,numel(lines));
    pageLines = lines(firstLine:lastLine);
    longestLine = max([1;strlength(pageLines)]);
    fontSize = max(4,min(7,1500/double(longestLine)));

    reportFigure = figure('Visible','off','Color','white', ...
        'Units','inches','Position',[0,0,pageSize]);
    reportAxes = axes(reportFigure,'Position',[0,0,1,1], ...
        'Visible','off','XLim',[0,1],'YLim',[0,1]);
    text(reportAxes,0.015,0.985, ...
        sprintf('Example 4 IQC components -- page %d/%d\n\n%s', ...
        pageIndex,numberOfPages,strjoin(pageLines,newline)), ...
        'Units','normalized','VerticalAlignment','top', ...
        'HorizontalAlignment','left','Interpreter','none', ...
        'FontName','Consolas','FontSize',fontSize);
    drawnow;
    if pageIndex==1
        exportgraphics(reportFigure,pdfPath,'ContentType','vector', ...
            'BackgroundColor','white');
    else
        exportgraphics(reportFigure,pdfPath,'ContentType','vector', ...
            'BackgroundColor','white','Append',true);
    end
    close(reportFigure);
end
end

function cert = solver_diagnostics(prog)
% Report the returned candidate and raw diagnostics without judging validity.
cert.solinfo = prog.solinfo;
cert.solutionAvailable = isfield(prog.solinfo,'RRx') ...
    && ~isempty(prog.solinfo.RRx);
names = {'feasratio','pinf','dinf','numerr'};
for k = 1:numel(names)
    cert.(names{k}) = NaN;
    if isfield(prog.solinfo,'info') && isfield(prog.solinfo.info,names{k})
        cert.(names{k}) = double(prog.solinfo.info.(names{k}));
    end
end
cert.residual = prog.solinfo.residual;
cert.message = '';
if ~cert.solutionAvailable
    cert.message = 'The solver returned no solution vector.';
end
end
function value = solution_scalar(prog,variable)
solution = lpigetsol(prog,variable);
value = double(solution.P);
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
