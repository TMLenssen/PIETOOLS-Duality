function files = plot_Example_L2_gain(exampleIdx,simulationDataFile,paperFigureDir,plotOptions)
%PLOT_EXAMPLE_L2_GAIN Regenerate Example_i L2-gain figures without synthesis.
%
%   files = plot_Example_L2_gain(exampleIdx)
%   files = plot_Example_L2_gain(exampleIdx, simulationDataFile)
%   files = plot_Example_L2_gain(exampleIdx, simulationDataFile, paperFigureDir)
%   files = plot_Example_L2_gain(..., plotOptions)
%   plot_Example_L2_gain(2,[],[],struct('paperFiguresOnly',true))
%   renders the state and effort panels for paper Figures 7 and 8.
arguments
    exampleIdx (1,1) {mustBeInteger,mustBePositive}
    simulationDataFile = []
    paperFigureDir = []
    plotOptions = struct
end
% Directory containing this plotting function.
plotRoot = fileparts(mfilename('fullpath'));
% Assume example directories are named Example_1, Example_2, ...
exampleDir = fullfile(plotRoot, sprintf('Example_%d', exampleIdx));
codeRoot = fileparts(fileparts(fileparts(exampleDir)));
addpath(genpath(codeRoot));
if isempty(simulationDataFile)
    simulationDataFile = fullfile(exampleDir, ...
        sprintf('Example_%d_L2_simulation.mat', exampleIdx));
end
if isempty(paperFigureDir)
    paperFigureDir = fullfile(fileparts(codeRoot), 'Documentation', ...
        'Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations', ...
        'Figures');
end
if ~isfile(simulationDataFile)
    error(['Simulation data not found. Run Example_%d_L2_gain once to ', ...
        'create: %s'], exampleIdx, simulationDataFile);
end
saved = load(simulationDataFile, 'plotData');
data = saved.plotData;
settings = plot_settings(exampleIdx);
if isfield(plotOptions,'paperFiguresOnly') && plotOptions.paperFiguresOnly
    settings.fontSize = 12;
    settings.titleFontSize = 12;
end
optionNames = fieldnames(plotOptions);
for k = 1:numel(optionNames)
    settings.(optionNames{k}) = plotOptions.(optionNames{k});
end
if isfield(data,'plotOpenLoop')
    settings.plotOpenLoop = data.plotOpenLoop;
end
if isfield(settings,'paperFiguresOnly') && settings.paperFiguresOnly
    assert(ismember(exampleIdx,[2 3]),'Paper figure styling is for examples 2 and 3.');
    files = plot_Example_nonlinear_figures(data,settings,exampleIdx,paperFigureDir);
    return
end
files = generate_pde_simulation_figures(paperFigureDir, ...
    data.s, data.t, data.zOpen, data.zClosed, data.inputSignal, ...
    data.boundarySignal, settings);
end


function settings = plot_settings(exampleIdx)
settings.filePrefix = sprintf('example%d', exampleIdx);
settings.showPreview = true;
settings.previewFigureName = sprintf('Example %d PDE simulation',exampleIdx);
settings.axisLabels = {'$t$', '$s$', '$x(t,s)$'};
settings.panelTitles = { ...
    '(a) Open-loop response', ...
    '(b) Closed-loop response'};

settings.amplitudeYLabel = '$\max_{s\in[0,1]}|x(t,s)|$';
settings.signalLegend = {'$w_p(t)$', '$x_b(t)$'};
settings.signalTitle = 'Disturbance and boundary state';
settings.surfaceTimeSamples = 2048;
settings.surfaceSpaceSamples = 1024;
settings.showZeroSurfaceLevel = true;
settings.colormap = mplmap('magma',256);
if exampleIdx == 2
    settings.colormap = mplmap('rdylbu_r',256);
end
settings.tMajorTickSpacing = 5;
settings.sMajorTickSpacing = 0.25;
% settings.zMajorTickSpacing = 0.5;
settings.tMinorTicksBetweenMajor = 9;
settings.sMinorTicksBetweenMajor = 4;
settings.zMinorTicksBetweenMajor = 9;
settings.view = [45 45];
% settings.resolution = 2400;
end
