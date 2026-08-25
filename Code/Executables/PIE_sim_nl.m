%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIE_sim_nl.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Assemble and simulate the PIE feedback interconnection
%
%   u = K*[xP;xTheta],       wDelta = Delta(zDelta).
%
% PI operators are assembled first and closed with closedLoopPIE. PIESIM
% then discretizes the complete linear block. Numeric indexing, ode45, and
% fsolve are used only after this discretization.
%
% CALL:
%   sim = PIE_sim_nl(CL,Delta,tspan,x0)
%   sim = PIE_sim_nl(CL,Delta,tspan,x0,opts)
%
% REQUIRED FIELDS OF CL:
% P         - plant box with vars,dom,T,A,B1,Bu,C1,D11,Dzu
% Theta     - filter box with T,A,B1,B2
% K         - PI controller mapping [xP;xTheta] to u
% CDelta    - PI operator mapping xP to zDelta
%
% OPTIONAL FIELDS OF CL:
% DDeltaW   - PI operator mapping [wDelta;wp] to zDelta (default zero)
% DDeltaU   - PI operator mapping u to zDelta (default zero)
%
% OPTIONAL SETTINGS:
% N         - PIESIM polynomial degree (default 8)
% nDelta    - number of finite-dimensional wDelta channels
% wp        - function handle or constant disturbance vector (default zero)
% ode,alg   - ode45 and fsolve options
% zeroTol   - tolerance for detecting zero DDelta (default 1e-12)
% algTol    - accepted algebraic residual (default 1e-9)
% plot      - plot selected discretized states and u (default false)
% states    - discretized-state indices to plot (default first two)
% labels    - labels corresponding to opts.states
%
% x0 may be either:
%   1) a numeric vector in PIESIM-discretized fundamental-state
%      coordinates (the original interface), or
%   2) a physical-state struct with fields x0.ode and x0.pde. x0.ode is
%      the vector of finite-dimensional initial states, and x0.pde is a
%      cell array of function handles or symbolic primary-PDE profiles.
%      PIE_sim_nl differentiates these profiles according to CL.P.x_tab
%      and performs the Chebyshev discretization internally.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function sim = PIE_sim_nl(CL,Delta,tspan,x0,opts)

narginchk(4,5);
if nargin<5 || isempty(opts)
    opts = struct();
end
if ~isstruct(CL)
    error('CL must be a closed-loop data struct.');
end
fields = {'P','Theta','K','CDelta'};
missing = fields(~isfield(CL,fields));
if ~isempty(missing)
    error('CL is missing field(s): %s.',strjoin(missing,', '));
end
if ~isa(Delta,'function_handle')
    error('Delta must be a function handle.');
end

% Assemble the PI operators and close K without using ss or numeric LFTs.
[PIE,K] = build_closed_loop(CL);
opts = simulation_options(opts,PIE);

% Discretize the complete linear PIE block around Delta.
[P,Dop,x0] = discretize_PIE(PIE,opts.N,x0);
nw = size(P.B,2);
if opts.nDelta>nw
    error('nDelta exceeds the number of discretized input channels.');
end

% Numeric channel indexing starts only after PIESIM discretization.
iDelta = 1:opts.nDelta;
ip = opts.nDelta+1:nw;
P.BDelta = P.B(:,iDelta);
P.Bp = P.B(:,ip);
P.DDelta = P.D(:,iDelta);
P.Dp = P.D(:,ip);

[t,x,zDelta,wDelta,wp] = integrate_nonlinearity( ...
    P,Delta,tspan,x0,opts);

% C2/D21 were reserved for u before calling PIESIM.
input = [wDelta,wp];
u = x*P.Cu'+input*P.Du';

sim.t = t;
sim.x = x;
sim.u = u;
sim.zDelta = zDelta;
sim.wDelta = wDelta;
sim.wp = wp;
sim.PIE = PIE;
sim.P = P;
sim.Dop = Dop;
sim.K = K;

if opts.plot
    plot_simulation(sim,opts);
end

end

