function sim = PIE_sim_nl(PIE,wd,tspan,x0,opts)
%PIE_SIM_NL Simulate a PIE with supplied wp and nonlinear wd channels.
%
%   sim = PIE_sim_nl(PIE,wd,tspan,x0,opts)
%
% The linear PIE must expose the nonlinear loop through its B1/C1 channels:
%
%   zd = C1*x + D11*[wd;wp],      wd = wd(zd).
%
% By default, finite-dimensional B1 inputs are supplied exogenous inputs wp,
% and distributed B1 inputs are nonlinear wd inputs. If opts.nwd0 is
% positive, the first opts.nwd0 finite-dimensional B1 inputs are included in
% the nonlinear wd loop; the remaining finite-dimensional B1 inputs are wp.
%
% Main options:
%   opts.N        PIESIM Chebyshev degree. Default: 16.
%   opts.splot    Physical plotting grid in the original PIE domain.
%   opts.wp       Supplied finite-dimensional input, either constant vector
%                 or function handle wp(t). Default: zero.
%   opts.nwd0     Number of finite-dimensional nonlinear wd channels.
%                 Default: 0.
%   opts.statePIE PIE used only for initial-condition/state metadata. This
%                 is useful when simulating closedLoopPIE(P,K), whose x_tab
%                 metadata should still come from P.
%   opts.ode      ODE solver options. Default: odeset tolerances.
%   opts.alg      fsolve options for algebraic D11 wd feedthrough loops.
%
% Initial condition:
%   x0 may be a numeric PIESIM fundamental-state vector, or a struct:
%
%       x0.ode = finite-dimensional initial states;
%       x0.pde = {primaryPDEState1, primaryPDEState2, ...};
%
%   Entries of x0.pde may be function handles of physical position s or
%   scalar constants. The conversion to PIESIM fundamental Chebyshev
%   coefficients is performed internally using PIE.x_tab.
%
% Nonlinearity input/output layout:
%   The wd handle receives one column vector containing
%
%       [finite nonlinear zd values;
%        distributed nonlinear zd values on Chebyshev nodes].
%
%   It must return the same layout for wd. Distributed values are converted
%   to Chebyshev coefficients internally.
%
% Useful returned fields:
%   sim.t              time grid returned by the ODE solver
%   sim.x              PIESIM fundamental state coefficients
%   sim.wp             supplied finite-dimensional input values
%   sim.zFinite        finite nonlinear zd channels
%   sim.wdFinite       finite nonlinear wd channels
%   sim.zPlot          distributed nonlinear zd channels on sim.splot
%   sim.wdPlot         distributed nonlinear wd channels on sim.splot
%   sim.outputFinite   all finite-dimensional regulated C1/D11 outputs
%   sim.outputPlot     all distributed regulated C1/D11 outputs on sim.splot
%   sim.z1, sim.z2     aliases for outputFinite(:,1/2), when present
%   sim.inputCoeff     full B1 input coefficient history in PIESIM order
%   sim.outputCoeff    full C1/D11 output coefficient history in PIESIM order
%   sim.Dop            PIESIM discretization data
%   sim.PIE            original, unscaled input realization (safe to reuse)
%
% Quick plotting examples:
%   surf(sim.splot,sim.t,sim.zPlot,'EdgeColor','none'); view(2);
%   plot(sim.t,sim.outputFinite(:,1));

narginchk(4,5);
if nargin<5 || isempty(opts)
    opts = struct();
end
if ~isa(wd,'function_handle')
    error('wd must be a function handle.');
end
opts = simulation_options(opts);

originalPIE = PIE;
statePIE = PIE;
if isfield(opts,'statePIE') && ~isempty(opts.statePIE)
    statePIE = opts.statePIE;
end

psize = piesim_size(statePIE,opts.N);
opts = validate_channel_options(opts,psize);
x0 = discretize_initial_condition(x0,statePIE,psize,statePIE.dom,opts.N);

