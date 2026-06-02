clear; clc; close all; clear stateNameGenerator
echo on

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b")) 
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
% =============================================
% === Declare the system of interest

% % Declare system as PDE
% Declare independent variables (time and space)
pvar t s
a=0;
b=1;
% Declare state, input, and output variables
x = pde_var();
v1 = pde_var(1,s,[a,b]);
v2 = pde_var(1,s,[a,b]);
zd1 = pde_var('output',1,s,[a,b]); wd1 = pde_var('input',1,s,[a,b]);
zd2 = pde_var('output',1,s,[a,b]); wd2 = pde_var('input',1,s,[a,b]);
z1 = pde_var('out');                w = pde_var('in');
z2 = pde_var('out');
y = pde_var('sense');              u = pde_var('control');
d = 1;
lam = 4;
% Declare the system equations
PDE = [diff(v1,t) == v2;    % PDE
    diff(v2,t) == d*diff(v1,s,2) + wd1 +s*(2-s)*w;
    diff(x,t) == u;
    zd1 == diff(v1,s,2);
    z1 == u;
    z2 == int(v1,s,[a,b]);                 % regulated output
    subs(v1,s,a) == 0;                        % first boundary condition
    subs(v2,s,a) == 0;
    subs(diff(v1,s),s,1)==x];               % second boundary condition

display_PDE(PDE);

% % Convert PDE to PIE
PIE = convert(PDE);
misc = PIE.misc;
dim = PIE.dim;
dom = PIE.dom;
vars = PIE.vars;
T = PIE.T; Tw = PIE.Tw; Tu = PIE.Tu;
A = PIE.A;          Bd = PIE.B1(:,2);     Bw = PIE.B1(:,1);     Bu = PIE.B2;
Cd = PIE.C1(3,:); Dd = PIE.D11(3,2);  Ddw = PIE.D11(3,1); Ddu = PIE.D12(3, 1);
Cz = PIE.C1(1:2,:); Dzd = PIE.D11(1:2,2); Dzw = PIE.D11(1:2,1); Dzu = PIE.D12(1:2,1);



%%



settings = lpisettings('heavy');
% settings.sosineq_on = 1;
% settings.opts.pzats = 1;
settings.sos_opts.solver = 'mosek';

dd1 = settings.dd1;
dd12 = settings.dd12;
sos_opts = settings.sos_opts;
options1 = settings.options1;
options12 = settings.options12;
override1 = settings.override1;
eppos = settings.eppos;
epneg = settings.epneg;
eppos2 = settings.eppos2;
ddZ = settings.ddZ;
sosineq_on = settings.sosineq_on;
if sosineq_on
    opts = settings.opts;
else
    override2 = settings.override2;
    options2 = settings.options2;
    options3 = settings.options3;
    dd2 = settings.dd2;
    dd3 = settings.dd3;
end
if ~(Tw==0)
    error('\n --- Non-coercive LPIs cannot currently be solved for systems with disturbances at the boundary. ---\n');
end

% Example: use bisection on gamma
gam_min = 0;       % set lower bound for gamma
gam_max = 10000;       % set upper bound for gamma
gam =0.5 * (gam_min + gam_max);
% dpvar gamV gamVhat;