function [PIE,K] = build_closed_loop(CL)
P = CL.P;
Theta = CL.Theta;
plantFields = {'vars','dom','T','A','B1','Bu','C1','D11','Dzu'};
filterFields = {'T','A','B1','B2'};
missing = plantFields(~isfield(P,plantFields));
if ~isempty(missing)
    error('CL.P is missing field(s): %s.',strjoin(missing,', '));
end
missing = filterFields(~isfield(Theta,filterFields));
if ~isempty(missing)
    error('CL.Theta is missing field(s): %s.',strjoin(missing,', '));
end

vars = P.vars;
dom = P.dom;
TP = P.T;
AP = P.A;
BP = P.B1;
Bu = P.Bu;
CP = P.C1;
DP = P.D11;
Dzu = P.Dzu;

TTheta = Theta.T;
ATheta = Theta.A;
B1Theta = Theta.B1;
B2Theta = Theta.B2;

CDelta = operator_value(CL.CDelta,TP.dim(:,2),vars,dom,'CDelta');
if any(CDelta.dim(2:end,1))
    error('Delta must currently have finite-dimensional input channels.');
end

T = blkdiag(TP,TTheta);
ZPTheta = zero_operator(TP.dim(:,1),TTheta.dim(:,2),vars,dom);
A = [AP,           ZPTheta;
     B1Theta*CP,   ATheta];
B1 = [BP;
      B1Theta*DP+B2Theta];
B2 = [Bu;
      B1Theta*Dzu];
if any(B2.dim(2:end,2))
    error('The controller output u must currently be finite-dimensional.');
end

ZDeltaTheta = zero_operator( ...
    CDelta.dim(:,1),TTheta.dim(:,2),vars,dom);
C1 = [CDelta,ZDeltaTheta];

if isfield(CL,'DDeltaW') && ~isempty(CL.DDeltaW)
    D11 = compatible_operator(CL.DDeltaW, ...
        C1.dim(:,1),B1.dim(:,2),vars,dom,'DDeltaW');
else
    D11 = zero_operator(C1.dim(:,1),B1.dim(:,2),vars,dom);
end
if isfield(CL,'DDeltaU') && ~isempty(CL.DDeltaU)
    D12 = compatible_operator(CL.DDeltaU, ...
        C1.dim(:,1),B2.dim(:,2),vars,dom,'DDeltaU');
else
    D12 = zero_operator(C1.dim(:,1),B2.dim(:,2),vars,dom);
end

% Reserve the second output for u. closedLoopPIE maps it to K*x because
% C2=0, D21=0, and D22=I before closing u=K*x.
C2 = zero_operator(B2.dim(:,2),T.dim(:,2),vars,dom);
D21 = zero_operator(B2.dim(:,2),B1.dim(:,2),vars,dom);
D22 = identity_operator(B2.dim(:,2),vars,dom);
Tw = zero_operator(T.dim(:,1),B1.dim(:,2),vars,dom);
Tu = zero_operator(T.dim(:,1),B2.dim(:,2),vars,dom);

K = compatible_operator(CL.K,B2.dim(:,2),T.dim(:,2),vars,dom,'K');

% Preserve the plant state metadata. PIESIM uses the differentiability
% order in x_tab to select the polynomial degree of each fundamental PDE
% state and to convert physical primary-state initial conditions.
stateTable = [];
if isfield(P,'x_tab')
    stateTable = P.x_tab;
end

PIE = pie_struct();
PIE.vars = vars;
PIE.dom = dom;
PIE.T = T;
PIE.Tw = Tw;
PIE.Tu = Tu;
PIE.A = A;
PIE.B1 = B1;
PIE.B2 = B2;
PIE.C1 = C1;
PIE.D11 = D11;
PIE.D12 = D12;
PIE.C2 = C2;
PIE.D21 = D21;
PIE.D22 = D22;
PIE = initialize(PIE);
if ~isempty(stateTable)
    PIE.x_tab = stateTable;
end
PIE = closedLoopPIE(PIE,K,'controller');
if ~isempty(stateTable)
    PIE.x_tab = stateTable;
