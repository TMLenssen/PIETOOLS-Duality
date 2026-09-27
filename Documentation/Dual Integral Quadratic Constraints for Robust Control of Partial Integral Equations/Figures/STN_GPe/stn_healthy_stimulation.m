%% Healthy STN-GPe response to a current pulse train
% Run this script in MATLAB (no additional toolboxes needed).
% Implements Eq. (21), labelled eq:stn-gpe_ode-pde in the manuscript,
% by its equivalent delay equations: phi_ij(t,1) = x_i(t-delay_ij).
% x denotes deviation from the HEALTHY equilibrium, not from the diseased one.
%
% Reference: Nevado Holgado et al., J Neurosci 30:12340-12352 (2010),
% DOI 10.1523/JNEUROSCI.0817-10.2010, Eqs. (3),(5), Tables 1 and 3.
% Parameters are fitted to animal data, not a patient-specific human model.
% The reference uses GPe; the companion diagram calls this node 'Proto'.
% Proto is a schematic stand-in, not a separately fitted cell population.
%
% Ten pulses at 100 Hz follow the burst structure described in the paper.
% The 0.2 mA amplitude and 0.3 ms width are illustrative choices, NOT a
% claim to reproduce the experimental waveform or a clinical prescription.
% The reference injects u = Stim*I_e OUTSIDE the sigmoid, into tauS*xdotS.
% A positive rectangular effective pulse is used, as in that model; it is
% not a biophysical electrode/tissue or charge-balanced waveform model.

clearvars;
outDir = fileparts(mfilename('fullpath'));

%% Editable stimulation settings (seconds, mA, pulses/second)
stim.amplitude_mA = 0.2;
stim.frequency_Hz = 100;
stim.width_s = 0.3e-3;
stim.count = 10;
stim.start_s = 0.1;
duration_s = 0.4;
dt_s = 20e-6; % Halved below for a numerical convergence check.

%% Healthy parameters (Tables 1 and 3)
p.wSG = 19.0; p.wGS = 1.12; p.wGG = 6.60;
p.wCS = 2.42; p.wXG = 15.1;
p.tau = [6; 14]*1e-3;
p.delay = [6; 6; 4]*1e-3; % GS, SG, GG
p.M = [300; 400]; p.B = [17; 75]; % spikes/s
p.Ctx = 27; p.Str = 2; % spikes/s
p.Stim = 4.6e3; % (spikes/s)/mA, healthy fitted conversion in Table 3

% Reduce the two equilibrium equations to a bracketed scalar root.
FS = @(q) p.M(1)./(1+exp(-4*q/p.M(1))*(p.M(1)-p.B(1))/p.B(1));
FG = @(q) p.M(2)./(1+exp(-4*q/p.M(2))*(p.M(2)-p.B(2))/p.B(2));
SofG = @(g) FS(-p.wGS*g+p.wCS*p.Ctx);
gStar = fzero(@(g) FG(p.wSG*SofG(g)-p.wGG*g-p.wXG*p.Str)-g,[0 p.M(2)]);
p.equilibrium = [SofG(gStar); gStar];
p.qStar = [-p.wGS*gStar+p.wCS*p.Ctx; ...
    p.wSG*p.equilibrium(1)-p.wGG*gStar-p.wXG*p.Str];
assert(max(abs(activation(p.qStar,p)-p.equilibrium)) < 1e-9);
p.c = p.M/4.*log((p.M-p.B)./p.B);
p.zStar = p.qStar-p.c; % Centered sigmoid input at equilibrium.
assert(max(abs(rhs([0;0],[0;0;0],0,p))) < 1e-12);

%% Simulate and verify
% Fixed-step RK4, method of steps, with interpolation of stored history.
% Every pulse edge is on the grid; each step uses its interval's constant
% current at all four RK stages. Narrow pulses are therefore never skipped.
% The history x(t)=0 for t<=0 represents a resting healthy network.
[tc,xc] = simulate(p,stim,duration_s,dt_s);
[t,x,current_mA] = simulate(p,stim,duration_s,dt_s/2);
convergenceError = max(abs(x(:,1:2:end)-xc),[],'all');
assert(convergenceError < 0.05,'Time-step refinement error exceeds 0.05 spikes/s.');
noStim = stim; noStim.amplitude_mA = 0;
[~,xRest] = simulate(p,noStim,duration_s,dt_s);
assert(max(abs(xRest),[],'all') < 1e-8,'Unforced equilibrium drifted.');
rates = x+p.equilibrium;
assert(all(isfinite(rates),'all') && min(rates,[],'all') >= 0);
assert(max(abs(x(:,end))) < 0.1,'Extend the recovery window.');
assert(sum(diff([0 current_mA>0])==1) == stim.count);
assert(abs(sum(current_mA)*(dt_s/2)- ...
    stim.amplitude_mA*stim.count*stim.width_s) < 1e-12);

