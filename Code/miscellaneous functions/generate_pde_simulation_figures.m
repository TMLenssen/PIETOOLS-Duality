function files = generate_pde_simulation_figures(outDir,s,t,zOpen,zClosed, ...
    inputSignal,controlSignal,settings)
%GENERATE_PDE_SIMULATION_FIGURES Plot and export paired PDE simulations.
% Surface rendering is delegated to PLOT_PDE_SURFACE. Use
% GENERATE_PDE_SURFACE_FIGURE when only one surface PDF is required.

if nargin < 8
    settings = struct;
end
% Defaults used only by this paired simulation-report workflow. Surface
% rendering defaults remain in default_surface_plot_settings.
simulationDefaults.filePrefix = 'simulation';
simulationDefaults.showPreview = true;
simulationDefaults.previewFigureName = 'PDE simulation';
simulationDefaults.previewSurfaceTitles = ...
    {'Open-loop state','Closed-loop state'};
simulationDefaults.figureSize = [7 3.5];
simulationDefaults.lineFigureSize = [3.5 2.35];
simulationDefaults.panelTitles = ...
    {'(a) Open-loop response','(b) Closed-loop response'};
simulationDefaults.amplitudeYLabel = '$\max_s |z(t,s)|$';
simulationDefaults.amplitudeLegend = {'Open loop','Closed loop'};
simulationDefaults.amplitudeTitle = 'Spatial-amplitude comparison';
simulationDefaults.signalYLabel = '';
simulationDefaults.signalLegend = {'Input','Control'};
simulationDefaults.signalTitle = 'Input and control effort';
simulationDefaults.openZTickValues = [];
simulationDefaults.closedZTickValues = [];
simulationDefaults.openZMajorTickSpacing = [];
simulationDefaults.closedZMajorTickSpacing = [];
simulationDefaults.openZMajorTickOrigin = [];
simulationDefaults.closedZMajorTickOrigin = [];
simulationDefaults.openZMinorTickValues = [];
simulationDefaults.closedZMinorTickValues = [];
simulationDefaults.openZMinorTicksBetweenMajor = [];
simulationDefaults.closedZMinorTicksBetweenMajor = [];
names = fieldnames(simulationDefaults);
for k = 1:numel(names)
    if ~isfield(settings,names{k})
        settings.(names{k}) = simulationDefaults.(names{k});
    end
end
settings = default_surface_plot_settings(settings);
[s,t,zOpen,zClosed,inputSignal,controlSignal] = normalize_inputs( ...
    s,t,zOpen,zClosed,inputSignal,controlSignal);

if ~isfolder(outDir)
    mkdir(outDir);
end
files.state = fullfile(outDir,[settings.filePrefix,'_state.pdf']);
files.amplitude = fullfile(outDir,[settings.filePrefix,'_amplitude.pdf']);
files.effort = fullfile(outDir,[settings.filePrefix,'_effort.pdf']);
files.preview = gobjects(0);

ampOpen = max(abs(zOpen),[],2);
ampClosed = max(abs(zClosed),[],2);

if settings.showPreview
    files.preview = write_preview_figure(s,t,zOpen,zClosed,inputSignal, ...
        controlSignal,ampOpen,ampClosed,settings);
end

surfaceIdx = sample_indices(numel(t),settings.surfaceTimeSamples);
write_state_figure(files.state,s,t(surfaceIdx),zOpen(surfaceIdx,:), ...
    zClosed(surfaceIdx,:),settings);
write_amplitude_figure(files.amplitude,t,ampOpen,ampClosed,settings);
write_effort_figure(files.effort,t,inputSignal,controlSignal,settings);
end

function fig = write_preview_figure(s,t,zOpen,zClosed,inputSignal, ...
    controlSignal,ampOpen,ampClosed,settings)
fig = figure('Name',settings.previewFigureName, ...
    'Color',settings.figureBackground);
timeIdx = sample_indices(numel(t),settings.surfaceTimeSamples);
spaceIdx = sample_indices(numel(s),settings.surfaceSpaceSamples);

subplot(2,2,1);
surfaceSettings = panel_surface_settings( ...
    settings,settings.previewSurfaceTitles{1},'open');
plot_pde_surface(gca,s(spaceIdx),t(timeIdx), ...
    zOpen(timeIdx,spaceIdx),surfaceSettings);

subplot(2,2,2);
surfaceSettings = panel_surface_settings( ...
    settings,settings.previewSurfaceTitles{2},'closed');
plot_pde_surface(gca,s(spaceIdx),t(timeIdx), ...
    zClosed(timeIdx,spaceIdx),surfaceSettings);

subplot(2,2,3);
plot(t,ampOpen,'LineWidth',1.4); hold on;
plot(t,ampClosed,'LineWidth',1.4);
grid on;
xlabel(settings.axisLabels{1},'Interpreter',settings.interpreter);
ylabel(settings.amplitudeYLabel,'Interpreter',settings.interpreter);
legend(settings.amplitudeLegend,'Interpreter',settings.interpreter, ...
    'Location','best');
title(settings.amplitudeTitle,'Interpreter',settings.interpreter);
format_paper_axes(gca,settings);

subplot(2,2,4);
plot(t,inputSignal,'LineWidth',1.3); hold on;
plot(t,controlSignal,'LineWidth',1.3);
grid on;
xlabel(settings.axisLabels{1},'Interpreter',settings.interpreter);
ylabel(settings.signalYLabel,'Interpreter',settings.interpreter);
legend(settings.signalLegend,'Interpreter',settings.interpreter, ...
    'Location','best');
