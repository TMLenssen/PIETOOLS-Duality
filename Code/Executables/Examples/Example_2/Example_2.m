clear; clc; close all; clear stateNameGenerator
echo off

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
codeRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(codeRoot));

%% Plant
pvar t s
a = 0;
b = 1;
d = 1;
sigma = 3;
damp = 0.2;
alpha = 0;
beta = 1.217234;
hatalpha = 0;
hatbeta = 2;
useSlope = 1;
renderFigures = false;

%% Figure settings
plotSettings = example_2_plot_settings();
x = pde_var('state',1,[],[]);
v1 = pde_var(s,[a,b]);
v2 = pde_var(s,[a,b]);
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
u = pde_var('control',1);
PDE = [diff(v1,t) == v2;    % PDE
    diff(v2,t) == d*diff(v1,s,2) + sigma*v1 - damp*v2 - sigma*wd;
    diff(x,t) == u;
    zd == v1;
    subs(v1,s,a) == 0;
    subs(v2,s,a) == 0;
    subs(diff(v1,s),s,b)==x];
P = convert(PDE);

wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);

% Identity filters only establish the primal [z;w] and dual [w;z]
% channel order. They have no states.
Psi = id_filter(zDim,wDim,P.vars,P.dom);
DPsi = id_filter(wDim,zDim,P.vars,P.dom);

settings = lpisettings('veryheavy');
% settings.ddZ = 1;
% settings.dd1 = 2;
% settings.dd12 = 2;
% settings.dd2 = 6;
% settings.dd3 = 6;
settings.ddM = 3;
% settings.kmax = 10000;
settings.multiplierUpper = 1e6;
settings.inverseFloor =  1e-6;
settings.epneg = 1e-8;
% settings.kypMarginUpper = 1e+2;
settings.kypSlackMode = 'signed';

%% Dual synthesis with the selected multiplier
progS = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);

if useSlope
    [progS,Vd] = PIETOOLS_IQC_slope_dual(progS,wDim,zDim,hatalpha,hatbeta,settings,P.vars,P.dom);
else
    [progS,Vd] = PIETOOLS_IQC_sector(progS,wDim,zDim,alpha,beta,settings,P.vars,P.dom);
end
settings.options1.sep = 1;
settings.options12.sep = 1;
[K,~,~,progS,kypBound] = PIETOOLS_IQC_controller_synthesis(progS,settings,P,DPsi,Vd);

[sFR,sPinf,sDinf,sNumerr] = solve_info(progS);
synthKypBound = double(lpigetsol(progS,kypBound));

analysisSettings = settings;
% analysisSettings.options1.sep = 0;
% analysisSettings.options12.sep = 0;

%% Identity-filtered primal and dual closed-loop graphs
GP = PIETOOLS_IQC_primal_graph(P,Psi,K);
GD = PIETOOLS_IQC_dual_graph(P,DPsi,K);

%% Primal analysis with the selected multiplier
progP = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
if useSlope
    [progP,Vp] = PIETOOLS_IQC_slope(progP,zDim,wDim,hatalpha,hatbeta,analysisSettings,P.vars,P.dom);
else
    [progP,Vp] = PIETOOLS_IQC_sector(progP,zDim,wDim,alpha,beta,analysisSettings,P.vars,P.dom);
end
[~,progP,primalKypBound] = PIETOOLS_IQC_analysis( ...
    progP,analysisSettings,GP,Vp);
primalKypBound = double(lpigetsol(progP,primalKypBound));
[pFR,pPinf,pDinf,pNumerr] = solve_info(progP);

%% Dual analysis with the selected multiplier
progD = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
if useSlope
    [progD,Va] = PIETOOLS_IQC_slope_dual(progD,wDim,zDim,hatalpha,hatbeta,analysisSettings,P.vars,P.dom,'rhoD');
else
    [progD,Va] = PIETOOLS_IQC_sector(progD,wDim,zDim,alpha,beta,analysisSettings,P.vars,P.dom);
end

[~,progD,dualKypBound] = PIETOOLS_IQC_analysis(progD,analysisSettings,GD,Va);
dualKypBound = double(lpigetsol(progD,dualKypBound));
[dFR,dPinf,dDinf,dNumerr] = solve_info(progD);

%% Nonlinear closed-loop simulation

Psim = disturbed_simulation_plant(a,b,d,sigma,damp,t,s);
Nsim = 16;
Tsim = 35;
amp = 0;

wp = @(t) 8*cos(t).*(t >= pi).*(t <= 4*pi);

splot = linspace(0,1,200).';
boundaryState0 = 0;
z0 = @(s) amp*sin(pi*s/2);
zt0 = @(s) zeros(size(s));
wd = @(z) z-sin(z);

samp = 30000;
tgrid = linspace(0,Tsim,samp);
x0.ode = boundaryState0;
x0.pde = {zt0,z0};