PIE = rescalePIE(PIE,[-1,1]);
Dop = PIESIM_discretize_ops(PIE,psize);
if ~isempty(Dop.Twcheb) && any(abs(Dop.Twcheb(:))>opts.zeroTol)
    error('A nonlinear wd input with a nonzero Tw term is not supported.');
end

A = Dop.Atotal;
B = Dop.Tcheb_inv*Dop.B1cheb;
C = Dop.C1cheb;
D = Dop.D11cheb;

channels = simulation_channels(psize,opts.N,opts.nwd0);

Bp = B(:,channels.wpCols);
Bwd = B(:,channels.wdCols);
Cz = C(channels.zRows,:);
Dzp = D(channels.zRows,channels.wpCols);
Dzwd = D(channels.zRows,channels.wdCols);
Eplot = cheb_eval_matrix(2*opts.splot(:)-1,opts.N);

[t,x,zCoeff,wdCoeff,wp] = integrate_wd_loop( ...
    A,Bp,Bwd,Cz,Dzp,Dzwd,wd,tspan,x0,opts,channels);

sim.t = t;
sim.x = x;
sim.wp = wp;
sim.zCoeff = zCoeff;
sim.wdCoeff = wdCoeff;
sim.inputCoeff = assemble_input_coefficients(wp,wdCoeff,channels);
sim.outputCoeff = x*C' + sim.inputCoeff*D';
sim.outputFinite = sim.outputCoeff(:,1:psize.nr0);
sim.outputPlot = evaluate_all_distributed_outputs( ...
    sim.outputCoeff(:,psize.nr0+1:end),Eplot,opts.N,psize.nrx);
sim.zFinite = zCoeff(:,1:channels.nwd0);
sim.wdFinite = wdCoeff(:,1:channels.nwd0);
sim.zPlot = evaluate_distributed_output(zCoeff,Eplot,channels);
sim.wdPlot = evaluate_distributed_output(wdCoeff,Eplot,channels);
if psize.nr0>=1
    sim.z1 = sim.outputFinite(:,1);
end
if psize.nr0>=2
    sim.z2 = sim.outputFinite(:,2);
end
sim.splot = opts.splot(:);
sim.s = sim.splot;
sim.PIE = originalPIE;
sim.Dop = Dop;
end

function opts = simulation_options(opts)
if ~isfield(opts,'N') || isempty(opts.N)
    opts.N = 16;
end
if ~isfield(opts,'splot') || isempty(opts.splot)
    opts.splot = linspace(0,1,200).';
end
if ~isfield(opts,'wp') || isempty(opts.wp)
    opts.wp = [];
end
if ~isfield(opts,'nwd0') || isempty(opts.nwd0)
    opts.nwd0 = 0;
end
if ~isfield(opts,'ode') || isempty(opts.ode)
    opts.ode = odeset('RelTol',1e-8,'AbsTol',1e-10);
end
if ~isfield(opts,'alg') || isempty(opts.alg)
    opts.alg = [];
end
if ~isfield(opts,'zeroTol') || isempty(opts.zeroTol)
    opts.zeroTol = 1e-12;
end
if ~isfield(opts,'algTol') || isempty(opts.algTol)
    opts.algTol = 1e-9;
end
if ~isfield(opts,'solver') || isempty(opts.solver)
    opts.solver = @ode15s;
end
end

function opts = validate_channel_options(opts,psize)
if ~isscalar(opts.nwd0) || opts.nwd0<0 || opts.nwd0~=floor(opts.nwd0)
    error('opts.nwd0 must be a nonnegative integer.');
end
if opts.nwd0>psize.nw0
    error('opts.nwd0 cannot exceed the number of finite-dimensional inputs.');
end
if psize.nrx~=psize.nwx
    error('The number of distributed zd and wd channels must match.');
end
if psize.nr0<opts.nwd0
    error('C1 must contain at least opts.nwd0 finite-dimensional zd outputs.');
end
if opts.nwd0+psize.nwx==0
    error('There must be at least one nonlinear wd channel.');
end
end

function channels = simulation_channels(psize,N,nwd0)
nDist = psize.nwx;
nDistCoeff = nDist*(N+1);

