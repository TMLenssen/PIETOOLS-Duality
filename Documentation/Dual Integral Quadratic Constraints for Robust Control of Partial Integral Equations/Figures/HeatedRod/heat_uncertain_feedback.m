%% Heat equation with uncertain heat generation: stable and unstable outputs
% Run this script directly. Only base MATLAB is required.
%
% theta(t,s) is temperature deviation from an operating temperature T0,
% in degrees C, along a rod containing an exothermically reacting material:
%
%   theta_t = a*theta_ss + [k0*(1 + delta) - h]*theta + u(t),  0 < s < L
%   theta(t,0) = theta(t,L) = 0,    theta(0,s) = 0
%   y(t) = (1/L)*integral_0^L theta(t,s) ds.
%
% PHYSICAL INTERPRETATION OF THE REACTION TERM
% Both ends are held at T0. Baseline heat removal balances steady reaction
% heat at the operating point; the equations describe deviations from that
% balance. The additional heater pulse u(t) has units degrees C/s.
% An exothermic reaction releases heat and speeds up when temperature rises.
% For example, with approximately constant reactant concentration, let
%   Qgen(T,delta) = (1 + delta)*Qstar*exp(-Ea/(R*T)) [W/m^3],
% where T is absolute temperature, Ea is activation energy, R is the gas
% constant, and Qstar includes reaction enthalpy and the rate prefactor.
% Linearizing the heat source about T0 and dividing by rho*cp gives
%   [Qgen(T0+theta,delta)-Qgen(T0,delta)]/(rho*cp)
%       approximately k0*(1 + delta)*theta,
%   k0 = Qstar*exp(-Ea/(R*T0))*Ea/(rho*cp*R*T0^2).
% Thus delta can represent relative uncertainty in the reaction-rate
% prefactor (e.g. effective catalyst activity), assumed uniform and constant
% over this experiment. Delta = 0.5 means 50% more temperature-sensitive
% heat generation. Cooling remains positive and contributes -h*theta.
% More heating -> faster reaction -> more heating is positive feedback.
% Diffusion and cooling oppose it. Reactant depletion and nonlinear thermal
% effects are neglected: growth demonstrates local instability, not a
% quantitatively valid prediction of unlimited physical temperature.
% Arrhenius heat-source example:
% https://doc.comsol.com/6.4/doc/com.comsol.help.models.chem.thermal_decomposition/thermal_decomposition.html
%
% The PDE state is a temperature field; the measured output y is one number,
% the average temperature deviation. This is an illustrative thermal model;
% unbounded growth indicates instability of the linearized model.
%
% The exact PDE modal growth rates are
%   lambda_n = k0*(1 + delta) - h - a*(n*pi/L)^2, n = 1, 2, ...
% Thus stability requires delta < (h + a*(pi/L)^2)/k0 - 1.
% A positive first-mode growth rate makes the measured average diverge
% after the pulse: uniform heating excites this mode and the average sees it.

clearvars;
close all;
clc;

%% Physical parameters and heater pulse
L = 1;                         % Rod length [m]
a = 0.01;                      % Thermal diffusivity [m^2/s]
h = 0.2;                       % Fixed positive cooling rate [1/s]
k0 = 0.25;                     % Nominal heat-generation sensitivity [1/s]
delta = -0.5:0.1:0.5;           % Sweep uncertain reaction sensitivity
kappa = k0*(1 + delta);
lambda1 = kappa - h - a*(pi/L)^2;
deltaCritical = (h + a*(pi/L)^2)/k0 - 1;
heaterRate = 2;                 % Heater-induced temperature rise [C/s]
heaterOff = 8;                  % Heater switches off at this time [s]
dt = 0.05;                     % Time between output samples [s]
t = (0:dt:30).';
u = heaterRate*double(t < heaterOff);
assert(h > 0 && all(kappa >= 0), 'Use positive cooling and nonnegative heating.');
assert(abs(heaterOff/dt-round(heaterOff/dt)) < 1e-10, ...
    'Align the heater switching time with the sampling grid.');