simOpts.N = Nsim;
simOpts.splot = splot;
simOpts.statePIE = Psim;
simOpts.nwd0 = 0;
simOpts.wp = wp;
simOpts.ode = odeset('RelTol',1e-6,'AbsTol',1e-8);

simOL = PIE_sim_nl(Psim,wd,tgrid,x0,simOpts);
simCL = PIE_sim_nl(closedLoopPIE(Psim,K),wd,tgrid,x0,simOpts);

tsim = simOL.t;
disturbanceInput = simCL.wp(:,1);
disturbanceProfile = splot.*(1-splot);
zsimOL = simOL.zPlot-simOL.wp(:,1)*disturbanceProfile.';
zsimCL = simCL.zPlot-simCL.wp(:,1)*disturbanceProfile.';
controlEffort = simCL.outputFinite(:,1);
spatialAmpOpen = max(abs(zsimOL),[],2);
spatialAmpClosed = max(abs(zsimCL),[],2);
fprintf('Peak boundary control |x(t)|: %.10g\n',max(abs(controlEffort)));
fprintf('Final open-loop spatial amplitude: %.10g\n',spatialAmpOpen(end));
fprintf('Final closed-loop spatial amplitude: %.10g\n',spatialAmpClosed(end));

if renderFigures
    generate_pde_simulation_figures(paperFigureDir,splot,tsim,zsimOL,zsimCL, ...
        disturbanceInput,controlEffort,plotSettings);
    fprintf('Paper figures written to: %s\n',paperFigureDir);
end
paperFigureDir = fullfile(fileparts(codeRoot),'Documentation', ...
        'Robust_Control_of_PIE_Systems_using_IQC_based_on_Duality','Figures');


% %% Distributed pendulum video
% videoFile = fullfile(paperFigureDir,'example2_distributed_pendulum_CL.mp4');
% title = 'Closed-loop distributed pendulum';
% make_pendulum_video(tsim,splot,zsimCL,controlEffort,videoFile,title);
% fprintf('Pendulum video written to: %s\n',videoFile);
% OLcontolEffort = zeros(samp,1);
% title = 'Open-loop distributed pendulum';
% videoFile = fullfile(paperFigureDir,'example2_distributed_pendulum_OL.mp4');
% make_pendulum_video(tsim,splot,zsimOL,OLcontolEffort,videoFile,title);
% fprintf('Pendulum video written to: %s\n',videoFile);

fprintf('\nSynthesis feasibility ratio: %.10g\n',sFR);
fprintf('Synthesis status:             pinf=%g, dinf=%g, numerr=%g\n',sPinf,sDinf,sNumerr);
fprintf('Synthesis KYP bound:          %.10g\n',synthKypBound);

fprintf('\nPrimal analysis feasibility ratio: %.10g\n',pFR);
fprintf('Primal analysis status:           pinf=%g, dinf=%g, numerr=%g\n',pPinf,pDinf,pNumerr);
fprintf('Primal analysis KYP bound:        %.10g\n',primalKypBound);
fprintf('Dual analysis feasibility ratio:   %.10g\n',dFR);
fprintf('Dual analysis status:             pinf=%g, dinf=%g, numerr=%g\n',dPinf,dDinf,dNumerr);
fprintf('Dual analysis KYP bound:          %.10g\n',dualKypBound);

function Psim = disturbed_simulation_plant(a,b,d,sigma,damp,t,s)
x = pde_var('state',1,[],[]);
v1 = pde_var(s,[a,b]);
v2 = pde_var(s,[a,b]);
zd = pde_var('output',1,s,[a,b]);
wd = pde_var('input',1,s,[a,b]);
zp = pde_var('output',1);
wp = pde_var('input',1);
u = pde_var('control',1);

PDE = [diff(v1,t) == v2;
    diff(v2,t) == d*diff(v1,s,2) + sigma*v1 - damp*v2 - sigma*wd;
    diff(x,t) == u;
    zd == v1 + s*(1-s)*wp;
    zp == x;
    subs(v1,s,a) == 0;
    subs(v2,s,a) == 0;
    subs(diff(v1,s),s,b) == x];
Psim = convert(PDE);
end

function F = id_filter(d1,d2,vars,dom)
d0 = zeros(size(d1));
F.T = zerosPI(d0,d0,vars,dom);
F.A = zerosPI(d0,d0,vars,dom);
F.B1 = zerosPI(d0,d1,vars,dom);
F.B2 = zerosPI(d0,d2,vars,dom);
F.C1 = zerosPI(d1,d0,vars,dom);
F.C2 = zerosPI(d2,d0,vars,dom);
F.D11 = eyePI(d1,vars,dom);
F.D12 = zerosPI(d1,d2,vars,dom);
F.D21 = zerosPI(d2,d1,vars,dom);
F.D22 = eyePI(d2,vars,dom);
end

