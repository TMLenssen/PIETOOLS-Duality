%% Example: export a 2-by-2 collection of PDE response surfaces
plottingDirectory = fileparts(mfilename('fullpath'));
addpath(plottingDirectory);

% One response is reused so the effect of the colormap and colorbar
% orientation can be compared directly across the four panels.
s = linspace(0,1,160);
t = linspace(0,10,1200).';
startup = 1-exp(-1.5*t);
decay = exp(-0.07*t);
x = startup.*(decay.*sin(pi*s).*sin(2.3*t-2*pi*s) ...
    +0.7*exp(-0.35*(t-4.5).^2).*sin(pi*s));

settings = default_surface_plot_settings();
settings.resolution = 800;
settings.surfaceTimeSamples = 600;
settings.surfaceSpaceSamples = 160;
settings.surfaceAlpha = 1;
settings.axisLabels = {'$t$','$s$','$\mathbf{x}(t,s)$'};
settings.view = [100 100];
settings.keepZAxisVertical = true;
settings.tMajorTickSpacing = 2;
settings.sMajorTickSpacing = 0.5;
settings.zMajorTickSpacing = 0.5;
settings.majorTickLength = [0.025 0.04 0.025];
settings.fontSize = 8;
settings.titleFontSize = 9;

% Change these two values for an arbitrary n-by-m layout. Colormaps and
% colorbar locations cycle when the number of panels exceeds four.
numRows = 2;
numColumns = 2;
numPanels = numRows*numColumns;
surfaceData = repmat({x},numPanels,1); % Replace entries for different data.
mapNames = {'magma','viridis','coolwarm','cividis'};
barLocations = {'southoutside','northoutside', ...
    'westoutside','eastoutside'};

fig = figure('Color',settings.figureBackground,'Visible','off','Units','inches', ...
    'Position',[1 1 9 7],'Renderer','opengl');
closeFigure = onCleanup(@()close(fig));
layout = tiledlayout(fig,numRows,numColumns, ...
    'TileSpacing','compact','Padding','compact');

for panel = 1:numPanels
    ax = nexttile(layout,panel);
    panelSettings = settings;
    mapName = mapNames{mod(panel-1,numel(mapNames))+1};
    barLocation = barLocations{mod(panel-1,numel(barLocations))+1};
    panelSettings.colormap = mplmap(mapName,256);
    panelSettings.colorbarLocation = barLocation;
    panelSettings.surfaceTitle = sprintf('%s, %s', ...
        mapName,barLocation);
    plot_pde_surface(ax,s,t,surfaceData{panel},panelSettings);
end

outputFile = fullfile(pwd,'pde_surface_example_2x2.pdf');
export_pde_surface_pdf(fig,outputFile,settings);
fprintf('2-by-2 surface figure written to: %s\n',outputFile);
clear closeFigure