channels.nwd0 = nwd0;
channels.nDist = nDist;
channels.N = N;
channels.nwCoeff = psize.nw0+nDistCoeff;

channels.wdFiniteCols = 1:nwd0;
channels.wpCols = nwd0 + (1:(psize.nw0-nwd0));
channels.wdDistCols = psize.nw0 + (1:nDistCoeff);
channels.wdCols = [channels.wdFiniteCols,channels.wdDistCols];

channels.zFiniteRows = 1:nwd0;
channels.zDistRows = psize.nr0 + (1:nDistCoeff);
channels.zRows = [channels.zFiniteRows,channels.zDistRows];
end

function inputCoeff = assemble_input_coefficients(wp,wdCoeff,channels)
inputCoeff = zeros(size(wdCoeff,1),channels.nwCoeff);
if ~isempty(channels.wpCols)
    inputCoeff(:,channels.wpCols) = wp;
end
if channels.nwd0>0
    inputCoeff(:,channels.wdFiniteCols) = wdCoeff(:,1:channels.nwd0);
end
if ~isempty(channels.wdDistCols)
    inputCoeff(:,channels.wdDistCols) = wdCoeff(:,channels.nwd0+1:end);
end
end

function [t,x,zCoeff,wdCoeff,wpOut] = integrate_wd_loop( ...
    A,Bp,Bwd,Cz,Dzp,Dzwd,wd,tspan,x0,opts,channels)

nx = size(A,1);
nwd = size(Cz,1);
nwp = size(Bp,2);
if numel(x0)~=nx
    error('x0 must contain %d PIESIM fundamental-state coefficients.',nx);
end
x0 = x0(:);

if isempty(opts.wp)
    wpFun = @(t) zeros(nwp,1);
elseif isa(opts.wp,'function_handle')
    wpFun = opts.wp;
else
    wpValue = opts.wp(:);
    wpFun = @(t) wpValue;
end

hasLoop = norm(Dzwd,inf)>opts.zeroTol;
if hasLoop && exist('fsolve','file')~=2
    error('A nonzero wd feedthrough requires fsolve or a DAE formulation.');
end
if hasLoop && isempty(opts.alg)
    opts.alg = optimoptions('fsolve','Display','off', ...
        'FunctionTolerance',opts.algTol,'StepTolerance',opts.algTol, ...
        'OptimalityTolerance',opts.algTol);
end

wp0 = input_value(tspan(1));
wdLast = wd_coefficients(Cz*x0+Dzp*wp0);
[t,x] = opts.solver(@rhs,tspan,x0,opts.ode);

zCoeff = zeros(numel(t),nwd);
wdCoeff = zeros(numel(t),nwd);
wpOut = zeros(numel(t),nwp);
wdGuess = wdLast;
for k = 1:numel(t)
    wpNow = input_value(t(k));
    q = Cz*x(k,:)'+Dzp*wpNow;
    [wdNow,zNow] = close_loop(q,wdGuess);
    zCoeff(k,:) = zNow.';
    wdCoeff(k,:) = wdNow.';
    wpOut(k,:) = wpNow.';
    wdGuess = wdNow;
end

    function dx = rhs(tNow,xNow)
        wpNow = input_value(tNow);
        q = Cz*xNow+Dzp*wpNow;
        [wdNow,~] = close_loop(q,wdLast);
        wdLast = wdNow;
        dx = A*xNow+Bp*wpNow+Bwd*wdNow;
    end

    function [wdNow,zNow] = close_loop(q,wdGuess)
        if ~hasLoop
            zNow = q;
            wdNow = wd_coefficients(zNow);
            return
        end
        residual = @(wdTry) wdTry-wd_coefficients(q+Dzwd*wdTry);
        [wdNow,res] = fsolve(residual,wdGuess,opts.alg);
        wdNow = wdNow(:);
        if norm(res,inf)>opts.algTol
            error('The wd algebraic loop did not converge (residual %.3e).', ...
                norm(res,inf));
        end
        zNow = q+Dzwd*wdNow;
    end

    function wpNow = input_value(tNow)
        wpNow = wpFun(tNow);
        wpNow = wpNow(:);
        if numel(wpNow)~=nwp
            error('wp(t) has incompatible dimensions.');
        end
    end

    function wdNow = wd_coefficients(zNow)
        zValues = unpack_nonlinear_signal(zNow,channels);
        wdValues = wd(zValues);
        wdValues = wdValues(:);
        expectedValues = channels.nwd0 + channels.nDist*(channels.N+1);
        if numel(wdValues)~=expectedValues || any(~isfinite(wdValues))
            error('wd(z) returned invalid values.');
        end
        wdNow = pack_nonlinear_signal(wdValues,channels);
    end