%% Spatial discretization, with zero boundary temperatures eliminated
N = 99;                        % Number of interior spatial grid points
ds = L/(N+1);
e = ones(N,1);
Dss = spdiags([e, -2*e, e], -1:1, N, N)/ds^2;
B = ones(N,1);                 % Uniform distributed heating
C = (ds/L)*ones(1,N);          % Trapezoidal spatial average; endpoints = 0
y = zeros(numel(t), numel(delta));

% Exact time propagation of the spatially discretized model for each
% constant-input interval: x(k+1) = Ad*x(k) + Bd*u(k).
% The PDE approximation error is spatial; no time integrator is needed.
for j = 1:numel(delta)
    A = a*Dss + (kappa(j)-h)*speye(N);
    % Augmented exponential also works when A is singular at the threshold.
    step = expm([full(A), B; zeros(1,N+1)]*dt);
    Ad = step(1:N,1:N);
    Bd = step(1:N,N+1);
    x = zeros(N,1);
    for k = 1:numel(t)-1
        x = Ad*x + Bd*u(k);
        y(k+1,j) = C*x;
    end
end

%% Plot output trajectories: blue when stable, red when unstable
trajectoryColor = [0.10, 0.36, 0.61];
unstableColor = [0.78, 0.19, 0.16];
curveColors = repmat(trajectoryColor,numel(delta),1);
isUnstable = lambda1 > 0;
curveColors(isUnstable,:) = repmat(unstableColor,sum(isUnstable),1);
fig = figure('Color','w', 'Position',[100, 100, 1050, 600]);
axOutput = axes(fig, 'Position',[0.10, 0.13, 0.72, 0.82]);
hold(axOutput,'on');
for j = 1:numel(delta)
    plot(axOutput, t, y(:,j), 'LineWidth',1.8, 'Color',curveColors(j,:));
end
grid(axOutput,'on');
xlabel(axOutput, '$t$', 'Interpreter','latex');
ylabel(axOutput, 'Average temperature');
ylim(axOutput, [0, 1.05*max(y,[],'all')]);
xlim(axOutput, [t(1), t(end)]);
axOutput.Toolbar.Visible = 'off';

% Label each curve at its endpoint. Spread labels in the right margin so
% trajectories approaching zero remain individually identifiable.
[endpointY, labelOrder] = sort(y(end,:));
plotHeight = diff(ylim(axOutput));
labelGap = 0.038*plotHeight;
labelY = endpointY;
labelY(1) = max(labelY(1), 0.02*plotHeight);
for j = 2:numel(delta)
    labelY(j) = max(labelY(j), labelY(j-1)+labelGap);
end
timeSpan = t(end)-t(1);
for j = 1:numel(delta)
    curveIndex = labelOrder(j);
    plot(axOutput, [t(end), t(end)+0.04*timeSpan], ...
        [endpointY(j), labelY(j)], 'Color',curveColors(curveIndex,:), ...
        'LineWidth',0.7, 'Clipping','off', 'HandleVisibility','off');
    text(axOutput, t(end)+0.05*timeSpan, labelY(j), ...
        ['\delta = ', sprintf('%.1f',delta(curveIndex))], ...
        'Interpreter','tex', 'Color',curveColors(curveIndex,:), 'FontSize',10, ...
        'VerticalAlignment','middle', 'Clipping','off', 'Tag','deltaLabel');
end

%% Save a preview alongside the script; leave the figure open for inspection
outputFolder = fileparts(mfilename('fullpath'));
exportgraphics(fig, fullfile(outputFolder,'heat_uncertain_feedback.png'), ...
    'Resolution',200);
fprintf('Scalar output: average temperature deviation from T0.\n');
fprintf('PDE is exponentially stable for delta < %.4f.\n',deltaCritical);
for j = 1:numel(delta)
    fprintf('delta = %+.1f, first-mode growth rate = %+.4f 1/s, final output = %.3f C\n', ...
        delta(j), lambda1(j), y(end,j));
end
