% [prog, Kval, gam_val, P, Z] = lpiscript(PIE,'hinf-controller','light');   
% PIE_CL = closedLoopPIE(PIE,Kval);

% =============================================
% === Simulate the system

% % Declare initial values and disturbance
syms st sx real
% % Set options for discretization and simulation
opts.plot = 'no';   % don't plot final solution
opts.N = 16;        % expand using 16 Chebyshev polynomials
opts.tf = 60;        % simulate up to t = 2
opts.dt = 1e-3;     % use time step of 10^-2

uinput.ic = 0;%sin(sx*pi/2);
w0  = 0.1;                            % initial rad/s
w1  = 10000;                             % final rad/s
T   = opts.tf;                             % sweep duration
tau = mod(st, T);

tsamp = opts.dt:opts.dt:opts.tf;
% wsamp = sin(w0*tsamp + ((w1-w0)/(2*T))*tsamp.^2);
Amax = 100;
l = opts.tf*(1/opts.dt);
P = 6;
N = l/P;
fs = 1/opts.dt;
[wsamp, f_fft, nf_pos] = multisine(l, P, opts.dt, Amax); 
% uinput.w = sin(w0*tau + ((w1-w0)/(2*T))*tau.^2);

uinput.w{1} = [tsamp;wsamp'];

% % Perform the actual simulation
[solution_CL,grid] = PIESIM(PIE_CL,opts,uinput);
tval = solution_CL.timedep.dtime;
x_CL = reshape(solution_CL.timedep.primary{2}(:,1,:),opts.N+1,[]);
wtilde = solution_CL.timedep.observed{1}(4,:);
u_CL = solution_CL.timedep.observed{1}(1,:);
w = solution_CL.timedep.observed{1}(2,:);
utilde = solution_CL.timedep.observed{1}(3,:);
wtilde = solution_CL.timedep.observed{1}(4,:);
%% 
L2_u = sqrt(trapz(tval, abs(utilde).^2));
L2_d = sqrt(trapz(tval, abs(wtilde).^2));
l2norm = L2_u/L2_d;
u = w;
y = u_CL;
skip = 2; %period(s)
index = skip*N+1:length(u);

u = u - mean(u);
y = y - mean(y);
up = reshape(u(index),[N,P-skip]);
yp = reshape(y(index),[N,P-skip]);

up_subtracted = up - up(:,end);
yp_subtracted = yp - yp(:,end);

figure;
subplot(2,1,1);
plot(tval(index), up_subtracted(:));
subplot(2,1,2);
plot(tval(index), yp_subtracted(:));


%% FFT-based estimates
% Assumption:
%   - rows = time samples
%   - columns = repeated periods / realizations

Up = fft(up, [], 1);
Yp = fft(yp, [], 1);

Up_pos = Up(1:nf_pos, :);
Yp_pos = Yp(1:nf_pos, :);
f_fft_pos = f_fft(1:nf_pos);
omega = 2*pi*f_fft_pos;

% % Average / variance across realizations (dimension 2)
% Up_pos_mean = mean(Up_pos, 2);
% Yp_pos_mean = mean(Yp_pos, 2);
% 
varU = var(Up_pos, 0, 2);
varY = var(Yp_pos, 0, 2);
% 
% % Avoid division by zero in FRF estimate
% G_est = nan(size(Yp_pos_mean));
% idx_den = abs(Up_pos_mean) > sqrt(eps);
% G_est(idx_den) = Yp_pos_mean(idx_den) ./ Up_pos_mean(idx_den);

Gk = Yp_pos ./ Up_pos;           % FRF per period
G_est = mean(Gk, 2, 'omitnan'); % average FRFs
thr = 1e-6*max(abs(Up_pos(:)));
Gk(abs(Up_pos) < thr) = NaN;
G_est = mean(Gk, 2, 'omitnan');
%% Plot FFT magnitudes + variances
figure('Color','w');

bx(1) = subplot(2,1,1);
plot(f_fft_pos, 20*log10(max(abs(Up_pos), eps)), 'LineWidth', 2); hold on
plot(f_fft_pos, 10*log10(max(varU, eps)), '*', 'LineWidth', 1);
grid on
title('Magnitude and Variance of $U_p$','Interpreter','latex')
xlabel('Frequency [Hz]','Interpreter','latex')
ylabel('Magnitude [dB]','Interpreter','latex')
ylim([-50 40])

bx(2) = subplot(2,1,2);
plot(f_fft_pos, 20*log10(max(abs(Yp_pos), eps)), 'LineWidth', 2); hold on
plot(f_fft_pos, 10*log10(max(varY, eps)), '*', 'LineWidth', 1);
grid on
title('Magnitude and Variance of $Y_p$','Interpreter','latex')
xlabel('Frequency [Hz]','Interpreter','latex')
ylabel('Magnitude [dB]','Interpreter','latex')

linkaxes(bx,'x')

%% 2.3 Welch / CPSD estimate
u = u(:);
y = y(:);
L = numel(u);

winLen   = floor(L/2);
win      = hamming(winLen);
noverlap = floor(winLen/2);
nfft     = L;   % keep your original choice

[Phi_uu, f] = pwelch(u, win, noverlap, nfft, fs);     % input PSD
[Phi_yy, ~] = pwelch(y, win, noverlap, nfft, fs);     % output PSD
[Phi_yu, ~] = cpsd(y, u, win, noverlap, nfft, fs);    % cross-PSD: y with u

G0_est = Phi_yu ./ max(Phi_uu, eps);
Phi_vv = Phi_yy - abs(G0_est).^2 .* Phi_uu;
Phi_vv = max(real(Phi_vv), 0);   % avoid tiny negative values from numerics

% Frequency responses of weights
resp   = gam*squeeze(freqresp((1/Wu)*(1/Wd), omega));
wdresp = squeeze(freqresp(Wd, omega));
wuresp = squeeze(freqresp(inv(Wu), omega));

magWuInv = abs(resp);

[coh,fcoh] = mscohere(u(:), y(:), hamming(N), N/2, N, fs);
omega_coh = 2*pi*fcoh;

figure('Color','w','Position',[50,50,1000,700]);
ax = gca;
semilogx(ax, omega, 20*log10(max(abs(G_est), eps)), ...
    'LineWidth', 2); hold(ax, 'on');
semilogx(ax, omega, 20*log10(max(magWuInv, eps)), '--', ...
    'LineWidth', 2);
semilogx(omega_coh, coh, 'LineWidth', 2);
grid on;
set(ax, 'FontSize', 20, 'LineWidth', 1.5)
ylabel(ax, 'Magnitude (dB)')
xlim(ax, [omega(1), omega(end)])
ylim(ax, [-10,2]);

