%% Upright pendulum: uncontrolled versus state-feedback controlled
clear;
close all;
clc;

%% Physical parameters
p.m = 1.0;                  % Mass [kg]
p.l = 1.0;                  % Pendulum length [m]
p.g = 9.81;                 % Gravity [m/s^2]
p.I = p.m * p.l^2;          % Moment of inertia [kg m^2]
p.b = 0.2;                  % Viscous damping [N m s/rad]

%% State-feedback gains
% u = -kp*q - kd*q_dot
p.kp = 0.2471*1e6;                % Proportional gain [N m/rad]
p.kd = 1.7*1e6;                 % Derivative gain [N m s/rad]

% Local stability requires
%   kp > m*g*l
%   kd > -b
fprintf('m*g*l = %.2f\n', p.m*p.g*p.l);
fprintf('kp    = %.2f\n', p.kp);

%% Initial condition
% q = 0 is the upright equilibrium
q0     = 0.20;              % Initial angular displacement [rad]
qdot0  = 0.00;              % Initial angular velocity [rad/s]
x0     = [q0; qdot0];

%% Simulation interval
tspan = [0, 10];

options = odeset( ...
    'RelTol', 1e-9, ...
    'AbsTol', 1e-11);

%% Simulate uncontrolled system
[tUn, xUn] = ode45( ...
    @(t,x) pendulumDynamics(t, x, p, false), ...
    tspan, x0, options);

%% Simulate controlled system
[tCon, xCon] = ode45( ...
    @(t,x) pendulumDynamics(t, x, p, true), ...
    tspan, x0, options);

%% Compute the control input
uCon = -p.kp*xCon(:,1) - p.kd*xCon(:,2);

%% Plot angle
figure;
plot(tUn, xUn(:,1), 'LineWidth', 1.5);
hold on;
plot(tCon, xCon(:,1), 'LineWidth', 1.5);
yline(0, '--');
grid on;

xlabel('Time [s]');
ylabel('q [rad]');
title('Upright-pendulum angle');
legend('Uncontrolled', 'Controlled', 'Upright equilibrium', ...
       'Location', 'best');

%% Plot angular velocity
figure;
plot(tUn, xUn(:,2), 'LineWidth', 1.5);
hold on;
plot(tCon, xCon(:,2), 'LineWidth', 1.5);
yline(0, '--');
grid on;

xlabel('Time [s]');
ylabel('$\dot q$ [rad/s]', 'Interpreter', 'latex');
title('Angular velocity');
legend('Uncontrolled', 'Controlled', ...
       'Location', 'best');

%% Plot phase trajectories
figure;
plot(xUn(:,1), xUn(:,2), 'LineWidth', 1.5);
hold on;
plot(xCon(:,1), xCon(:,2), 'LineWidth', 1.5);
plot(0, 0, 'ko', 'MarkerFaceColor', 'k');
grid on;

xlabel('q [rad]');
ylabel('$\dot q$ [rad/s]', 'Interpreter', 'latex');
title('Phase trajectories');
legend('Uncontrolled', 'Controlled', 'Origin', ...
       'Location', 'best');

%% Plot control input
figure;
plot(tCon, uCon, 'LineWidth', 1.5);
yline(0, '--');
grid on;

xlabel('Time [s]');
ylabel('u [N m]');
title('State-feedback control input');

%% Local linearized eigenvalues
A_uncontrolled = [ ...
    0,                     1;
    p.m*p.g*p.l/p.I, -p.b/p.I];

A_controlled = [ ...
    0,                                    1;
    (p.m*p.g*p.l-p.kp)/p.I, -(p.b+p.kd)/p.I];

disp('Uncontrolled linearized eigenvalues:');
disp(eig(A_uncontrolled));

disp('Controlled linearized eigenvalues:');
disp(eig(A_controlled));

%% Nonlinear pendulum dynamics
function dx = pendulumDynamics(~, x, p, controllerEnabled)

    q    = x(1);
    qdot = x(2);

    if controllerEnabled
        u = -p.kp*q - p.kd*qdot;
    else
        u = 0;
    end

    % Upright-pendulum model:
    %
    % I*qddot + b*qdot - m*g*l*sin(q) = u
    %
    qddot = ( ...
        u ...
        - p.b*qdot ...
        + p.m*p.g*p.l*sin(q)) / p.I;

    dx = [qdot; qddot];
end