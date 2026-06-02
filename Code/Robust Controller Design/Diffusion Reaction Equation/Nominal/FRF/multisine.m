% l - signal length
% P - # of periods
% dt - sampling time
% fc - cutoff frequency
% Amax - max amplitude
function [r, f_fft, nf_pos] = multisine(l, P, dt, Amax)
N = l/P; % signal length per period
fs = 1/dt; % sampling frequency of 1Hz
f0 = fs/N; % fundamental frequency of 1 period
fN = fs/2; % nyquist frequency
f_fft = (0:N-1)*(fs/N); % frequency spectrum for fft
if mod(N,2) == 0 % identify the frequency spectrum until the nyquist frequency
    nf_pos = N/2+1; % Even N: Include Nyquist frequency
else
    nf_pos = (N+1)/2; % Odd N: Exclude Nyquist frequency
end

freqs = f0:f0:fN;
freqs = freqs(1:end-1); % exclude nyquist frequency from spectrum

% phase = 2*pi*rand(1,length(freqs));
phase = -pi * (1:length(freqs)) .* ((1:length(freqs)) - 1) / length(freqs);

A = ones(1,length(freqs));
t = (0:N-1)/fs;

r = A*sin(2*pi*freqs'*t+phase');
r = (r / max(abs(r))) * Amax; % Normalize the signal to ensure no saturation occurs
r = repmat(r',[P,1]);
end
% 
% figure; plot(r);
% 
% r = r-mean(r);
% rp = reshape(r,[N,P]);
% 
% 
% Rp = fft(rp,[],1);
% Rp_pos = Rp(1:nf_pos,:);
% 
% f_fft_pos = f_fft(1:nf_pos);
% 
% mean_R = mean(rp,2);
% 
% varR = var(Rp_pos,[],2);
% 
% figure;
% plot(f_fft_pos,db(Rp_pos)); hold on; plot(f_fft_pos,db(varR,'power'),'*');
% grid on;
% title('Magnitude and Variance of $Rp$','Interpreter','latex')
% xlabel('frequency [Hz]','Interpreter','latex'); ylabel('Magnitude [dB]','Interpreter','latex');