end
end

function opts = simulation_options(opts,PIE)
if ~isfield(opts,'N') || isempty(opts.N)
    opts.N = 8;
end
if ~isfield(opts,'nDelta') || isempty(opts.nDelta)
    opts.nDelta = sum(PIE.C1.dim(:,1));
end
if ~isscalar(opts.nDelta) || opts.nDelta<1 || ...
        opts.nDelta~=floor(opts.nDelta)
    error('opts.nDelta must be a positive integer.');
end
if any(PIE.B1.dim(2:end,2))
    error('Delta and wp must currently be finite-dimensional inputs.');
end
if ~isfield(opts,'wp')
    opts.wp = [];
end
if ~isfield(opts,'ode') || isempty(opts.ode)
    opts.ode = odeset('RelTol',1e-8,'AbsTol',1e-10);
end
if ~isfield(opts,'alg')
    opts.alg = [];
end
if ~isfield(opts,'zeroTol') || isempty(opts.zeroTol)
    opts.zeroTol = 1e-12;
end
if ~isfield(opts,'algTol') || isempty(opts.algTol)
    opts.algTol = 1e-9;
end
if ~isfield(opts,'plot') || isempty(opts.plot)
    opts.plot = false;
end
if ~isfield(opts,'states')
    opts.states = [];
end
if ~isfield(opts,'labels')
    opts.labels = {};
end
end

function [t,x,zDelta,wDelta,wpOut] = integrate_nonlinearity( ...
    P,Delta,tspan,x0,opts)

nx = size(P.A,1);
nDelta = size(P.BDelta,2);
nzDelta = size(P.C,1);
np = size(P.Bp,2);
if numel(x0)~=nx
    error(['x0 must contain %d PIESIM fundamental-state ', ...
        'coefficients.'],nx);
end
x0 = x0(:);

if isempty(opts.wp)
    wpFun = @(t) zeros(np,1);
elseif isa(opts.wp,'function_handle')
    wpFun = opts.wp;
else
    wpValue = opts.wp;
    wpFun = @(t) wpValue;
end

hasLoop = norm(P.DDelta,inf)>opts.zeroTol;
if hasLoop
    if exist('fsolve','file')~=2
        error('A nonzero DDelta requires fsolve or a DAE formulation.');
    end
    if isempty(opts.alg)
        opts.alg = optimoptions('fsolve','Display','off', ...
            'FunctionTolerance',opts.algTol,'StepTolerance',opts.algTol, ...
            'OptimalityTolerance',opts.algTol);
    end
end

p0 = input_value(tspan(1));
wLast = delta_value(P.C*x0+P.Dp*p0);
[t,x] = ode45(@rhs,tspan,x0,opts.ode);

zDelta = zeros(numel(t),nzDelta);
wDelta = zeros(numel(t),nDelta);
wpOut = zeros(numel(t),np);
wGuess = wLast;
for k = 1:numel(t)
    p = input_value(t(k));
    q = P.C*x(k,:)'+P.Dp*p;
    [w,z] = close_loop(q,wGuess);
    zDelta(k,:) = z';
    wDelta(k,:) = w';
    wpOut(k,:) = p';
    wGuess = w;
end

    function dx = rhs(tNow,xNow)
        p = input_value(tNow);
        q = P.C*xNow+P.Dp*p;
        [w,~] = close_loop(q,wLast);
        wLast = w;
        dx = P.A*xNow+P.BDelta*w+P.Bp*p;
    end

    function [w,z] = close_loop(q,wGuess)
        if ~hasLoop
            z = q;
            w = delta_value(z);
            return
        end
        F = @(wTry) wTry-delta_value(q+P.DDelta*wTry);
        [w,residual] = fsolve(F,wGuess,opts.alg);
        w = w(:);
        if norm(residual,inf)>opts.algTol
            error(['The Delta algebraic loop did not converge ', ...
                '(residual %.3e).'],norm(residual,inf));
        end
        z = q+P.DDelta*w;
    end

    function p = input_value(tNow)
        p = wpFun(tNow);
        p = p(:);
        if numel(p)~=np
            error('wp(t) has incompatible dimensions.');
        end
    end

    function w = delta_value(z)
        w = Delta(z);
        w = w(:);
        if numel(w)~=nDelta
            error('Delta(zDelta) has incompatible dimensions.');
        end
    end