title(settings.signalTitle,'Interpreter',settings.interpreter);
format_paper_axes(gca,settings);
end

function write_amplitude_figure(fileName,t,ampOpen,ampClosed,settings)
fig = paper_figure(settings.lineFigureSize,settings);
plot(t,ampOpen,'-.','Color',[0.10 0.10 0.10],'LineWidth',1.15);
hold on;
plot(t,ampClosed,'Color',[0.00 0.45 0.74],'LineWidth',1.25);
grid on;
box on;
xlabel(settings.axisLabels{1},'Interpreter',settings.interpreter);
ylabel(settings.amplitudeYLabel,'Interpreter',settings.interpreter);
legend(settings.amplitudeLegend,'Interpreter',settings.interpreter, ...
    'Location','northwest','FontSize',7);
format_paper_axes(gca,settings);
xlim([t(1),t(end)]);
export_pde_surface_pdf(fig,fileName,settings);
close(fig);
end

function write_effort_figure(fileName,t,inputSignal,controlSignal,settings)
fig = paper_figure(settings.lineFigureSize,settings);
plot(t,inputSignal,'-.','Color',[0.10 0.10 0.10],'LineWidth',1.15);
hold on;
plot(t,controlSignal,'Color',[0.85 0.20 0.15],'LineWidth',1.2);
grid on;
box on;
xlabel(settings.axisLabels{1},'Interpreter',settings.interpreter);
if ~isempty(settings.signalYLabel)
    ylabel(settings.signalYLabel,'Interpreter',settings.interpreter);
end
legend(settings.signalLegend,'Interpreter',settings.interpreter, ...
    'Location','best','FontSize',7);
format_paper_axes(gca,settings);
xlim([t(1),t(end)]);
export_pde_surface_pdf(fig,fileName,settings);
close(fig);
end

function write_state_figure(fileName,s,t,zOpen,zClosed,settings)
fig = paper_figure(settings.figureSize,settings);
layout = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
spaceIdx = sample_indices(numel(s),settings.surfaceSpaceSamples);

openSettings = panel_surface_settings( ...
    settings,settings.panelTitles{1},'open');
axOpen = nexttile(layout);
plot_pde_surface(axOpen,s(spaceIdx),t,zOpen(:,spaceIdx),openSettings);

closedSettings = panel_surface_settings( ...
    settings,settings.panelTitles{2},'closed');
axClosed = nexttile(layout);
plot_pde_surface(axClosed,s(spaceIdx),t,zClosed(:,spaceIdx),closedSettings);

drawnow;
export_pde_surface_pdf(fig,fileName,settings);
close(fig);
end

function surfaceSettings = panel_surface_settings(settings,panelTitle,panel)
% Map paired-figure z-tick overrides onto the generic surface settings.
surfaceSettings = settings;
surfaceSettings.surfaceTitle = panelTitle;
suffixes = {'ZTickValues','ZMajorTickSpacing','ZMajorTickOrigin', ...
    'ZMinorTickValues','ZMinorTicksBetweenMajor'};
sharedNames = {'zTickValues','zMajorTickSpacing','zMajorTickOrigin', ...
    'zMinorTickValues','zMinorTicksBetweenMajor'};
for k = 1:numel(suffixes)
    specificName = [lower(panel),suffixes{k}];
    if ~isempty(settings.(specificName))
        surfaceSettings.(sharedNames{k}) = settings.(specificName);
    end
end
end

function [s,t,zOpen,zClosed,inputSignal,controlSignal] = normalize_inputs( ...
    s,t,zOpen,zClosed,inputSignal,controlSignal)
s = s(:);
t = t(:);
inputSignal = inputSignal(:);
controlSignal = controlSignal(:);
zOpen = orient_surface(zOpen,numel(t),numel(s),'zOpen');
zClosed = orient_surface(zClosed,numel(t),numel(s),'zClosed');
if numel(inputSignal) ~= numel(t) || numel(controlSignal) ~= numel(t)
    error('Input and control signals must contain one value per time sample.');
end
end

function z = orient_surface(z,numTime,numSpace,name)
if isequal(size(z),[numTime,numSpace])
    return
end
if isequal(size(z),[numSpace,numTime])
    z = z.';
    return
end
error('%s must have size numel(t)-by-numel(s), or its transpose.',name);
end

function idx = sample_indices(numSamples,numSelected)
idx = unique(round(linspace(1,numSamples,min(numSamples,numSelected))));
end

function fig = paper_figure(sizeInches,settings)
fig = figure('Color',settings.figureBackground,'Visible','off', ...
    'Units','inches','Position',[1 1 sizeInches],'Renderer','opengl');
end

function format_paper_axes(ax,settings)
set(ax,'FontName',settings.fontName,'FontSize',settings.fontSize, ...
    'TickLabelInterpreter',settings.interpreter, ...
    'Color',settings.figureBackground, ...
    'XColor',settings.axesColor,'YColor',settings.axesColor, ...
    'ZColor',settings.axesColor);
ax.XLabel.Color = settings.textColor;
ax.YLabel.Color = settings.textColor;
ax.ZLabel.Color = settings.textColor;
ax.Title.Color = settings.textColor;
legends = findall(ancestor(ax,'figure'),'Type','Legend');
for k = 1:numel(legends)
    legends(k).TextColor = settings.textColor;
    legends(k).Color = settings.figureBackground;
    legends(k).EdgeColor = settings.axesColor;
end
end