end

function x0 = discretize_initial_condition( ...
    initialCondition,PIE,psize,physicalDomain,N)
if isnumeric(initialCondition)
    x0 = initialCondition(:);
    return
end
if ~isstruct(initialCondition)
    error('x0 must be numeric or a struct with fields ode and pde.');
end

numberOfODEStates = PIE.T.dim(1,2);
numberOfPDEStates = sum(psize.n);

if isfield(initialCondition,'ode') && ~isempty(initialCondition.ode)
    odeInitial = initialCondition.ode(:);
else
    odeInitial = zeros(numberOfODEStates,1);
end
if numel(odeInitial)~=numberOfODEStates
    error('x0.ode must contain %d finite-dimensional states.', ...
        numberOfODEStates);
end

if isfield(initialCondition,'pde')
    pdeInitial = initialCondition.pde;
else
    pdeInitial = cell(1,0);
end
if ~iscell(pdeInitial)
    pdeInitial = num2cell(pdeInitial);
end
if numel(pdeInitial)~=numberOfPDEStates
    error('x0.pde must contain %d primary PDE profiles.', ...
        numberOfPDEStates);
end

differentiabilityOrder = repelem(0:numel(psize.n)-1,psize.n);
pdeCoefficients = cell(numberOfPDEStates,1);
for stateIndex = 1:numberOfPDEStates
    derivativeOrder = differentiabilityOrder(stateIndex);
    profile = pdeInitial{stateIndex};

    if isa(profile,'function_handle')
        pdeCoefficients{stateIndex} = profile_coefficients( ...
            profile,N,derivativeOrder,physicalDomain);
    elseif isnumeric(profile) && isscalar(profile)
        pdeCoefficients{stateIndex} = constant_profile_coefficients( ...
            profile,N,derivativeOrder);
    else
        error('Unsupported x0.pde profile for state %d.',stateIndex);
    end
end

x0 = [odeInitial;vertcat(pdeCoefficients{:})];
end

function coefficients = profile_coefficients( ...
    profile,N,derivativeOrder,physicalDomain)
grid = cos(pi*(0:N)/N).';
physicalGrid = 0.5*(physicalDomain(2)-physicalDomain(1))*grid + ...
    0.5*sum(physicalDomain);
values = profile(physicalGrid);
values = values(:);
if numel(values)~=N+1 || any(~isfinite(values))
    error('Initial-condition function returned invalid values.');
end

coefficients = fcht(values);
derivativeScale = 2/(physicalDomain(2)-physicalDomain(1));
for derivativeIndex = 1:derivativeOrder
    coefficients = derivativeScale* ...
        differentiate_chebyshev_coefficients(coefficients);
end
end

function coefficients = constant_profile_coefficients(value,N,derivativeOrder)
if derivativeOrder==0
    coefficients = fcht(value*ones(N+1,1));
else
    coefficients = zeros(N+1-derivativeOrder,1);
end
end

function derivative = differentiate_chebyshev_coefficients(coefficients)
coefficients = coefficients(:);
degree = numel(coefficients)-1;
if degree<1
    derivative = 0;
    return
end

work = zeros(degree+1,1);
work(degree) = 2*degree*coefficients(degree+1);
for coefficientDegree = degree-2:-1:0
    work(coefficientDegree+1) = work(coefficientDegree+3) + ...
        2*(coefficientDegree+1)*coefficients(coefficientDegree+2);
