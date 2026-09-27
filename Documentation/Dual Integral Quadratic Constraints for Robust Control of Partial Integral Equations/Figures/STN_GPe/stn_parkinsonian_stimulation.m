%% Unforced Parkinsonian STN-GPe dynamics in the shifted states of Eq. (21)
% Run this script in MATLAB (no additional toolboxes needed).
% Implements Eq. (21), labelled eq:stn-gpe_ode-pde in the manuscript,
% by its equivalent delay equations: phi_ij(t,1) = x_i(t-delay_ij).
% x denotes deviation from the PARKINSONIAN equilibrium.
%
% Reference: Nevado Holgado et al., J Neurosci 30:12340-12352 (2010),
% DOI 10.1523/JNEUROSCI.0817-10.2010, Eqs. (3),(5), Tables 1 and 3.
% Parameters are fitted to animal data, not a patient-specific human model.
% The reference uses GPe; the companion diagram calls this node 'Proto'.
% Proto is a schematic stand-in, not a separately fitted cell population.
%
% No stimulation: u(t)=0 for the entire simulation.
% The existing filename is retained so earlier links point to this update.

clearvars;
outDir = fileparts(mfilename('fullpath'));

%% Simulation settings
duration_s = 0.4;
dt_s = 20e-6; % Halved below for a numerical convergence check.

%% Parkinsonian parameters (Tables 1 and 3, disease index K=1)
p.wSG = 20.0; p.wGS = 10.7; p.wGG = 12.3;
p.wCS = 9.2; p.wXG = 139.4;
p.tau = [6; 14]*1e-3;
p.delay = [6; 6; 4]*1e-3; % GS, SG, GG
p.M = [300; 400]; p.B = [17; 75]; % spikes/s
p.Ctx = 27; p.Str = 2; % spikes/s
p.history = [1;0]; % Small constant STN perturbation (spikes/s) seeds instability.

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
assert(max(abs(rhs([0;0],[0;0;0],p))) < 1e-12);

%% Simulate and verify
% Fixed-step RK4, method of steps, with interpolation of stored history.
% Starting exactly at an unstable equilibrium would hide its instability.
% A small constant initial history shows growth away from the origin.
[~,xc] = simulate(p,duration_s,dt_s);
[t,x] = simulate(p,duration_s,dt_s/2);
convergenceError = max(abs(x(:,1:2:end)-xc),[],'all');
assert(convergenceError < 0.05,'Time-step refinement error exceeds 0.05 spikes/s.');
tail = x(:,t > duration_s-0.1);
unforcedAmplitude = max(tail,[],2)-min(tail,[],2);
assert(all(unforcedAmplitude > 1),'Expected persistent unforced oscillations.');
atOrigin = p; atOrigin.history = [0;0];
[~,xOrigin] = simulate(atOrigin,duration_s,dt_s);
assert(max(abs(xOrigin),[],'all') < 1e-12,'The shifted origin must be an equilibrium.');
current_mA = zeros(size(t)); u = zeros(size(t));
rates = x+p.equilibrium;
assert(all(isfinite(rates),'all') && min(rates,[],'all') >= 0);

%% Plot only the equilibrium-shifted states (no stimulation)
blue = [23 74 128]/255; red = [230 55 62]/255;
fig = figure('Color','none','Position',[100 100 1150 500]);
ax = axes(fig);
plot(ax,t,x(1,:),'Color',blue,'LineWidth',1.7); hold(ax,'on');
plot(ax,t,x(2,:),'Color',red,'LineWidth',1.7);
yline(ax,0,':','Color',[.4 .4 .4],'HandleVisibility','off');
ylabel(ax,'spikes/s'); xlabel(ax,'t');
legend(ax,{'x_S (STN)','x_G (GPe / Proto)'},'Location','northwest','Box','off');
set(ax,'FontName','Arial','FontSize',14,'Box','off','TickDir','out','Color','none');
xlim(ax,[0 duration_s]);
exportgraphics(fig,fullfile(outDir,'stn_parkinsonian_stimulation.pdf'),'ContentType','vector','BackgroundColor','none');
% MATLAB's raster exporter does not preserve alpha; render the vector PDF.
% Requires Python with PyMuPDF, also used for the companion TikZ diagrams.
[status,message] = system(sprintf('python "%s" "%s"', ...
    fullfile(outDir,'render_stn_plot.py'),fullfile(outDir,'stn_parkinsonian_stimulation.pdf')));
assert(status == 0,'Transparent PNG export failed: %s',message);
savefig(fig,fullfile(outDir,'stn_parkinsonian_stimulation.fig'));
data = table(t',current_mA',rates(1,:)',rates(2,:)',x(1,:)',x(2,:)', ...
    'VariableNames',{'t_s','current_mA','STN_spikes_per_s','GPe_spikes_per_s', ...
    'xS_spikes_per_s','xG_spikes_per_s'});
writetable(data,fullfile(outDir,'stn_parkinsonian_stimulation.csv'));
save(fullfile(outDir,'stn_parkinsonian_stimulation.mat'), ...
    't','x','rates','current_mA','u','p','convergenceError','unforcedAmplitude');
fprintf('Parkinsonian equilibrium: STN %.6f, GPe %.6f spikes/s.\n',p.equilibrium);
fprintf('Peak rates: STN %.6f, GPe %.6f spikes/s.\n',max(rates,[],2));
fprintf('Refinement error: %.6g spikes/s.\n',convergenceError);
fprintf('Unforced peak-to-peak rates: STN %.6f, GPe %.6f spikes/s.\n',unforcedAmplitude);
fprintf('Saved simulation and plot to %s\n',outDir);

function f = activation(q,p)
f = p.M./(1+exp(-4*q./p.M).*(p.M-p.B)./p.B);
end

function [t,x] = simulate(p,T,h)
assert(abs(T/h-round(T/h)) < 1e-7,'End time must align with the grid.');
assert(h < min(p.delay),'Time step must be shorter than every delay.');
t = (0:round(T/h))*h;
x = zeros(2,numel(t));
x(:,1) = p.history;
lags = p.delay/h;
for k = 1:numel(t)-1
    k1 = rhs(x(:,k),delayed(x,k,0,lags,p.history),p);
    mid = delayed(x,k,0.5,lags,p.history);
    k2 = rhs(x(:,k)+h*k1/2,mid,p);
    k3 = rhs(x(:,k)+h*k2/2,mid,p);
    k4 = rhs(x(:,k)+h*k3,delayed(x,k,1,lags,p.history),p);
    x(:,k+1) = x(:,k)+h*(k1+2*k2+2*k3+k4)/6;
end
end

function v = delayed(x,k,c,lags,history)
% Ordered as G(t-delayGS), S(t-delaySG), G(t-delayGG).
rows = [2 1 2]; v = zeros(3,1);
for j = 1:3
    position = k+c-lags(j);
    if position > 1
        lo = floor(position); fraction = position-lo;
        v(j) = (1-fraction)*x(rows(j),lo)+fraction*x(rows(j),lo+1);
    else
        v(j) = history(rows(j));
    end
end
end

function dx = rhs(x,v,p)
z = [-p.wGS*v(1); p.wSG*v(2)-p.wGG*v(3)];
% Eq. (21): delta_i(v) = sigma_i(zStar_i+v)-sigma_i(zStar_i).
sigma = @(q) p.M/2.*tanh(2*q./p.M);
delta = sigma(p.zStar+z)-sigma(p.zStar);
dx = (delta-x)./p.tau; % u(t)=0
end