%% Plot the actual current and the equilibrium-shifted states in Eq. (21)
blue = [23 74 128]/255; red = [230 55 62]/255;
fig = figure('Color','none','Position',[100 100 1150 700]);
layout = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
ax1 = nexttile(layout);
stairs(ax1,t,current_mA,'Color',blue,'LineWidth',1.25);
ylabel(ax1,'Current (mA)');
ylim(ax1,[-0.02 1.25*stim.amplitude_mA]);
ax2 = nexttile(layout);
plot(ax2,t,x(1,:),'Color',blue,'LineWidth',1.7); hold(ax2,'on');
plot(ax2,t,x(2,:),'Color',red,'LineWidth',1.7);
yline(ax2,0,':','Color',[.4 .4 .4],'HandleVisibility','off');
ylabel(ax2,'spikes/s'); xlabel(ax2,'t');
legend(ax2,{'x_S (STN)','x_G (GPe / Proto)'},'Location','northeast','Box','off');
for ax = [ax1 ax2]
    set(ax,'FontName','Arial','FontSize',14,'Box','off','TickDir','out','Color','none');
    xlim(ax,[0 duration_s]);
end
linkaxes([ax1 ax2],'x');
exportgraphics(fig,fullfile(outDir,'stn_healthy_stimulation.pdf'),'ContentType','vector','BackgroundColor','none');
% MATLAB's raster exporter does not preserve alpha; render the vector PDF.
% Requires Python with PyMuPDF, also used for the companion TikZ diagrams.
[status,message] = system(sprintf('python "%s" "%s"', ...
    fullfile(outDir,'render_stn_plot.py'),fullfile(outDir,'stn_healthy_stimulation.pdf')));
assert(status == 0,'Transparent PNG export failed: %s',message);
savefig(fig,fullfile(outDir,'stn_healthy_stimulation.fig'));
data = table(t',current_mA',rates(1,:)',rates(2,:)',x(1,:)',x(2,:)', ...
    'VariableNames',{'t_s','current_mA','STN_spikes_per_s','GPe_spikes_per_s', ...
    'xS_spikes_per_s','xG_spikes_per_s'});
writetable(data,fullfile(outDir,'stn_healthy_stimulation.csv'));
save(fullfile(outDir,'stn_healthy_stimulation.mat'), ...
    't','x','rates','current_mA','p','stim','convergenceError');
fprintf('Healthy equilibrium: STN %.6f, GPe %.6f spikes/s.\n',p.equilibrium);
fprintf('Peak rates: STN %.6f, GPe %.6f spikes/s.\n',max(rates,[],2));
fprintf('Refinement error: %.6g spikes/s; recovery error: %.6g spikes/s.\n', ...
    convergenceError,max(abs(x(:,end))));
fprintf('Saved simulation and plot to %s\n',outDir);
stn_healthy_input_spikes; % Also export the same plot with u(t) in spikes/s.

function f = activation(q,p)
f = p.M./(1+exp(-4*q./p.M).*(p.M-p.B)./p.B);
end

function [t,x,current] = simulate(p,stim,T,h)
assert(stim.frequency_Hz > 0 && stim.width_s > 0 && ...
    stim.width_s < 1/stim.frequency_Hz);
assert(stim.count >= 1 && stim.count == round(stim.count));
assert(stim.amplitude_mA >= 0 && stim.start_s >= 0);
starts = stim.start_s+(0:stim.count-1)/stim.frequency_Hz;
assert(starts(end)+stim.width_s < T);
gridTimes = [T starts starts+stim.width_s];
assert(max(abs(gridTimes/h-round(gridTimes/h))) < 1e-7, ...
    'Choose a time step that aligns with every pulse edge and the end time.');
assert(h < min(p.delay),'Time step must be shorter than every delay.');
t = (0:round(T/h))*h;
x = zeros(2,numel(t)); current = zeros(size(t));
for start = starts
    first = round(start/h)+1; last = round((start+stim.width_s)/h);
    current(first:last) = stim.amplitude_mA;
end
lags = p.delay/h;
for k = 1:numel(t)-1
    u = p.Stim*current(k);
    k1 = rhs(x(:,k),delayed(x,k,0,lags),u,p);
    mid = delayed(x,k,0.5,lags);
    k2 = rhs(x(:,k)+h*k1/2,mid,u,p);
    k3 = rhs(x(:,k)+h*k2/2,mid,u,p);
    k4 = rhs(x(:,k)+h*k3,delayed(x,k,1,lags),u,p);
    x(:,k+1) = x(:,k)+h*(k1+2*k2+2*k3+k4)/6;
end
end

function v = delayed(x,k,c,lags)
% Ordered as G(t-delayGS), S(t-delaySG), G(t-delayGG).
rows = [2 1 2]; v = zeros(3,1);
for j = 1:3
    position = k+c-lags(j);
    if position > 1
        lo = floor(position); fraction = position-lo;
        v(j) = (1-fraction)*x(rows(j),lo)+fraction*x(rows(j),lo+1);
    end
end
end

function dx = rhs(x,v,u,p)
z = [-p.wGS*v(1); p.wSG*v(2)-p.wGG*v(3)];
% Eq. (21): delta_i(v) = sigma_i(zStar_i+v)-sigma_i(zStar_i).
sigma = @(q) p.M/2.*tanh(2*q./p.M);
delta = sigma(p.zStar+z)-sigma(p.zStar);
dx = (delta-x+[u;0])./p.tau;
end