end

function [PN,Dop,x0] = discretize_PIE(P,N,x0)
physicalDomain = P.dom;
psize.N = N;
nx = P.T.dim(2,1);
if isempty(P.x_tab)
    psize.n = nx;
else
    psize.n = zeros(1,max(P.x_tab(:,end))+1);
    for order = 0:max(P.x_tab(:,end))
        psize.n(order+1) = sum( ...
            P.x_tab(P.x_tab(:,end)==order & P.x_tab(:,3),2));
    end
end

x0 = discretize_initial_condition(x0,P,psize,physicalDomain,N);
P = rescalePIE(P,[-1,1]);

Dop = PIESIM_discretize_ops(P,psize);
if ~isempty(Dop.Twcheb) && any(abs(Dop.Twcheb)>1e-12,'all')
    error('A nonlinear input with a nonzero Tw term is not supported.');
end

% PIESIM already returns Atotal=Tcheb_inv*Acheb.
PN.A = Dop.Atotal;
PN.B = Dop.Tcheb_inv*Dop.B1cheb;
PN.C = Dop.C1cheb;
PN.D = Dop.D11cheb;
PN.Cu = Dop.C2cheb;
PN.Du = Dop.D21cheb;
end

function x0 = discretize_initial_condition( ...
    initialCondition,PIE,psize,physicalDomain,N)
% Convert physical primary-state profiles to fundamental-state Chebyshev
% coefficients. Numeric input retains the original pre-discretized API.
if isnumeric(initialCondition)
    x0 = initialCondition(:);
    return
end
if ~isstruct(initialCondition)
    error(['x0 must be a numeric fundamental-state vector or a struct ', ...
           'with fields ode and pde.']);
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
    polynomialDegree = N-derivativeOrder;
    if polynomialDegree<1
        error(['PIESIM degree N=%d is too small for PDE state %d, ', ...
               'which has differentiability order %d.'], ...
              N,stateIndex,derivativeOrder);
    end

    computationalGrid = cos(pi*(0:polynomialDegree)/polynomialDegree)';
    physicalGrid = 0.5*(physicalDomain(2)-physicalDomain(1))* ...
                   computationalGrid + 0.5*sum(physicalDomain);
    profile = pdeInitial{stateIndex};

    if isa(profile,'sym')
        spatialVariables = symvar(profile);
        if numel(spatialVariables)>1
            error('Each symbolic x0.pde profile may use one variable.');
        elseif isempty(spatialVariables)
            if derivativeOrder==0
                profileValues = double(profile)*ones(size(physicalGrid));
            else
                profileValues = zeros(size(physicalGrid));
            end
        else
            fundamentalProfile = diff( ...
                profile,spatialVariables(1),derivativeOrder);
            profileValues = double(subs( ...
                fundamentalProfile,spatialVariables(1),physicalGrid));
        end
    elseif isnumeric(profile) && isscalar(profile)
        if derivativeOrder==0
            profileValues = profile*ones(size(physicalGrid));
        else
            profileValues = zeros(size(physicalGrid));
        end
    elseif isa(profile,'function_handle')
        % Sample the physical primary state at the degree-N Chebyshev
        % nodes, transform it, and differentiate its coefficients. Each
        % derivative lowers the degree by one and introduces the physical
        % domain scaling d/ds = 2/(b-a) d/dxi.
        primaryComputationalGrid = cos(pi*(0:N)/N)';
        primaryPhysicalGrid = 0.5*(physicalDomain(2)-physicalDomain(1))* ...
                              primaryComputationalGrid + ...
                              0.5*sum(physicalDomain);
        primaryValues = profile(primaryPhysicalGrid);
        primaryValues = primaryValues(:);
        if numel(primaryValues)~=N+1 || any(~isfinite(primaryValues))
            error('Function-handle x0.pde profile %d returned invalid values.', ...
                  stateIndex);
        end
        coefficients = fcht(primaryValues);
        derivativeScale = 2/(physicalDomain(2)-physicalDomain(1));
        for derivativeIndex = 1:derivativeOrder
            coefficients = derivativeScale* ...
                differentiate_chebyshev_coefficients(coefficients);
        end
        pdeCoefficients{stateIndex} = coefficients;
        continue
    else
        error('Unsupported x0.pde profile for state %d.',stateIndex);
    end

    profileValues = profileValues(:);
    if numel(profileValues)~=polynomialDegree+1 || ...
            any(~isfinite(profileValues))
        error('x0.pde profile %d returned invalid grid values.',stateIndex);
    end
    pdeCoefficients{stateIndex} = fcht(profileValues);
