function sim = simulate_memoryless_nonlinear_pde_using_PIESIM( ...
    N, tFinal, makePlot)
%SIMULATE_MEMORYLESS_NONLINEAR_PDE_USING_PIESIM ODE-PDE simulation.
%
%   SIM = SIMULATE_MEMORYLESS_NONLINEAR_PDE_USING_PIESIM(N,TFINAL,PLOT)
%   uses PIETOOLS/PIESIM to simulate the scalar nonlinear feedback loop
%
%     x_t(s,t) = 0.1*x_ss(s,t) - 0.4*x(s,t) + w(t) + u(t),
%       eta_dot = -0.8*eta(t) + integral_0^1 x(s,t) ds,
%             z = eta(t),             w(t) = tanh(z(t)),
%             u = K*[eta;x],                     K = 0,
%
%   with x(0,t)=x(1,t)=0, x(s,0)=0.7*sin(pi*s), and eta(0)=0.
%   The nonlinearity has one scalar input and one scalar output. The PDE
%   and ODE are declared together and converted to a PIE by PIETOOLS.
%
%   Defaults: N=16, TFINAL=8, PLOT=true. N is the Chebyshev degree used
%   by PIESIM. The returned structure includes the reconstructed fields
%   SIM.xPDE, SIM.xODE, and SIM.s in addition to the PIE_sim_nl output.

    if nargin < 1 || isempty(N)
        N = 16;
    end
    if nargin < 2 || isempty(tFinal)
        tFinal = 8;
    end
    if nargin < 3 || isempty(makePlot)
        makePlot = true;
    end

    validateattributes(N, {'numeric'}, {'scalar','integer','>=',4});
    validateattributes(tFinal, {'numeric'}, {'scalar','real','positive'});
    validateattributes(makePlot, {'logical','numeric'}, {'scalar'});

    pietoolsRoot = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
    if ~isfolder(pietoolsRoot)
        error('PIETOOLS installation not found at "%s".', pietoolsRoot);
    end
    addpath(genpath(pietoolsRoot));
    addpath(fileparts(mfilename('fullpath')), '-begin');

    %% Declare the coupled ODE-PDE plant
    pvar t s
    domain = [0,1];

    xPDE = pde_var('state',1,s,domain);
    xODE = pde_var('state');
    z = pde_var('output');       % scalar input to Delta
    w = pde_var('input');        % scalar output from Delta
    control = pde_var('control');

    PDE = [diff(xPDE,t) == 0.1*diff(xPDE,s,2) - 0.4*xPDE + w + control;
           diff(xODE,t) == -0.8*xODE + int(xPDE,s,domain(1),domain(2));
           z == xODE;
           subs(xPDE,s,domain(1)) == 0;
           subs(xPDE,s,domain(2)) == 0];

    plantPIE = convert(PDE);

    % Put the converted system in the plant format expected by PIE_sim_nl.
    P.vars = plantPIE.vars;
    P.dom = plantPIE.dom;
    P.T = plantPIE.T;
    P.A = plantPIE.A;
    P.B1 = plantPIE.B1;
    P.Bu = plantPIE.B2;
    P.C1 = plantPIE.C1;
    P.D11 = plantPIE.D11;
    P.Dzu = plantPIE.D12;
    P.x_tab = plantPIE.x_tab;

    %% Form the scalar nonlinear interconnection with K=0
    % No IQC filter states are needed for this simulation. These empty PI
    % operators preserve the general interconnection used by PIE_sim_nl.
    emptyDim = zeros(size(P.T.dim,1),1);
    Theta.T = zero_operator(emptyDim,emptyDim,P.vars,P.dom);
    Theta.A = zero_operator(emptyDim,emptyDim,P.vars,P.dom);
    Theta.B1 = zero_operator(emptyDim,P.C1.dim(:,1),P.vars,P.dom);
    Theta.B2 = zero_operator(emptyDim,P.B1.dim(:,2),P.vars,P.dom);

    CL.P = P;
    CL.Theta = Theta;
    CL.K = zero_operator(P.Bu.dim(:,2),P.T.dim(:,2),P.vars,P.dom);
    CL.CDelta = P.C1;

    Delta = @(zScalar) tanh(zScalar);

    %% Initial condition in physical primary-state coordinates
    % PIE_sim_nl owns the conversion to PIESIM fundamental-state Chebyshev
    % coefficients. The implementation only specifies the physical ODE
    % state and PDE profile.
    x0.ode = 0;
    x0.pde = {@(position) 0.7*sin(pi*position)};

    simOpts.N = N;
    simOpts.nDelta = 1;
    simOpts.plot = false;
    simOpts.ode = odeset('RelTol',1e-8,'AbsTol',1e-10);
    requestedTimes = linspace(0,tFinal,201);
    sim = PIE_sim_nl(CL,Delta,requestedTimes,x0,simOpts);

    %% Reconstruct the physical ODE and PDE states
    primaryCheb = sim.Dop.Tcheb_2PDEstate*sim.x';
    sim.xODE = primaryCheb(1,:)';
    sim.xPDE = zeros(numel(sim.t),N+1);
    for timeIndex = 1:numel(sim.t)
        sim.xPDE(timeIndex,:) = ifcht(primaryCheb(2:end,timeIndex))';
    end
    computationalGrid = cos(pi*(0:N)/N)';
    sim.s = 0.5*(domain(2)-domain(1))*computationalGrid + ...
            0.5*sum(domain);
    sim.model = struct('diffusivity',0.1,'decayRate',0.4, ...
                       'odeDecayRate',0.8,'K',0, ...
                       'nonlinearity','w = tanh(z)');

    if max(abs(sim.u),[],'all') > 1e-12
        error('The controller output is nonzero even though K=0.');
    end
    if max(abs(sim.zDelta-sim.xODE),[],'all') > 1e-8
        error('The reconstructed scalar nonlinear channel is inconsistent.');
    end

    if makePlot
        plot_results(sim);
    end
end

function op = zero_operator(rowDim,colDim,vars,dom)
    op = mat2opvar(zeros(sum(rowDim),sum(colDim)), ...
                   [rowDim,colDim],vars,dom);
end

function plot_results(sim)
    figure('Color','w');
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

    nexttile([1,2]);
    surf(sim.s,sim.t,sim.xPDE,'EdgeColor','none');
    xlabel('Position s');
    ylabel('Time t');
    zlabel('x(s,t)');
    title('PIESIM solution of the PDE state (K=0)');
    colorbar;
    view(40,30);
    axis tight;

    nexttile;
    plot(sim.t,sim.xODE,'LineWidth',1.5);
    hold on;
    plot(sim.t,sim.wDelta,'--','LineWidth',1.5);
    hold off;
    xlabel('Time t');
    ylabel('Scalar signals');
    legend('\eta(t)=z(t)','w(t)=tanh(z(t))','Location','best');
    title('Scalar memoryless nonlinear loop');
    grid on;

    nexttile;
    sampleRows = unique(round(linspace(1,numel(sim.t),5)));
    plot(sim.s,sim.xPDE(sampleRows,:),'LineWidth',1.5);
    xlabel('Position s');
    ylabel('x(s,t)');
    legend(compose('t = %.2f',sim.t(sampleRows)),'Location','best');
    title('PDE state snapshots');
    grid on;
end