end
work(1) = 0.5*work(1);
derivative = work(1:degree);
end

function psize = piesim_size(PIE,N)
psize.dim = 1;
psize.N = N;
psize.n0 = PIE.T.dim(1,1);
psize.n = zeros(1,max(PIE.x_tab(:,end))+1);
for k = 0:max(PIE.x_tab(:,end))
    psize.n(k+1) = sum(PIE.x_tab(PIE.x_tab(:,end)==k & PIE.x_tab(:,3),2));
end
psize.nw0 = PIE.B1.dim(1,2);
psize.nwx = PIE.B1.dim(2,2);
psize.nw = psize.nw0+psize.nwx;
psize.nu0 = PIE.B2.dim(1,2);
psize.nux = PIE.B2.dim(2,2);
psize.nu = psize.nu0+psize.nux;
psize.nr0 = PIE.C1.dim(1,1);
psize.nrx = PIE.C1.dim(2,1);
psize.no0 = PIE.C2.dim(1,1);
psize.nox = PIE.C2.dim(2,1);
end

function values = unpack_nonlinear_signal(coefficients,channels)
coefficients = coefficients(:);
finiteValues = coefficients(1:channels.nwd0);
distributedCoefficients = coefficients(channels.nwd0+1:end);
distributedValues = cheb_coefficients_to_values(distributedCoefficients, ...
    channels.N,channels.nDist);
values = [finiteValues;distributedValues];
end

function coefficients = pack_nonlinear_signal(values,channels)
values = values(:);
finiteValues = values(1:channels.nwd0);
distributedValues = values(channels.nwd0+1:end);
distributedCoefficients = cheb_values_to_coefficients(distributedValues, ...
    channels.N,channels.nDist);
coefficients = [finiteValues;distributedCoefficients];
end

function values = cheb_coefficients_to_values(coefficients,N,nChannels)
values = zeros(nChannels*(N+1),1);
for channelIndex = 1:nChannels
    idx = (channelIndex-1)*(N+1) + (1:N+1);
    values(idx) = real(ifcht(coefficients(idx)));
end
end

function coefficients = cheb_values_to_coefficients(values,N,nChannels)
coefficients = zeros(nChannels*(N+1),1);
for channelIndex = 1:nChannels
    idx = (channelIndex-1)*(N+1) + (1:N+1);
    coefficients(idx) = fcht(values(idx));
end
end

function values = evaluate_distributed_output(coefficients,Eplot,channels)
if channels.nDist==0
    values = [];
    return
end

values = zeros(size(coefficients,1),size(Eplot,1),channels.nDist);
distributedCoefficients = coefficients(:,channels.nwd0+1:end);
for timeIndex = 1:size(coefficients,1)
    for channelIndex = 1:channels.nDist
        idx = (channelIndex-1)*(channels.N+1) + (1:channels.N+1);
        values(timeIndex,:,channelIndex) = ...
            real(Eplot*distributedCoefficients(timeIndex,idx).').';
    end
end
if channels.nDist==1
    values = values(:,:,1);
end
end

function values = evaluate_all_distributed_outputs(coefficients,Eplot,N,nChannels)
if nChannels==0
    values = [];
    return
end

values = zeros(size(coefficients,1),size(Eplot,1),nChannels);
for timeIndex = 1:size(coefficients,1)
    for channelIndex = 1:nChannels
        idx = (channelIndex-1)*(N+1) + (1:N+1);
        values(timeIndex,:,channelIndex) = ...
            real(Eplot*coefficients(timeIndex,idx).').';
    end
end
if nChannels==1
    values = values(:,:,1);
end
end

function E = cheb_eval_matrix(x,N)
x = x(:);
E = zeros(numel(x),N+1);
E(:,1) = 1;
if N>=1
    E(:,2) = x;
end
for k = 2:N
    E(:,k+1) = 2*x.*E(:,k)-E(:,k-1);
end
end
