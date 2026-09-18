function generate_stn_gpe_figures(mode)
% Reproduce the paper's STN--GPe figures from sector-only stability synthesis.
% Run 'synthesize', then 'simulate' for a spatial convergence check.
% Use 'plot' for both figures, 'plot-admissible' for Figure 9, or
% 'plot-trajectories' for Figure 10.
if nargin == 0, mode = 'plot'; end
figureRoot = fileparts(mfilename('fullpath'));
paperRoot = fileparts(figureRoot);
codeRoot = fullfile(paperRoot,'..','..','Code');
exampleRoot = fullfile(codeRoot,'Executables','Examples','Example_4');
addpath(exampleRoot);
cacheFile = fullfile(figureRoot,'stn_gpe_sector_simulation.mat');
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
    source = strrep(source,'simulationInitialState = [1;-1];', ...
        'simulationInitialState = [0;0];');
    % Add d after Delta: w = Delta(z)+d, only in the simulated interconnection.
    source = strrep(source,'sim = PIE_sim_nl(P,delta,tgrid,x0,opts);', ...
        'sim = PIE_sim_nl(add_feedback_disturbance(P),delta,tgrid,x0,opts);');
    source = strrep(source,'sim = PIE_sim_nl(G,delta,tgrid,x0,opts);', ...
        'sim = PIE_sim_nl(add_feedback_disturbance(G),delta,tgrid,x0,opts);');
    source = strrep(source,'opts.nwd0 = 2;',sprintf([ ...
        'opts.nwd0 = 2;\n' ...
        'opts.wp = @(t) [5;-5]*(sin(pi*(t-0.10)/0.04)^2)*(t>=0.10 && t<=0.14);']));
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
        'disturbanceInterval',[0.10 0.14],'disturbanceAmplitude',[5;-5]);
    assert(Results.synthesis.feasible,'Sector synthesis failed.');
    save(cacheFile,'Results','provenance','-v7.3');
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
assert(data.provenance.lambdaSector==1 && data.provenance.lambdaZF==0);
if strcmp(mode,'simulate')
    addpath(genpath('C:\Program Files\MATLAB\PIETOOLS\PIETOOLS'));
    addpath(genpath(codeRoot));
    data.provenance.disturbanceAmplitude = [5;-5];
    data.provenance.initialHistory = [0;0];
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
    name = field{1}; G = R.(name).PIE;
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
[sectorLimit,~] = stn_gpe_admissible_trajectories(alphaSector,1);
[~,slopeLimit] = stn_gpe_admissible_trajectories(alphaSlope,1);
[~,zStar,~,p] = stn_gpe_equilibrium(1);
M = [p.MS,p.MG];
symbols = {'S','G'};
names = {'STN','GPe'};
blue = [0.08 0.40 0.72]; orange = [0.85 0.32 0.13];
sectorFill = [0.86 0.92 0.98]; bothFill = [0.74 0.87 0.80];
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
    {'$\delta_i(z_i)/z_i$','$\delta_i''(z_i)$','Sector bound','Both bounds'}, ...
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
% The synthesis plant uses xS_dot = ... + 4600*u_code; the paper uses
% tauS*xS_dot = ... + u. Plot u_paper = tauS*4600*u_code.
u = provenance.controlScaleToPaper*closed.u;
assert(all(isfinite([closed.xS;closed.xG;closed.zDelta(:);u(:)])));
maxZ = max(closed.zDelta,[],1);
assert(all(maxZ<=limits),'Simulated inputs exceed the sector intervals.');
% Keep the original styling, with readable text at single-column width.
blue = [0.08 0.40 0.72];
fig = new_figure([7.0 6.6]);
positions = [0.125 0.70 0.335 0.21;0.625 0.70 0.335 0.21; ...
             0.125 0.40 0.335 0.21;0.625 0.40 0.335 0.21; ...
             0.125 0.10 0.335 0.21;0.625 0.10 0.335 0.21];
closedSignals = {closed.xS,closed.xG,closed.zDelta(:,1),closed.zDelta(:,2),u,closed.wp(:,1)};
openSignals = {open.xS,open.xG,open.zDelta(:,1),open.zDelta(:,2),zeros(size(open.t)),open.wp(:,2)};
labels = {'$x_{\mathrm S}(t)$','$x_{\mathrm G}(t)$', ...
    '$z_{\mathrm S}(t)$','$z_{\mathrm G}(t)$', ...
    '$u(t)\;[\mathrm{spikes/s}]$','$d(t)\;[\mathrm{spikes/s}]$'};
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
        ylim(ax,[min(-5,1.08*min(values)),1.08*max([values;bound])]);
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
        ax.YTickLabel = tickLabels;
    else
        values = closedSignals{i};
        if i<=2, values = [values;openSignals{i}]; end
        if i==6, values = [values;openSignals{i}]; end
        limitsY = [min(values) max(values)];
        padding = 0.08*max(diff(limitsY),0.01);
        ylim(ax,limitsY+[-padding padding]);
    end
    xlim(ax,[closed.t(1) 0.25]);
    ylabel(ax,labels{i},'Interpreter','latex','FontSize',12);
    if i>=5
        xlabel(ax,'$t$','Interpreter','latex','FontSize',12);
    end
    style_axes(ax,12);
    if i==3, legendAxes = ax; handles = [hc ho hl]; end
    if i==6
        legend(ax,[hc ho],{'$d_{\mathrm S}$','$d_{\mathrm G}$'}, ...
            'Interpreter','latex','Box','off','Location','northeast','FontSize',12);
    end
end
lg = legend(legendAxes,handles,{'Sector controller','Open loop','Sector limit'}, ...
    'Interpreter','latex','Orientation','horizontal','Box','off','FontSize',12);
lg.Units='normalized'; lg.Position=[0.10 0.947 0.86 0.04];
export_pdf(fig,fullfile(figureRoot,'stn_gpe_sector_trajectories.pdf'));
fprintf('Actual certified alpha: %.10g\n',alpha);
fprintf('Sector upper limits [S,G]: %.9g %.9g\n',limits);
fprintf('Closed-loop maxima z [S,G]: %.9g %.9g\n',maxZ);
fprintf('Final closed-loop states [S,G]: %.9g %.9g\n',closed.xS(end),closed.xG(end));
fprintf('Peak paper control effort: %.9g\n',max(abs(u),[],'all'));
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