while (gam_max - gam_min) > 1e-3
    % Don't support boundary disturbances


    % Declare an SOS program and initialize domain and opvar spaces
    %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    prog = lpiprogram(PIE.vars(:,1),PIE.vars(:,2),PIE.dom);      % Initialize the program structure
    % % 
    % prog = lpidecvar(prog, gamV); % set gam = gamma as decision variable
    % prog = lpi_ineq(prog, gamV);  % enforce gamma>=0
    % prog = lpisetobj(prog, gamV); % set gamma as objective function to minimize
    % %     % STEP 1: declare the posopvar variable, Pop, which defines the storage
    % function candidate and the indefinite operator Zop, which is used to
    % contruct the estimator gain
    disp('- Declaring Positive Lyapunov Operator variable using specified options...');

    [prog, R1op] = poslpivar(prog, T.dim,dd1,options1);

    if override1~=1
        [prog, P2op] = poslpivar(prog, T.dim,dd12,options12);
        Rop=R1op+P2op;
    else
        Rop=R1op;
    end

    % Also declare an indefinite operator Qop=Pop*Top so that Rop = Top'*Qop.   % DJ, 01/06/2025
    Qdeg = get_lpivar_degs(Rop,T);
    [prog, Q] = lpivar(prog,T.dim,Qdeg);
    prog = lpi_eq(prog, T'*Q-Rop);

    [prog,Z] = lpivar(prog,Bu.dim(:,[2,1]),ddZ);
    epsilon = 1e-4;

    for k = 1:1
        % V_opts.exclude = [0,0,1,1];
        [prog, P_blocks{k}] = poslpivar(prog, [0, 0; 1, 1], 3, settings.options1);
    end
    P = blkdiag(P_blocks{:});
    for k = 1:1
        % V_opts.exclude = [0,0,1,1];
        [prog, R_blocks{k}] = lpivar(prog, [0, 0; 1, 1], 3, settings.options1);
    end
    R = blkdiag(R_blocks{:});
    Id = mat2opvar(eye(size(Bd,2)), Bd.dim(:,2), PIE.vars, PIE.dom);
    Iw = mat2opvar(eye(size(Bw,2)), Bw.dim(:,2), PIE.vars, PIE.dom);
    Iz = mat2opvar(eye(size(Cz,1)), Cz.dim(:,1), PIE.vars, PIE.dom);
    Zd = mat2opvar(zeros(1,1), [0,0;1,1], PIE.vars, PIE.dom);
    Zdw = mat2opvar(zeros(1,1), [0,1;1,0], PIE.vars, PIE.dom);
    Zdz = mat2opvar(zeros(1,2), [0,2;1,0], PIE.vars, PIE.dom);
    Zw = mat2opvar(zeros(1,1), [1,1;0,0], PIE.vars, PIE.dom);
    Zwd = mat2opvar(zeros(1,1), [1,0;0,1], PIE.vars, PIE.dom);
    Zzd = mat2opvar(zeros(2,1), [2,0;0,1], PIE.vars, PIE.dom);
    Zzw = mat2opvar(zeros(2,1), [2,1;0,0], PIE.vars, PIE.dom);
    Zxd = mat2opvar(zeros(3,1), [1,0;2,1], PIE.vars, PIE.dom);
    Zxz = mat2opvar(zeros(3,2), [1,2;2,0], PIE.vars, PIE.dom);
    Zdx = mat2opvar(zeros(1,3), [0,1;1,2], PIE.vars, PIE.dom);
    V11 = P;
    V12 = R - R';
    V21 = R' - R;
    V22 = -P;
    V_mu = [V11, V12; V21, V22];
    V_hat = [Iw, Zzw'; Zzw, -Iz];
    Op1 = [Bd, Zxd; Dd, gam*Id; Dzd, Zzd];
    Op2 = [Bw, Zxz; Ddw, Zdz; Dzw, Iz];
    eps = 1e-9;
    
    % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % STEP 2: Define the KYP matrix


    disp('- Constructing the Negativity Constraint...');

    Dop1 = [A*Q+Bu*Z+Q'*A'+Z'*Bu', Q'*Cd'+Z'*Ddu', Q'*Cz'+Z'*Dzu';
            Cd*Q+Ddu*Z,      eps*Id,            Zdz;
            Cz*Q+Dzu*Z,       Zzd,            eps*Iz];

    
    Dop2 = Op1*V_mu*Op1';

    Dop3 = Op2*V_hat*Op2';

    Dop = Dop1 + Dop2 + Dop3;

    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % STEP 3: Impose Negativity Constraint. There are two methods, depending on
    % the options chosen
    %
    disp('- Enforcing the Negativity Constraint...');
    if sosineq_on
        disp('  - Using lpi_ineq');
        prog = lpi_ineq(prog,-Dop,opts);
    else
        disp('  - Using an Equality constraint...');
        [prog, De1op] = poslpivar(prog, Dop.dim, dd2, options2);

        if override2~=1
            [prog, De2op] = poslpivar(prog, Dop.dim, dd3, options3);
            Deop=De1op+De2op;
        else
            Deop=De1op;
        end
        prog = lpi_eq(prog,Deop+Dop,'symmetric'); %Dop=-Deop
    end


    %solving the sos program
    disp('- Solving the LPI using the specified SDP solver...');
    prog = lpisolve(prog,sos_opts);
    %Feasibility
    is_pinf = prog.solinfo.info.pinf;       % is primal feasible?
    is_dinf = prog.solinfo.info.dinf;       % is dual feasible?
    feasrat = prog.solinfo.info.feasratio;  % ratio should be close to 1

    if is_dinf || is_pinf || abs(feasrat-1)>0.1   % Stability cannot be verified --> decrease value of rho...
        feas = false;
    else
        % The system is stable --> try larger value of rho...
        feas = true;
    end
    % V11 = lpigetsol(prog,V11);
    if feas
        gam_max = gam;
        validated_gam = gam%(double(lpigetsol(prog,gamV)))
        % validated_V = V11;
        Q = lpigetsol(prog,Q);
        Z = lpigetsol(prog,Z);
        tol = 1e-5;
        Kval = Z*inv(Q,tol);
    else
        gam_min = gam;
    end
    gam = 0.5 * (gam_min + gam_max);
end
%% 



% =============================================
% === Monte Carlo Simulation Parameters
num_simulations = 100;      % Number of Monte Carlo runs
opts.plot = 'no';
opts.N = 8;                % Number of Chebyshev polynomials
opts.tf = 5;               % Simulation time
opts.dt = 0.1e-1;            % Time step
ndiff = [0,0,1];           % PDE state differentiation order

% Initialize storage for results
all_z_act = [];            % Store all z_act trajectories
all_tval = [];             % Store time vectors
all_d = [];                % Store parameter d values
all_lam_u = [];            % Store parameter lam_u values
all_eps1 = [];             % Store eps1 values
all_eps2 = [];             % Store eps2 values


% =============================================
% === Monte Carlo Loop
fprintf('Running Monte Carlo simulation with %d iterations...\n', num_simulations);

for sim_iter = 1:num_simulations
    fprintf('Iteration %d/%d\n', sim_iter, num_simulations);
    
    % Your existing simulation code (with random parameters)
    % =============================================
    % === Simulate the system

    
    % Generate random complex number with magnitude < 1

    
    % Extract real and imaginary parts
    eps1 = 3*rand()-1.5;
    eps2 = 3*rand()-1.5;
    
    % Store epsilon values
    all_eps1(sim_iter) = eps1;
    all_eps2(sim_iter) = eps2;
    
    % Calculate parameters
    d = (1+1/validated_gam*eps1);
    lam_u = lam + 1/validated_gam*eps2;
    
    % Store parameters
    all_d(sim_iter) = d;
    all_lam_u(sim_iter) = lam_u;
    
    PDE = [diff(x,t) == d*diff(x,s,2) + lam_u*x + s*w + s*u;    % PDE
    z1 == u;
    z2 == int(x,s,[a,b]);                 % regulated output
    subs(x,s,a) == 0;                        % first boundary condition
    subs(x,s,b) == 0];           % second boundary condition

    display_PDE(PDE);
    PIE = convert(PDE);

    T = PIE.T;
    A = PIE.A;
    Bu = PIE.B2;
    Bw = PIE.B1;
    Cz = PIE.C1;
    Dzu = PIE.D12;
    Dzw = PIE.D11;
    
    PIE_CL = piess(T,A+Bu*Kval,Bw,Cz+Dzu*Kval,Dzw);

    syms st sx real

    % Create symbolic expression with fixed random values
    w3 = (heaviside(st-0.5)-heaviside(st-0.75));
    
    uinput.ic.PDE = 0;
    uinput.w = w3;

    % Simulate solution to the PIE with estimator
    [solution,~] = PIESIM(PIE_CL,opts,uinput,ndiff);
    
    % Extract actual state and output at each time step
    tval = solution.timedep.dtime;
    x_act = reshape(solution.timedep.pde(:,1,:),opts.N+1,[]);
    z_act = solution.timedep.regulated(2,:);
    
    % Store results
    all_z_act(sim_iter, :) = z_act;
    all_tval(sim_iter, :) = tval;
    
end
%% 

% Additional storage for divergence analysis
diverging_trajectories = []; % Indices of diverging trajectories
inside_hypersphere = [];     % Boolean for each trajectory
divergence_threshold = 0.01; % Threshold for detecting divergence

% =============================================
% === Analyze trajectories for divergence and hypercube membership
fprintf('\nAnalyzing trajectories...\n');

% Check each trajectory for divergence
for i = 1:num_simulations
    % Check if trajectory diverges (exceeds threshold)
    final_z = abs(all_z_act(i, end));
    if final_z > divergence_threshold
        diverging_trajectories(end+1) = i;

        inside_hypersphere(end+1) = sqrt((all_d(i)-1)^2+(all_lam_u(i)-4)^2)<= 1/validated_gam;
    end
end

% Get indices of stable trajectories (non-diverging)
stable_indices = setdiff(1:num_simulations, diverging_trajectories);

% =============================================
% === Publication-Quality Plotting Results
figure('Position', [100, 100, 1200, 500], 'Color', 'white');
sgtitle('\textbf{Structured Controller Gain Synthesis}', 'interpreter', 'latex');
% Set font sizes for publication
title_fontsize = 12;
axis_fontsize = 12;
legend_fontsize = 10;

% Subplot 1: Parameter scatter plot
subplot(1,2,1);
hold on;
box on; % Add box around plot

% Create separate arrays for different categories
stable_d = []; stable_lam = [];
diverging_inside_d = []; diverging_inside_lam = [];
diverging_outside_d = []; diverging_outside_lam = [];

% Classify points
for i = 1:num_simulations
    if ismember(i, diverging_trajectories)
        idx_in_div = find(diverging_trajectories == i);
        if inside_hypersphere(idx_in_div)
            diverging_inside_d(end+1) = all_d(i);
            diverging_inside_lam(end+1) = all_lam_u(i);
        else
            diverging_outside_d(end+1) = all_d(i);
            diverging_outside_lam(end+1) = all_lam_u(i);
        end
    else
        stable_d(end+1) = all_d(i);
        stable_lam(end+1) = all_lam_u(i);
    end
end

% Plot with explicit handles for legend
legend_handles = [];
legend_labels = {};

% Plot stable trajectories
if ~isempty(stable_d)
    h1 = scatter(stable_d, stable_lam, 40, [0.2, 0.4, 0.8], 'filled', 'o', ...
                'MarkerEdgeColor', [0.1, 0.3, 0.7], 'LineWidth', 0.8);
    legend_handles(end+1) = h1;
    legend_labels{end+1} = 'Stable';
end

% Plot diverging inside hypercube
if ~isempty(diverging_inside_d)
    h2 = scatter(diverging_inside_d, diverging_inside_lam, 50, [0.9, 0.3, 0.3], 'filled', '^', ...
                'MarkerEdgeColor', [0.7, 0.1, 0.1], 'LineWidth', 0.8);
    legend_handles(end+1) = h2;
    legend_labels{end+1} = 'Unstable (inside $\frac{1}{\gamma_V}\mathbf{\Delta}$)';
end

% Plot diverging outside hypercube
if ~isempty(diverging_outside_d)
    h3 = scatter(diverging_outside_d, diverging_outside_lam, 50, [0.3, 0.7, 0.3], 'filled', 's', ...
                'MarkerEdgeColor', [0.1, 0.5, 0.1], 'LineWidth', 0.8);
    legend_handles(end+1) = h3;
    legend_labels{end+1} = 'Unstable (outside $\frac{1}{\gamma_V}\mathbf{\Delta}$)';
end

% Plot circular boundary
half_side = 1/validated_gam;   % radius of the circle
theta = linspace(0, 2*pi, 200);  % angle values for smooth circle
circle_x = 1 + half_side * cos(theta);
circle_y = lam + half_side * sin(theta);

h4 = plot(circle_x, circle_y, 'k-', 'LineWidth', 1.2);
legend_handles(end+1) = h4;
legend_labels{end+1} = 'Uncertainty set $\frac{1}{\gamma_V}\mathbf{\Delta}$';


% Plot center point
h5 = plot(1, lam, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'black', ...
          'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
legend_handles(end+1) = h5;
legend_labels{end+1} = 'Nominal';

% Configure plot appearance
xlabel('Parameter $d$', 'FontSize', axis_fontsize, 'Interpreter', 'latex');
ylabel('Parameter $\lambda$', 'FontSize', axis_fontsize, 'Interpreter', 'latex');
title('\textit{Parameter Space with Stability Regions}', 'FontSize', title_fontsize, 'Interpreter', 'latex');
legend(legend_handles, legend_labels, 'Location', 'best', 'FontSize', legend_fontsize, 'Interpreter', 'latex');
grid on;
axis equal;

% Set nice axis limits with some padding
x_range = max(all_d) - min(all_d);
y_range = max(all_lam_u) - min(all_lam_u);
xlim([min(all_d)-0.1*x_range, max(all_d)+0.1*x_range]);
ylim([min(all_lam_u)-0.1*y_range, max(all_lam_u)+0.1*y_range]);

% Subplot 2: Trajectories plot
subplot(1,2,2);
hold on;
box on; % Add box around plot

% Set y-axis limits to focus on stable region
if ~isempty(stable_indices)
    stable_max = max(max(all_z_act(stable_indices, :)));
    y_upper = min(0.15, stable_max * 1.3); % More conservative upper limit
else
    y_upper = 0.15;
end
ylim([0, y_upper]);

% Create explicit handles for legend
traj_handles = [];
traj_labels = {};

% Plot non-diverging trajectories
if ~isempty(stable_indices)
    for i = stable_indices
        h = plot(all_tval(i,:), all_z_act(i,:), 'Color', [0.2, 0.4, 0.8, 0.6], 'LineWidth', 1);
    end
    traj_handles(end+1) = h;
    traj_labels{end+1} = 'Stable';
end

bool1 = false;
bool2 = false;

% Plot diverging trajectories - stop when they exceed y_upper
if ~isempty(diverging_trajectories)
    for i = 1:length(diverging_trajectories)
        idx = diverging_trajectories(i);
        
        % Find where trajectory first exceeds y_upper
        t_vals = all_tval(idx,:);
        z_vals = all_z_act(idx,:);
        exceed_idx = find(z_vals > y_upper, 1);
        
        if isempty(exceed_idx)
            % Never exceeds - plot full trajectory
            t_plot = t_vals;
            z_plot = z_vals;
        else
            % Stop at point before exceeding
            t_plot = t_vals(1:exceed_idx);
            z_plot = z_vals(1:exceed_idx);
        end
        
        if inside_hypersphere(i)
            h = plot(t_plot, z_plot, 'Color', [0.9, 0.3, 0.3, 0.7], 'LineWidth', 1.2, 'LineStyle', '--');
            if ~bool1
                traj_handles(end+1) = h;
                traj_labels{end+1} = 'Unstable (inside $\frac{1}{\gamma_V}\mathbf{\Delta}$)';
                bool1 = true;
            end
        else
            h = plot(t_plot, z_plot, 'Color', [0.3, 0.7, 0.3, 0.7], 'LineWidth', 1.2, 'LineStyle', ':');
            if ~bool2
                traj_handles(end+1) = h;
                traj_labels{end+1} = 'Unstable (outside $\frac{1}{\gamma_V}\mathbf{\Delta}$)';
                bool2 = true;
            end
        end
    end
end

% Plot mean trajectory of STABLE trajectories only
if ~isempty(stable_indices)
    mean_z_act_stable = mean(all_z_act(stable_indices, :), 1);
    h_mean = plot(tval, mean_z_act_stable, 'b-', 'LineWidth', 2.5, 'Color', [0, 0, 0.9]);
    traj_handles(end+1) = h_mean;
    traj_labels{end+1} = 'Mean stable';
end

% Configure plot appearance
xlabel('Time(t)', 'FontSize', axis_fontsize, 'Interpreter', 'latex');
ylabel('$z(t)$', 'FontSize', axis_fontsize, 'Interpreter', 'latex');
title('\textit{System Response Trajectories}', 'FontSize', title_fontsize, 'Interpreter', 'latex');
legend(traj_handles, traj_labels, 'Location', 'best', 'FontSize', legend_fontsize, 'Interpreter', 'latex');
grid on;

% Adjust layout
set(gcf, 'Color', 'white');

% =============================================
% === Display results (unchanged)
fprintf('\n=== Monte Carlo Simulation Complete ===\n');
fprintf('Parameter Statistics:\n');
fprintf('  Parameter d range: [%.4f, %.4f]\n', min(all_d), max(all_d));
fprintf('  Parameter lam_u range: [%.4f, %.4f]\n', min(all_lam_u), max(all_lam_u));
fprintf('  Nominal point: (d=1, λ=%.4f)\n', lam);
fprintf('  Uncertainty half-side: 1/γ = 1/%.4f = %.4f\n', validated_gam, 1/validated_gam);
fprintf('  Number of simulations: %d\n', num_simulations);

% Divergence analysis
fprintf('\nDivergence Analysis:\n');
fprintf('  Divergence threshold: %.0e\n', divergence_threshold);
fprintf('  Total diverging trajectories: %d/%d (%.1f%%)\n', ...
    length(diverging_trajectories), num_simulations, 100*length(diverging_trajectories)/num_simulations);

if ~isempty(diverging_trajectories)
    num_inside = sum(inside_hypersphere);
    num_outside = length(diverging_trajectories) - num_inside;
    fprintf('  Diverging inside hypercube: %d (%.1f%% of diverging)\n', ...
        num_inside, 100*num_inside/length(diverging_trajectories));
    fprintf('  Diverging outside hypercube: %d (%.1f%% of diverging)\n', ...
        num_outside, 100*num_outside/length(diverging_trajectories));
    
    % This is the important result - any red points indicate potential issues
    if num_inside > 0
        fprintf('  WARNING: %d trajectories diverged INSIDE the uncertainty bound!\n', num_inside);
        fprintf('  This may indicate robustness issues.\n');
    end
end

% Stable trajectory statistics
fprintf('\nStable Trajectory Statistics:\n');
fprintf('  Number of stable trajectories: %d/%d (%.1f%%)\n', ...
    length(stable_indices), num_simulations, 100*length(stable_indices)/num_simulations);
if ~isempty(stable_indices)
    stable_final_values = all_z_act(stable_indices, end);
    fprintf('  Final z_act range for stable trajectories: [%.4f, %.4f]\n', ...
        min(stable_final_values), max(stable_final_values));
    fprintf('  Mean final z_act for stable trajectories: %.4f\n', mean(stable_final_values));
end
%% 
% 
% 
PIE_CL = piess(T,A+Bu*Kval,Bw,Cz+Dzu*Kval,Dzw);
% 

% =============================================
% === Simulate the system

% % Declare initial values and disturbance
syms st sx real
uinput.ic.PDE = 0;
w3 = (heaviside(st-0.5)-heaviside(st-0.75));
uinput.w = w3;%2*sin(pi*st);

% % Set options for discretization and simulation
opts.plot = 'yes';  % plot solution
opts.N = 8;         % expand using 8 Chebyshev polynomials
opts.tf = 5;        % simulate up to t = 2
opts.dt = .1e-2;     % use time step of 10^-3
ndiff = [0,0,2];    % PDE state involves 2 second order differentiable state variables

% % Simulate solution to the PIE with estimator.
[solution,grid] = PIESIM(PIE_CL,opts,uinput,ndiff);
% % Extract actual and estimated state and output at each time step.
tval = solution.timedep.dtime;
x_act = reshape(solution.timedep.pde(:,1,:),opts.N+1,[]);
x_est = reshape(solution.timedep.pde(:,2,:),opts.N+1,[]);
z_act = solution.timedep.regulated(1,:);
z_est = solution.timedep.regulated(2,:);


echo off



% % Change titles of plots
figure;
plot(tval, abs(z_act - z_est));
fig3 = figure(3);
fig3.Children(5).String = 'True ($\mathbf{x}_1(t,s)$) and estimated ($\mathbf{x}_2(t,s)$) PDE state evolution';
fig2 = figure(1);     ax = fig2.CurrentAxes;
title(ax,'True ($z_1(t)$) and estimated ($z_2(t)$) regulated output evolution','Interpreter','latex','FontSize',15);