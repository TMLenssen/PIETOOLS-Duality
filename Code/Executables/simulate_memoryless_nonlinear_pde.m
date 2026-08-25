function [s, t, xPDE, xODE, w] = simulate_memoryless_nonlinear_pde( ...
    diffusivity, feedbackGain, N, tFinal, makePlot)
%SIMULATE_MEMORYLESS_NONLINEAR_PDE Finite-difference ODE-PDE reference.
%
%   This function solves
%
%     x_t(s,t) = diffusivity*x_ss(s,t) - 0.4*x(s,t) + w(t) + u(t),
%       eta_dot = -0.8*eta(t) + integral_0^1 x(s,t) ds,
%             z = eta(t),     w(t) = feedbackGain*tanh(z(t)),
%             u = K*[eta;x],                              K = 0,
%
%   with x(0,t)=x(1,t)=0, x(s,0)=0.7*sin(pi*s), and eta(0)=0.
%   The static memoryless nonlinearity therefore acts on a scalar channel,
%   while the ODE and PDE states are dynamically interconnected.
%
%   Inputs are optional. Defaults are diffusivity=0.1, feedbackGain=1,
%   N=150 grid points, tFinal=8, and makePlot=true.

    if nargin < 1 || isempty(diffusivity)
        diffusivity = 0.1;
    end
    if nargin < 2 || isempty(feedbackGain)
        feedbackGain = 1;
    end
    if nargin < 3 || isempty(N)
        N = 150;
    end
    if nargin < 4 || isempty(tFinal)
        tFinal = 8;
    end
    if nargin < 5 || isempty(makePlot)
        makePlot = true;
    end

    validateattributes(diffusivity, {'numeric'}, ...
        {'scalar','real','positive'});
    validateattributes(feedbackGain, {'numeric'}, ...
        {'scalar','real','finite'});
    validateattributes(N, {'numeric'}, {'scalar','integer','>=',4});
    validateattributes(tFinal, {'numeric'}, {'scalar','real','positive'});
    validateattributes(makePlot, {'logical','numeric'}, {'scalar'});

    decayRate = 0.4;
    odeDecayRate = 0.8;
    s = linspace(0,1,N)';
    ds = s(2)-s(1);
    numberOfInteriorPoints = N-2;

    e = ones(numberOfInteriorPoints,1);
    Dss = spdiags([e,-2*e,e],[-1,0,1], ...
                  numberOfInteriorPoints,numberOfInteriorPoints)/ds^2;
    APDE = diffusivity*Dss - decayRate*speye(numberOfInteriorPoints);

    xPDE0 = 0.7*sin(pi*s(2:end-1));
    xODE0 = 0;
    initialState = [xPDE0;xODE0];
    requestedTimes = linspace(0,tFinal,201);

    % The arrow-shaped Jacobian pattern includes the scalar nonlinear
    % feedback from eta to every PDE point and the PDE integral into eta.
    jacobianPattern = blkdiag(spones(APDE),1);
    jacobianPattern(1:numberOfInteriorPoints,end) = 1;
    jacobianPattern(end,1:numberOfInteriorPoints) = 1;
    options = odeset('RelTol',1e-8,'AbsTol',1e-10, ...
                     'JPattern',jacobianPattern);

    rhs = @(~,state) coupled_rhs(state,APDE,s,feedbackGain,odeDecayRate);
    [t,state] = ode15s(rhs,requestedTimes,initialState,options);

    xPDE = [zeros(numel(t),1), ...
            state(:,1:numberOfInteriorPoints),zeros(numel(t),1)];
    xODE = state(:,end);
    w = feedbackGain*tanh(xODE);

    if makePlot
        plot_results(s,t,xPDE,xODE,w);
    end
end

function derivative = coupled_rhs(state,APDE,s,feedbackGain,odeDecayRate)
    interiorState = state(1:end-1);
    odeState = state(end);
    nonlinearOutput = feedbackGain*tanh(odeState);

    pdeDerivative = APDE*interiorState + nonlinearOutput;
    fullPDEState = [0;interiorState;0];
    odeDerivative = -odeDecayRate*odeState + trapz(s,fullPDEState);
    derivative = [pdeDerivative;odeDerivative];
end

function plot_results(s,t,xPDE,xODE,w)
    figure('Color','w');
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

    nexttile([1,2]);
    surf(s,t,xPDE,'EdgeColor','none');
    xlabel('Position s');
    ylabel('Time t');
    zlabel('x(s,t)');
    title('Finite-difference solution of the PDE state (K=0)');
    colorbar;
    view(40,30);
    axis tight;

    nexttile;
    plot(t,xODE,'LineWidth',1.5);
    hold on;
    plot(t,w,'--','LineWidth',1.5);
    hold off;
    xlabel('Time t');
    ylabel('Scalar signals');
    legend('\eta(t)=z(t)','w(t)=tanh(z(t))','Location','best');
    title('Scalar memoryless nonlinear loop');
    grid on;

    nexttile;
    sampleRows = unique(round(linspace(1,numel(t),5)));
    plot(s,xPDE(sampleRows,:),'LineWidth',1.5);
    xlabel('Position s');
    ylabel('x(s,t)');
    legend(compose('t = %.2f',t(sampleRows)),'Location','best');
    title('PDE state snapshots');
    grid on;
end
