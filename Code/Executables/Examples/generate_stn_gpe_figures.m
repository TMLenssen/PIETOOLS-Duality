function generate_stn_gpe_figures(mode)
% Reproduce the paper's STN--GPe figures from sector-only stability synthesis.
% Run 'synthesize', then 'simulate' for a spatial convergence check.
% Use 'plot' for both figures, 'plot-admissible' for Figure 9, or
% 'plot-trajectories' for Figure 10.
% 'simulate-unshifted' integrates the original firing-rate equations and
% verifies the coordinate transformation and spatial convergence.
if nargin == 0, mode = 'plot'; end
examplesRoot = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(fileparts(fileparts(examplesRoot)));
paperRoot = fullfile(repositoryRoot,'Documentation', ...
    'Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations');
figureRoot = fullfile(paperRoot, 'Figures');
codeRoot = fullfile(paperRoot,'..','..','Code');
exampleRoot = fullfile(codeRoot,'Executables','Examples','Example_4');
addpath(exampleRoot);
cacheFile = fullfile(examplesRoot,'stn_gpe_sector_simulation.mat');
if strcmp(mode,'synthesize')
    % Run a workspace-local copy, preserving the original solver settings,
    % plant, controller synthesis, and nonlinear simulation implementation.
    sourceFile = fullfile(exampleRoot,'Example_4_synthesis.m');
    source = fileread(sourceFile);
    source = strrep(source,'clear; clc; close all; clear stateNameGenerator', ...
        'function Results = run_stn_sector_source');
    source = strrep(source, ...
        'codeRoot = fileparts(fileparts(fileparts(fileparts(mfilename(''fullpath'')))));', ...
        sprintf('codeRoot = ''%s'';',strrep(codeRoot,'''','''''')));
    source = strrep(source,'plotSimulation = true;','plotSimulation = false;');
    source = regexprep(source,'lambdaSector = [01];','lambdaSector = 1;');
    source = regexprep(source,'lambdaZF = [01];','lambdaZF = 0;');
    source = strrep(source,'simulationInitialState = [1;-1];', ...
        'simulationInitialState = [0;0];');
    % Add d after Delta: w = Delta(z)+d, only in the simulated interconnection.
    source = strrep(source,'sim = PIE_sim_nl(P,delta,tgrid,x0,opts);', ...
        'sim = PIE_sim_nl(add_feedback_disturbance(P),delta,tgrid,x0,opts);');
    source = strrep(source,'sim = PIE_sim_nl(G,delta,tgrid,x0,opts);', ...
        'sim = PIE_sim_nl(add_feedback_disturbance(G),delta,tgrid,x0,opts);');
    source = strrep(source,'opts.nwd0 = 2;',sprintf([ ...
        'opts.nwd0 = 2;\n' ...
        'opts.wp = @(t) [10;-10]*(sin(pi*(t-0.10)/0.04)^2)*(t>=0.10 && t<=0.14);']));
    source = strrep(source,'''AbsTol'',1e-9)', ...
        '''AbsTol'',1e-9,''MaxStep'',5e-4)');
    source = [source,newline, sprintf([ ...
        'function G = add_feedback_disturbance(G)\n' ...
        'G.B1 = block_hcat(G.B1,G.B1,G.vars,G.dom);\n' ...
        'G.D11 = block_hcat(G.D11,G.D11,G.vars,G.dom);\n' ...
        'G.Tw = block_hcat(G.Tw,G.Tw,G.vars,G.dom);\n' ...
        'G.D21 = block_hcat(G.D21,G.D21,G.vars,G.dom);\n' ...
        'end\n'])];
    source = strrep(source,'function result = analyze_closed_loop_stability', ...
        sprintf('end\n\nfunction result = analyze_closed_loop_stability'));
    runRoot = fullfile(paperRoot,'build','stn_sector');
    if ~isfolder(runRoot), mkdir(runRoot); end
    fid = fopen(fullfile(runRoot,'run_stn_sector_source.m'),'w');
    assert(fid>=0); fwrite(fid,source); fclose(fid);
    addpath(runRoot);
    oldDirectory = pwd;
    restoreDirectory = onCleanup(@() cd(oldDirectory));
    cd(runRoot);
    Results = run_stn_sector_source();
    provenance = struct('sourceFile',sourceFile,'sourceText',fileread(sourceFile), ...
        'lambdaSector',1,'lambdaZF',0,'objective','robust stability', ...
        'initialHistory',[0;0],'spatialOrder',24, ...
        'controlScaleToPaper',6e-3*4.6e3, ...
        'disturbanceLocation','w = Delta(z) + d', ...
        'disturbanceInterval',[0.10 0.14],'disturbanceAmplitude',[10;-10]);
    assert(Results.synthesis.feasible,'Sector synthesis failed.');
    save(cacheFile,'Results','provenance','-v7.3');
    save(fullfile(examplesRoot,'stn_gpe_sector_controller.mat'), ...
        'Results','provenance','-v7.3');
end
if strcmp(mode,'simulate-unshifted')
    addpath(genpath('C:\Program Files\MATLAB\PIETOOLS\PIETOOLS'));
    addpath(genpath(codeRoot));
    data = load(fullfile(examplesRoot,'stn_gpe_sector_controller.mat'));
    assert(data.provenance.lambdaSector==1 && data.provenance.lambdaZF==0);
    assert(size(data.Results.K.P,2)==2,'Expected a sector-only controller.');
    data.Results = simulate_unshifted(data.Results,data.provenance);
    data.provenance.coordinates = 'original firing rates and sigmoid inputs';
    data.provenance.initialHistory = [data.Results.parameters.xS0;data.Results.parameters.xG0];
    data.provenance.initialHistoryCoordinates = 'absolute firing rates';
    data.provenance.spatialOrder = 32;
    Results=data.Results; provenance=data.provenance;
    save(fullfile(examplesRoot,'stn_gpe_unshifted_simulation.mat'), ...
        'Results','provenance','-v7.3');
    plot_trajectories(Results,provenance,figureRoot);
    return
end
if ~strcmp(mode,'plot-trajectories')
    plot_admissible(figureRoot);
end
if strcmp(mode,'plot-admissible'), return; end
if ~isfile(cacheFile)
    fprintf('Admissibility figure exported; run with ''synthesize'' for trajectories.\n');
    return
end
addpath(genpath('C:\Program Files\MATLAB\PIETOOLS\PIETOOLS'));
data = load(cacheFile,'Results','provenance');
if strcmp(mode,'simulate')
    data = load(fullfile(examplesRoot,'stn_gpe_sector_controller.mat'), ...
        'Results','provenance');
end
assert(data.provenance.lambdaSector==1 && data.provenance.lambdaZF==0);
if strcmp(mode,'simulate')
    addpath(genpath('C:\Program Files\MATLAB\PIETOOLS\PIETOOLS'));
    addpath(genpath(codeRoot));
    data.provenance.disturbanceAmplitude = [10;-10];
    data.provenance.initialHistory = [0;0];
    data.provenance.coordinates = 'equilibrium deviations';
    data.provenance.initialHistoryCoordinates = 'equilibrium deviations';
    data.Results = simulate_saved(data.Results,data.provenance);
    data.provenance.spatialOrder = 32;
    Results = data.Results; provenance = data.provenance;
    save(cacheFile,'Results','provenance','-v7.3');
end
plot_trajectories(data.Results,data.provenance,figureRoot);
end

function R = simulate_saved(R,provenance)
p = R.parameters;
delta = @(z) [p.MS/2*(tanh(2*(p.tildeZSStar+z(1))/p.MS)-tanh(2*p.tildeZSStar/p.MS)); ...
    p.MG/2*(tanh(2*(p.tildeZGStar+z(2))/p.MG)-tanh(2*p.tildeZGStar/p.MG))];
for field = {'simOpen','simClosed'}
    name = field{1};
    G = unscaled_simulation_plant(R.synthesis.P,R.K,strcmp(name,'simClosed'));
    x0.ode = [provenance.initialHistory;zeros(G.T.dim(1,2)-2,1)];
    x0.pde = {provenance.initialHistory(2),provenance.initialHistory(1), ...
        provenance.initialHistory(2)};
    opts.nwd0 = 2; opts.splot = linspace(0,1,151).';
    opts.wp = @(t) provenance.disturbanceAmplitude* ...
        sin(pi*(t-0.10)/0.04)^2*(t>=0.10 && t<=0.14);
    opts.ode = odeset('RelTol',1e-8,'AbsTol',1e-10,'MaxStep',2.5e-4);
    for order = [24 32]
        opts.N = order;
        sim = PIE_sim_nl(G,delta,R.(name).t,x0,opts);
        primary = sim.Dop.Tcheb_2PDEstate*sim.x.';
        sim.xS = primary(1,:).'; sim.xG = primary(2,:).';
        sim.zDelta = sim.zFinite(:,1:2);
        if strcmp(name,'simClosed'), sim.u = sim.outputFinite(:,3:end); end
        signals = [sim.xS sim.xG sim.outputFinite];
        if order==24
            baseSignals = signals;
        else
            relativeError = max(abs(signals-baseSignals),[],1)./ ...
                max(1,max(abs(signals),[],1));
            fprintf('%s N=24/32 relative differences: ',name);
            fprintf('%.3g ',relativeError); fprintf('\n');
            assert(max(relativeError)<1e-3,'Spatial convergence check failed.');
            R.validation.(name) = relativeError;
        end
    end
    R.(name) = sim;
end
end

function plot_admissible(figureRoot)
alphaSector = 0.492;
alphaSlope = 0.562;
Kd = 1;
[sectorLimit,~] = stn_gpe_admissible_trajectories(alphaSector,1);
[~,slopeLimit] = stn_gpe_admissible_trajectories(alphaSlope,1);
[~,zStar,~,p] = stn_gpe_equilibrium(Kd);
M = [p.MS,p.MG];
symbols = {'S','G'};
names = {'STN','GPe'};
blue = [0.08 0.40 0.72]; orange = [0.85 0.32 0.13];
sectorFill = [0.74 0.87 0.80]; bothFill = [0.74 0.87 0.80]-0.1;
fig = new_figure([7.0 3.45]);
for i = 1:2
    ax = axes(fig,'Position',[0.115+(i-1)*0.505,0.19,0.35,0.54]);
    hold(ax,'on');
    zMin = -0.3*sectorLimit(i); zMax = 2.4*sectorLimit(i);
    z = sort(unique([linspace(zMin,zMax,1600),0]));
    delta = M(i)/2*(tanh(2*(zStar(i)+z)/M(i))-tanh(2*zStar(i)/M(i)));
    quotient = delta./z;
    quotient(z==0) = sech(2*zStar(i)/M(i))^2;
    slope = sech(2*(zStar(i)+z)/M(i)).^2;
    hs = patch(ax,[zMin sectorLimit(i) sectorLimit(i) zMin], ...
        [0 0 1.03 1.03],sectorFill,'EdgeColor','none');
    hb = patch(ax,[zMin min(sectorLimit(i),slopeLimit(i))*[1 1] zMin], ...
        [0 0 1.03 1.03],bothFill,'EdgeColor','none');
    hq = plot(ax,z,quotient,'Color',blue,'LineWidth',1.6);
    hd = plot(ax,z,slope,'Color',orange,'LineWidth',1.6);
    yline(ax,alphaSector,'--','Color',blue,'LineWidth',0.9,'HandleVisibility','off');
    yline(ax,alphaSlope,'--','Color',orange,'LineWidth',0.9,'HandleVisibility','off');
    xlim(ax,[zMin zMax]); ylim(ax,[0 1.03]); ax.YTick = 0:0.25:1;
    xlabel(ax,sprintf('$z_{\\mathrm{%s}}$',symbols{i}),'Interpreter','latex');
    ylabel(ax,'$\alpha$','Interpreter','latex');
    title(ax,names{i},'FontWeight','normal','Interpreter','latex'); style_axes(ax,14);
    % Mark the exact right endpoints of the admissible intervals.
    drawnow;
    bounds = [slopeLimit(i),sectorLimit(i)];
    baseTicks = ax.XTick;
    gap = 0.12*(zMax-zMin);
    baseTicks(any(abs(baseTicks(:)-bounds)<gap,2)) = [];
    ticks = sort(unique([baseTicks(:);0;bounds(:)]));
    tickLabels = arrayfun(@(v)sprintf('$%g$',v),ticks,'UniformOutput',false);
    [~,slopeIndex] = min(abs(ticks-slopeLimit(i)));
    [~,sectorIndex] = min(abs(ticks-sectorLimit(i)));
    tickLabels{slopeIndex} = sprintf('$%.3g$',slopeLimit(i));
    tickLabels{sectorIndex} = sprintf('$%.3g$',sectorLimit(i));
    set(ax,'XTick',ticks,'XTickLabel',tickLabels,'XTickLabelRotation',0);
    ax.XRuler.FontSize = 11;
    if i==1, legendAxes = ax; handles = [hq hd hs hb]; end
end
lg = legend(legendAxes,handles, ...
    {'$\delta_i(z_i)/z_i\quad$','$\delta_i''(z_i)$','Sector bound','Both bounds'}, ...
    'Interpreter','latex','NumColumns',2,'Box','off','FontSize',14);
lg.Units = 'normalized'; lg.Position = [0.24 0.81 0.55 0.16];
export_pdf(fig,fullfile(figureRoot,'stn_gpe_admissible_trajectories.pdf'));
fprintf('Admissible sector limits (alpha=0.492): %.9g %.9g\n',sectorLimit);
fprintf('Admissible slope limits (alpha=0.562): %.9g %.9g\n',slopeLimit);
end

function plot_trajectories(R,provenance,figureRoot)
closed = R.simClosed; open = R.simOpen;
alpha = R.synthesis.betaBar;
[limits,~] = stn_gpe_admissible_trajectories(alpha,R.Kd);
originalCoordinates = isfield(provenance,'coordinates') && ...
    strcmp(provenance.coordinates,'original firing rates and sigmoid inputs');
if originalCoordinates
    limits = limits+[R.parameters.uS0,R.parameters.uG0];
end
% The synthesis plant uses xS_dot = ... + 4600*u_code; the paper uses
% tauS*xS_dot = ... + u. Plot u_paper = tauS*4600*u_code.
u = provenance.controlScaleToPaper*closed.u;
assert(all(isfinite([closed.xS;closed.xG;closed.zDelta(:);u(:)])));
maxZ = max(closed.zDelta,[],1);
% assert(all(maxZ<=limits),'Simulated inputs exceed the sector intervals.');
% Keep the original styling, with readable text at single-column width.
blue = [0.08 0.40 0.72];
fig = new_figure([7.0 6.6]);
positions = [0.125 0.70 0.335 0.21;0.625 0.70 0.335 0.21; ...
             0.125 0.40 0.335 0.21;0.625 0.40 0.335 0.21; ...
             0.125 0.10 0.335 0.21;0.625 0.10 0.335 0.21];
closedSignals = {closed.xS,closed.xG,closed.zDelta(:,1),closed.zDelta(:,2),u,closed.wp(:,1)};
openSignals = {open.xS,open.xG,open.zDelta(:,1),open.zDelta(:,2),zeros(size(open.t)),open.wp(:,2)};
labels = {'$x_{\mathrm S}(t)\;[\mathrm{spikes/s}]$','$x_{\mathrm G}(t)\;[\mathrm{spikes/s}]$', ...
    '$z_{\mathrm S}(t)$','$z_{\mathrm G}(t)$', ...
    '$u(t)\;[\mathrm{spikes/s}]$','$d(t)\;[\mathrm{spikes/s}]$'};
if originalCoordinates
    labels(1:4) = {'$\mathrm{STN}(t)\;[\mathrm{spikes/s}]$', ...
        '$\mathrm{GP}(t)\;[\mathrm{spikes/s}]$','$q_{\mathrm S}(t)$','$q_{\mathrm G}(t)$'};
end
for i=1:6
    ax = axes(fig,'Position',positions(i,:)); hold(ax,'on');
    if i<=4
        ho = plot(ax,open.t,openSignals{i},'--','Color',[0.53 0.56 0.60], ...
            'LineWidth',1.15);
    elseif i==6
        ho = plot(ax,open.t,openSignals{i},'--','Color',[0.85 0.32 0.13],'LineWidth',1.3);
    end
    hc = plot(ax,closed.t,closedSignals{i},'Color',blue,'LineWidth',1.5);
    if i==3 || i==4
        bound = limits(i-2);
        symbol = char('S'*(i==3)+'G'*(i==4));
        hl = yline(ax,bound,':','Color',[0.16 0.18 0.21], ...
            'LineWidth',1.25);
        values = [closedSignals{i};openSignals{i}];
        limitsY = [min([values;bound]),max([values;bound])];
        padding = 0.08*max(diff(limitsY),0.01);
        ylim(ax,limitsY+[-padding padding]);
        drawnow;
        baseTicks = ax.YTick;
        if numel(baseTicks)>1
            tickSpacing = median(diff(baseTicks));
            baseTicks(abs(baseTicks-bound)<0.45*tickSpacing) = [];
        end
        ticks = sort([baseTicks bound]);
        ax.YTick = ticks;
        tickLabels = compose('$%.4g$',ticks);
        [~,boundIndex] = min(abs(ticks-bound));
        tickLabels{boundIndex} = sprintf('$z_{\\mathrm{%s}}^{\\max}$',symbol);
        if originalCoordinates
            tickLabels{boundIndex} = sprintf('$q_{\\mathrm{%s}}^{\\max}$',symbol);
        end
        ax.YTickLabel = tickLabels;
    else
        values = closedSignals{i};
        if i<=2, values = [values;openSignals{i}]; end
        if i==6, values = [values;openSignals{i}]; end
        limitsY = [min(values) max(values)];
        padding = 0.08*max(diff(limitsY),0.01);
        ylim(ax,limitsY+[-padding padding]);
    end
    xlim(ax,[closed.t(1) 0.5]);
    ylabel(ax,labels{i},'Interpreter','latex','FontSize',12);
    if i>=5
        xlabel(ax,'$t\;[\mathrm{s}]$','Interpreter','latex','FontSize',12);
    end
    style_axes(ax,12);
    xticks(ax,0:0.1:0.5);
    if i==3, legendAxes = ax; handles = [hc ho hl]; end
    if i==6
        legend(ax,[hc ho],{'$d_{\mathrm S}$','$d_{\mathrm G}$'}, ...
            'Interpreter','latex','Box','off','Location','northeast','FontSize',12);
    end
end
lg = legend(legendAxes,handles,{'Sector controller$\quad$','Open loop$\quad$','Sector limit$\quad$'}, ...
    'Interpreter','latex','Orientation','horizontal','Box','off','FontSize',12);
lg.Units='normalized'; lg.Position=[0.10 0.947 0.86 0.04];
export_pdf(fig,fullfile(figureRoot,'stn_gpe_sector_trajectories.pdf'));
fprintf('Actual certified alpha: %.10g\n',alpha);
fprintf('Sector upper limits [S,G]: %.9g %.9g\n',limits);
fprintf('Closed-loop maxima z [S,G]: %.9g %.9g\n',maxZ);
fprintf('Final closed-loop states [S,G]: %.9g %.9g\n',closed.xS(end),closed.xG(end));
fprintf('Peak paper control effort: %.9g\n',max(abs(u),[],'all'));
end

function R = simulate_unshifted(R,provenance)
% Integrate absolute population rates using F(q), with the delay transport
% equations discretized by PIESIM. The controller takes rate deviations.
% Constant equilibrium histories have zero spatial derivative, so only the
% first two fundamental-state coordinates require an equilibrium offset.
p=R.parameters;
equilibrium=[p.xS0;p.xG0]; qStar=[p.uS0;p.uG0];
tau=[0.006;0.014];
sigmoid=@(q) [p.MS/(1+exp(-4*q(1)/p.MS)*(p.MS-p.BS)/p.BS); ...
    p.MG/(1+exp(-4*q(2)/p.MG)*(p.MG-p.BG)/p.BG)];
fStar=sigmoid(qStar);
delta=@(z) sigmoid(z+qStar)-fStar;
pulse=@(t) provenance.disturbanceAmplitude* ...
    sin(pi*(t-0.10)/0.04)^2*(t>=0.10 && t<=0.14);
for field={'simOpen','simClosed'}
    name=field{1}; closedLoop=strcmp(name,'simClosed');
    % Cached sim.PIE values from older PIE_sim_nl versions have already
    % been rescaled. Rebuild from the original synthesis plant instead.
    G=unscaled_simulation_plant(R.synthesis.P,R.K,closedLoop);
    times=R.(name).t;
    assert(G.T.dim(1,2)==2,'Only the static-sector controller is supported.');
    x0.ode=[0;0];
    x0.pde={0,0,0};
    opts.nwd0=2; opts.splot=linspace(0,1,151).'; opts.wp=pulse;
    opts.ode=odeset('RelTol',1e-9,'AbsTol',1e-11,'MaxStep',1.25e-4);
    for order=[24,32]
        fprintf('%s: integrating equilibrium initial condition, N=%d\n',name,order);
        opts.N=order;
        shifted=PIE_sim_nl(G,delta,times,x0,opts);
        A=shifted.Dop.Atotal;
        B=shifted.Dop.Tcheb_inv*shifted.Dop.B1cheb;
        C=shifted.Dop.C1cheb; D=shifted.Dop.D11cheb;
        assert(norm(D,inf)<1e-12,'Expected zero feedthrough.');
        assert(size(B,2)==4,'Expected two nonlinearity and two pulse inputs.');
        offset=zeros(size(A,1),1); offset(1:2)=equilibrium;
        initial=offset;
        [t,y]=ode15s(@original_rhs,times,initial,opts.ode);
        deviation=y-offset.';
        q=deviation*C(1:2,:).'+qStar.';
        uCode=zeros(size(t));
        if closedLoop, uCode=deviation*C(3,:).'; end
        wp=zeros(numel(t),2);
        for k=1:numel(t), wp(k,:)=pulse(t(k)).'; end
        signals=[y(:,1:2),q,provenance.controlScaleToPaper*uCode];
        referenceU=zeros(size(t));
        if closedLoop, referenceU=shifted.outputFinite(:,3); end
        reference=[shifted.x(:,1:2),shifted.zFinite, ...
            provenance.controlScaleToPaper*referenceU];
        referenceAbsolute=reference+[equilibrium.',qStar.',0];
        coordinateError=max(abs(signals-referenceAbsolute),[],1)./ ...
            max(1,max(abs(reference),[],1));
        assert(max(coordinateError)<1e-5,'Coordinate equivalence check failed.');
        if order==24
            coarse=signals;
        else
            spatialError=max(abs(signals-coarse),[],1)./ ...
                max(1,max(abs(reference),[],1));
            fprintf('%s spatial refinement errors:',name);
            fprintf(' %.3g',spatialError); fprintf('\n');
            assert(max(spatialError)<1e-3,'Spatial convergence check failed.');
        end
    end
    R.(name)=struct('t',t,'xS',y(:,1),'xG',y(:,2),'zDelta',q, ...
        'u',uCode,'wp',wp);
    R.validation.(name)=struct('coordinateError',coordinateError, ...
        'spatialError',spatialError);
    if ~closedLoop
        directOptions=ddeset('RelTol',1e-10,'AbsTol',1e-12,'MaxStep',1e-4, ...
            'Jumps',[0.10,0.14]);
        direct=dde23(@direct_rhs,[0.004,0.006],equilibrium, ...
            [times(1),times(end)],directOptions);
        directRates=deval(direct,times).';
        directError=max(abs(y(:,1:2)-directRates),[],1)./ ...
            max(1,max(abs(directRates-equilibrium.'),[],1));
        assert(max(directError)<1e-3,'Independent physical-delay check failed.');
        R.validation.(name).directDelayError=directError;
        fprintf('Open-loop PIE/original DDE relative errors: %.3g %.3g\n',directError);
        % Figure 5.C uses zero initial rates and no perturbation pulse.
        reference=dde23(@reference_rhs,[0.004,0.006],[0;0], ...
            [times(1),times(end)],directOptions);
        referenceRates=deval(reference,times).';
        R.reference5C=struct('t',times,'rates',referenceRates, ...
            'history',[0;0],'pulseAmplitude',[0;0]);
        referenceFigure=new_figure([7,3]);
        plot(times,referenceRates(:,1),'k-','LineWidth',1.2); hold on;
        plot(times,referenceRates(:,2),'Color',[0.5,0.5,0.5],'LineWidth',1.2);
        xlabel('Time [s]'); ylabel('Firing rate [spikes/s]');
        legend('STN','GPe'); xlim([0,0.5]); ylim([0,250]);
        title('Original model: K_d=1, zero history, no pulse');
        export_pdf(referenceFigure,fullfile(fileparts(fileparts(fileparts( ...
            mfilename('fullpath')))),'..','Documentation', ...
            'Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations', ...
            'Figures','stn_gpe_reference_5c.pdf'));
    end
    fprintf('%s original/shifted relative errors:',name);
    fprintf(' %.3g',coordinateError); fprintf('\n');
    fprintf('%s N=24/32 relative errors:',name);
    fprintf(' %.3g',spatialError); fprintf('\n');
end
[limits,~]=stn_gpe_admissible_trajectories(R.synthesis.betaBar,R.Kd);
R.validation.sectorMargin=limits-max(R.simClosed.zDelta-qStar.',[],1);
R.validation.insideSector=all(R.validation.sectorMargin>0);
fprintf('Entire closed-loop trajectory inside sector intervals: %d\n', ...
    R.validation.insideSector);
fprintf('Original equilibrium rates: %.10g %.10g\n',equilibrium);
fprintf('Deviation sector margins: %.10g %.10g\n',R.validation.sectorMargin);
    function dy=reference_rhs(~,y,Z)
        q=[-p.wGS*Z(2,2)+p.wCS*p.Ctx; ...
            p.wSG*Z(1,2)-p.wGG*Z(2,1)-p.wXG*p.Str];
        dy=(sigmoid(q)-y)./tau;
    end
    function dy=direct_rhs(t,y,Z)
        dy=reference_rhs(t,y,Z)+pulse(t)./tau;
    end
    function dy=original_rhs(t,y)
        x=y-offset;
        qNow=C(1:2,:)*x+qStar;
        firing=sigmoid(qNow); disturbance=pulse(t);
        % Auxiliary transport coordinates remain spatial derivatives.
        dy=A*x+B(:,1:2)*(firing-fStar)+B(:,3:4)*disturbance;
        u=0;
        if closedLoop, u=provenance.controlScaleToPaper*C(3,:)*x; end
        % Original, unshifted firing-rate equations, including the pulse.
        dy(1:2)=(firing-y(1:2)+[u;0]+disturbance)./tau;
    end
end

function G=unscaled_simulation_plant(P,K,closedLoop)
G=P;
if closedLoop
    G.A=P.A+P.B2*K;
    outputDims=ioDimensions(["nonlinearity","control"], ...
        [P.C1.dim(:,1).';K.dim(:,1).']);
    stateDims=ioDimensions("state",P.C1.dim(:,2).');
    grid=gridBuilder(outputDims,stateDims,P.vars,P.dom);
    grid(1,1)=P.C1+P.D12*K; grid(2,1)=K;
    G.C1=grid();
end
% Append a duplicate disturbance input without modifying the synthesis PIE.
inputDims=ioDimensions(["nonlinearity","pulse"], ...
    [P.B1.dim(:,2).';P.B1.dim(:,2).']);
stateDims=ioDimensions("state",P.B1.dim(:,1).');
grid=gridBuilder(stateDims,inputDims,P.vars,P.dom);
grid(1,1)=P.B1; grid(1,2)=P.B1; G.B1=grid();
zop=@(rows,cols) mat2opvar(zeros(sum(rows),sum(cols)), ...
    [rows,cols],P.vars,P.dom);
G.Tw=zop(G.T.dim(:,1),G.B1.dim(:,2));
G.D11=zop(G.C1.dim(:,1),G.B1.dim(:,2));
empty=[0;0];
G.B2=zop(G.T.dim(:,1),empty); G.Tu=G.B2;
G.C2=zop(empty,G.T.dim(:,2));
G.D12=zop(G.C1.dim(:,1),empty);
G.D21=zop(empty,G.B1.dim(:,2)); G.D22=zop(empty,empty);
G.misc=struct();
end

function fig = new_figure(pageSize)
fig = figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1 1 pageSize],'Renderer','painters');
set(fig,'PaperUnits','inches','PaperSize',pageSize, ...
    'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual');
end

function style_axes(ax,fontSize)
set(ax,'FontName','Times New Roman','FontSize',fontSize, ...
    'TickLabelInterpreter','latex','Box','off','TickDir','out', ...
    'LineWidth',0.6,'XGrid','off','YGrid','on','GridColor',[0.7 0.74 0.78], ...
    'GridAlpha',0.25,'Layer','top','XColor',[0.15 0.17 0.20], ...
    'YColor',[0.15 0.17 0.20]);
end

function export_pdf(fig,file)
print(fig,file,'-dpdf','-painters'); close(fig);
end
