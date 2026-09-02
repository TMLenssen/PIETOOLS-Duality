function files = plot_Example_L2_gain(exampleIdx, simulationDataFile, paperFigureDir)
%PLOT_EXAMPLE_L2_GAIN Regenerate Example_i L2-gain figures without synthesis.
%
%   files = plot_Example_L2_gain(exampleIdx)
%   files = plot_Example_L2_gain(exampleIdx, simulationDataFile)
%   files = plot_Example_L2_gain(exampleIdx, simulationDataFile, paperFigureDir)
arguments
    exampleIdx (1,1) {mustBeInteger,mustBePositive}
    simulationDataFile = []
    paperFigureDir = []
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
        'Robust_Control_of_PIE_Systems_using_IQC_based_on_Duality', ...
        'Figures');
end
if ~isfile(simulationDataFile)
    error(['Simulation data not found. Run Example_%d_L2_gain once to ', ...
        'create: %s'], exampleIdx, simulationDataFile);
end
saved = load(simulationDataFile, 'plotData');
data = saved.plotData;
settings = plot_settings(exampleIdx);
files = generate_pde_simulation_figures(paperFigureDir, ...
    data.s, data.t, data.zOpen, data.zClosed, data.inputSignal, ...
    data.boundarySignal, settings);
end


function settings = plot_settings(exampleIdx)
settings.filePrefix = sprintf('example%d', exampleIdx);
settings.showPreview = false;
settings.axisLabels = {'$t$', '$s$', '$x(t,s)$'};
settings.panelTitles = { ...
    '(a) Open-loop response', ...
    '(b) Closed-loop response'};

settings.amplitudeYLabel = '$\max_{s\in[0,1]}|x(t,s)|$';
settings.signalLegend = {'$w_p(t)$', '$x_b(t)$'};
settings.signalTitle = 'Disturbance and boundary state';
settings.surfaceTimeSamples = 1024;
settings.surfaceSpaceSamples = 200;
end