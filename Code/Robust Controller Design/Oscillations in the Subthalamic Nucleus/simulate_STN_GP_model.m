function simulate_STN_GP_model(healthy)

    if nargin < 1
        healthy = true;
    end

    % ============================================================
    % Parameters
    % ============================================================
    p.tauS = 6e-3;
    p.tauG = 14e-3;

    if healthy
        p.wGS = 1.12;
        p.wCS = 2.42;
        p.wSG = 19.0;
        p.wGG = 6.6;
        p.wXG = 15.1;
    else
        p.wGS = 10.7;
        p.wCS = 9.2;
        p.wSG = 20.0;
        p.wGG = 12.3;
        p.wXG = 139.4;
    end

    p.dGS = 6e-3;
    p.dSG = 6e-3;
    p.dGG = 4e-3;

    p.Ctx = @(t) 27;
    p.Str = @(t) 2;

    p.Ms = 300;
    p.Bs = 17;
    p.Mg = 400;
    p.Bg = 75;

    p.Fs_raw = @(u) p.Ms ./ ...
        (1 + exp(-4*u./p.Ms) .* ((p.Ms - p.Bs)/p.Bs));

    p.Fg_raw = @(u) p.Mg ./ ...
        (1 + exp(-4*u./p.Mg) .* ((p.Mg - p.Bg)/p.Bg));

    % ============================================================
    % Simulation setup
    % ============================================================
    IC_abs = [0; 0];   % original absolute initial condition
    tspan = [0 0.5];
    lags = [p.dGS, p.dSG, p.dGG];

    % ============================================================
    % Find true absolute equilibrium
    % ============================================================
    p = find_equilibrium(p, IC_abs);

    % Centered initial condition
    IC_ctr = IC_abs - [p.STN0; p.GP0];

    % ============================================================
    % Simulate uncentered absolute model
    % ============================================================
    sol_abs = dde23(@rhs_uncentered, lags, IC_abs, tspan);

    % ============================================================
    % Simulate centered deviation model
    % ============================================================
    sol_ctr = dde23(@rhs_centered, lags, IC_ctr, tspan);

    % ============================================================
    % Evaluate and compare
    % ============================================================
    t = linspace(tspan(1), tspan(2), 3000);

    y_abs = deval(sol_abs, t);
    y_ctr = deval(sol_ctr, t);

    y_ctr_abs = y_ctr + [p.STN0; p.GP0];

    err = y_abs - y_ctr_abs;

    fprintf('\nMaximum absolute reconstruction errors:\n');
    fprintf('  STN error = %.3e\n', max(abs(err(1,:))));
    fprintf('  GP  error = %.3e\n', max(abs(err(2,:))));

    % ============================================================
    % Plot absolute comparison
    % ============================================================
    figure;
    tiledlayout(2,1);

    nexttile;
    plot(t, y_abs(1,:), 'LineWidth', 1.5); hold on;
    plot(t, y_ctr_abs(1,:), '--', 'LineWidth', 1.5);
    grid on;
    ylabel('STN activity');
    legend('Uncentered', 'Centered reconstructed');
    title('STN: absolute dynamics');

    nexttile;
    plot(t, y_abs(2,:), 'LineWidth', 1.5); hold on;
    plot(t, y_ctr_abs(2,:), '--', 'LineWidth', 1.5);
    grid on;
    xlabel('Time');
    ylabel('GP activity');
    legend('Uncentered', 'Centered reconstructed');
    title('GP: absolute dynamics');

    % ============================================================
    % Plot centered variables
    % ============================================================
    figure;
    plot(t, y_ctr(1,:), 'LineWidth', 1.5); hold on;
    plot(t, y_ctr(2,:), 'LineWidth', 1.5);
    yline(0, '--');
    grid on;
    xlabel('Time');
    ylabel('Deviation from equilibrium');
    legend('STN - STN_0', 'GP - GP_0');
    title('Centered state variables');

    % ============================================================
    % Plot reconstruction error
    % ============================================================
    figure;
    semilogy(t, abs(err(1,:)) + eps, 'LineWidth', 1.5); hold on;
    semilogy(t, abs(err(2,:)) + eps, 'LineWidth', 1.5);
    grid on;
    xlabel('Time');
    ylabel('Absolute error');
    legend('STN error', 'GP error');
    title('Uncentered minus reconstructed centered');

    % ============================================================
    % Plot centered sigmoids
    % ============================================================
    plot_centered_sigmoids(p);


    % ============================================================
    % Nested functions
    % ============================================================

    function dydt = rhs_uncentered(t, y, Z)

        STN = y(1);
        GP  = y(2);

        GP_dGS  = Z(2,1);
        STN_dSG = Z(1,2);
        GP_dGG  = Z(2,3);

        uS = -p.wGS * GP_dGS + p.wCS * p.Ctx(t);

        uG =  p.wSG * STN_dSG ...
            - p.wGG * GP_dGG ...
            - p.wXG * p.Str(t);

        dSTN = (p.Fs_raw(uS) - STN) / p.tauS;
        dGP  = (p.Fg_raw(uG) - GP ) / p.tauG;

        dydt = [dSTN; dGP];

    end


    function dydt = rhs_centered(t, y, Z)

        % y(1) = STN - STN0
        % y(2) = GP  - GP0

        STN_ctr = y(1);
        GP_ctr  = y(2);

        GP_ctr_dGS  = Z(2,1);
        STN_ctr_dSG = Z(1,2);
        GP_ctr_dGG  = Z(2,3);

        % Reconstruct absolute delayed states before applying nonlinearities
        GP_abs_dGS  = GP_ctr_dGS  + p.GP0;
        STN_abs_dSG = STN_ctr_dSG + p.STN0;
        GP_abs_dGG  = GP_ctr_dGG  + p.GP0;

        uS = -p.wGS * GP_abs_dGS + p.wCS * p.Ctx(t);

        uG =  p.wSG * STN_abs_dSG ...
            - p.wGG * GP_abs_dGG ...
            - p.wXG * p.Str(t);

        dSTN_ctr = (p.Fs_raw(uS) - p.STN0 - STN_ctr) / p.tauS;
        dGP_ctr  = (p.Fg_raw(uG) - p.GP0  - GP_ctr ) / p.tauG;

        dydt = [dSTN_ctr; dGP_ctr];

    end


    function p_out = find_equilibrium(p_in, xguess)

        Ctx0 = p_in.Ctx(0);
        Str0 = p_in.Str(0);

        residual = @(x) [
            x(1) - p_in.Fs_raw(-p_in.wGS*x(2) + p_in.wCS*Ctx0);
            x(2) - p_in.Fg_raw( p_in.wSG*x(1) ...
                               - p_in.wGG*x(2) ...
                               - p_in.wXG*Str0)
        ];

        objective = @(x) sum(residual(x).^2);

        opts = optimset( ...
            'Display', 'off', ...
            'TolX', 1e-12, ...
            'TolFun', 1e-12, ...
            'MaxIter', 1e4, ...
            'MaxFunEvals', 1e4);

        [xstar, fval] = fminsearch(objective, xguess, opts);

        resnorm = sqrt(fval);

        p_out = p_in;

        p_out.STN0 = xstar(1);
        p_out.GP0  = xstar(2);

        p_out.uS0 = -p_out.wGS*p_out.GP0 + p_out.wCS*Ctx0;
        p_out.uG0 =  p_out.wSG*p_out.STN0 ...
                   - p_out.wGG*p_out.GP0 ...
                   - p_out.wXG*Str0;

        fprintf('\nEquilibrium used for centering:\n');
        fprintf('  STN0 = %.10f\n', p_out.STN0);
        fprintf('  GP0  = %.10f\n', p_out.GP0);
        fprintf('  uS0  = %.10f\n', p_out.uS0);
        fprintf('  uG0  = %.10f\n', p_out.uG0);
        fprintf('  residual norm = %.3e\n', resnorm);

        if resnorm > 1e-6
            warning('Equilibrium residual is not very small: %g', resnorm);
        end

    end


    function plot_centered_sigmoids(p_in)

        duS = linspace(-p_in.Ms, p_in.Ms, 1000);
        duG = linspace(-p_in.Mg, p_in.Mg, 1000);

        FS_ctr = p_in.Fs_raw(p_in.uS0 + duS) - p_in.STN0;
        FG_ctr = p_in.Fg_raw(p_in.uG0 + duG) - p_in.GP0;

        figure;
        tiledlayout(1,2);

        nexttile;
        plot(duS, FS_ctr, 'LineWidth', 1.5);
        hold on;
        xline(0, '--');
        yline(0, '--');
        grid on;
        xlabel('\Delta u_S = u_S - u_{S0}');
        ylabel('F_S(u_S) - STN_0');
        title('Centered STN sigmoid');

        nexttile;
        plot(duG, FG_ctr, 'LineWidth', 1.5);
        hold on;
        xline(0, '--');
        yline(0, '--');
        grid on;
        xlabel('\Delta u_G = u_G - u_{G0}');
        ylabel('F_G(u_G) - GP_0');
        title('Centered GP sigmoid');

    end

end