end

x0 = [odeInitial;vertcat(pdeCoefficients{:})];
end

function derivative = differentiate_chebyshev_coefficients(coefficients)
% Differentiate sum_k coefficients(k+1)*T_k(xi) in coefficient space.
coefficients = coefficients(:);
degree = numel(coefficients)-1;
if degree<1
    derivative = 0;
    return
end

work = zeros(degree+1,1,class(coefficients));
work(degree) = 2*degree*coefficients(degree+1);
for coefficientDegree = degree-2:-1:0
    work(coefficientDegree+1) = work(coefficientDegree+3) + ...
        2*(coefficientDegree+1)*coefficients(coefficientDegree+2);
end
work(1) = 0.5*work(1);
derivative = work(1:degree);
end

function P = operator_value(value,inputDim,vars,dom,name)
if isnumeric(value)
    outputDim = zeros(size(inputDim));
    outputDim(1) = size(value,1);
    if size(value,2)~=sum(inputDim)
        error('%s has incompatible dimensions.',name);
    end
    P = mat2opvar(value,[outputDim,inputDim],vars,dom);
elseif isa(value,'opvar')
    P = value;
    if ~all(P.dim(:,2)==inputDim)
        error('%s has incompatible input dimensions.',name);
    end
else
    error('%s must be numeric or a PI operator.',name);
end
end

function P = compatible_operator(value,outputDim,inputDim,vars,dom,name)
if isnumeric(value)
    if ~isequal(size(value),[sum(outputDim),sum(inputDim)])
        error('%s has incompatible dimensions.',name);
    end
    P = mat2opvar(value,[outputDim,inputDim],vars,dom);
elseif isa(value,'opvar')
    P = value;
    if ~all(P.dim(:,1)==outputDim) || ~all(P.dim(:,2)==inputDim)
        error('%s has incompatible PI dimensions.',name);
    end
else
    error('%s must be numeric or a PI operator.',name);
end
end

function P = zero_operator(outputDim,inputDim,vars,dom)
P = mat2opvar(zeros(sum(outputDim),sum(inputDim)), ...
    [outputDim,inputDim],vars,dom);
end

function P = identity_operator(dim,vars,dom)
P = mat2opvar(eye(sum(dim)),[dim,dim],vars,dom);
end

function plot_simulation(sim,opts)
indices = opts.states(:)';
if isempty(indices)
    indices = 1:min(2,size(sim.x,2));
end
if any(indices<1) || any(indices>size(sim.x,2))
    error('opts.states contains an invalid discretized-state index.');
end

figure('Color','w');
tiledlayout(numel(indices)+1,1);
for k = 1:numel(indices)
    nexttile;
    plot(sim.t,sim.x(:,indices(k)),'LineWidth',1.5);
    grid on;
    if numel(opts.labels)>=k
        ylabel(opts.labels{k});
    else
        ylabel(sprintf('x_%d',indices(k)));
    end
end
nexttile;
plot(sim.t,sim.u,'LineWidth',1.5);
grid on;
ylabel('u');
xlabel('Time [s]');
end