function [ratio,pinf,dinf,numerr] = solve_info(prog)
info = prog.solinfo.info;
ratio = double(info.feasratio);
pinf = double(info.pinf);
dinf = double(info.dinf);
numerr = double(info.numerr);
end

function make_pendulum_video(t,s,q,xBoundary,filename,titleName)
% Animate the PIESIM state q(t,s) as a distributed pendulum array.
% q = 0 is upright; neighboring bobs are connected to show spatial coupling.

fps = 30;
Npend = min(35,numel(s));
rodLength = 0.12;
bobSize = 28;

t = t(:);
s = s(:);

if size(q,1) ~= numel(t) && size(q,2) == numel(t)
    q = q.';
end
if size(q,1) ~= numel(t) || size(q,2) ~= numel(s)
    error('q must have size length(t)-by-length(s).');
end

xBoundary = xBoundary(:);
if numel(xBoundary) ~= numel(t)
    error('xBoundary must have the same number of samples as t.');
end

% Spatial and temporal downsampling for the video.
idx = unique(round(linspace(1,numel(s),Npend)));
sDraw = s(idx);
qDraw = q(:,idx);

tVideo = (t(1):1/fps:t(end)).';
if tVideo(end) < t(end)
    tVideo(end+1,1) = t(end);
end

qVideo = interp1(t,qDraw,tVideo,'linear');
xVideo = interp1(t,xBoundary,tVideo,'linear');

% Fixed pivot positions.
xp = (sDraw-sDraw(1))/(sDraw(end)-sDraw(1));

fig = figure('Color','w','Position',[100 100 1100 500]);
ax = axes(fig);
hold(ax,'on');
axis(ax,'equal');
box(ax,'on');

xlim(ax,[-0.08 1.08]);
ylim(ax,[-1.25*rodLength 1.35*rodLength]);
xlabel(ax,'$s$','Interpreter','latex');
yticks(ax,[]);
title(ax,titleName, ...
    'Interpreter','latex');

% Support and pivots.
plot(ax,[0 1],[0 0],'k-','LineWidth',0.8);
plot(ax,xp,zeros(size(xp)),'k.','MarkerSize',8);

% Pendulum rods and bobs.
rods = gobjects(Npend,1);
for k = 1:Npend
    rods(k) = plot(ax,[xp(k) xp(k)],[0 rodLength], ...
        'k-','LineWidth',1.1);
end

bobs = scatter(ax,xp,rodLength*ones(size(xp)),bobSize, ...
    'filled','MarkerFaceColor',[0.10 0.45 0.85], ...
    'MarkerEdgeColor','k');

% Springs between neighboring bobs.
springs = gobjects(Npend-1,1);
for k = 1:Npend-1
    springs(k) = plot(ax,nan,nan,'k-','LineWidth',0.7);
end

text(ax,0,-0.055,'$q(0,t)=0$', ...
    'Interpreter','latex','HorizontalAlignment','left');
text(ax,1,-0.055,'$q_s(1,t)=x(t)$', ...
    'Interpreter','latex','HorizontalAlignment','right');

timeText = text(ax,0.02,0.95,'','Units','normalized', ...
    'Interpreter','latex','FontSize',11);
boundaryText = text(ax,0.98,0.95,'','Units','normalized', ...
    'Interpreter','latex','FontSize',11, ...
    'HorizontalAlignment','right');

vid = VideoWriter(filename,'MPEG-4');
vid.FrameRate = fps;
vid.Quality = 95;
open(vid);

for j = 1:numel(tVideo)
    theta = qVideo(j,:).';

    % q = 0 is the upright equilibrium.
    xb = xp + rodLength*sin(theta);
    yb = rodLength*cos(theta);

    for k = 1:Npend
        set(rods(k),'XData',[xp(k) xb(k)],'YData',[0 yb(k)]);
    end
    set(bobs,'XData',xb,'YData',yb);

    % Draw a small sinusoidal spring between adjacent bobs.
    for k = 1:Npend-1
        xa = xb(k);   ya = yb(k);
        xc = xb(k+1); yc = yb(k+1);

        xx = linspace(xa,xc,12);
        yy = linspace(ya,yc,12);

        ell = hypot(xc-xa,yc-ya);
        if ell > 0
            nx = -(yc-ya)/ell;
            ny =  (xc-xa)/ell;
            wiggle = 0.0035*sin(linspace(0,6*pi,12));
            xx = xx + nx*wiggle;
            yy = yy + ny*wiggle;
        end

        set(springs(k),'XData',xx,'YData',yy);
    end

    set(timeText,'String',sprintf('$t=%.2f$',tVideo(j)));
    set(boundaryText,'String',sprintf('$x(t)=%.3f$',xVideo(j)));

    drawnow;
    writeVideo(vid,getframe(fig));
end

close(vid);
close(fig);
end
