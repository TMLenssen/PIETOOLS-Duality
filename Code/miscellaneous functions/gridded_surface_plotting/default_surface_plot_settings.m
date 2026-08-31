function settings = default_surface_plot_settings(settings)
%DEFAULT_SURFACE_PLOT_SETTINGS Return documented surface-plot defaults.
%   SETTINGS = DEFAULT_SURFACE_PLOT_SETTINGS() returns every setting
%   understood by PLOT_PDE_SURFACE and GENERATE_PDE_SURFACE_FIGURE.
%
%   SETTINGS = DEFAULT_SURFACE_PLOT_SETTINGS(OVERRIDES) returns the
%   defaults with fields from OVERRIDES applied. Unknown fields are also
%   preserved. See EXAMPLE_GENERATE_PDE_SURFACE_FIGURE for usage.

if nargin < 1
    settings = struct;
end
overrides = settings;
settings = struct;

%% Figure layout
% Size of the surface axes box, [width height] in inches. Equal values make
% the layout box square. The complete PDF size is derived from this box,
% labels, title, colorbar, and the margins below.
settings.surfaceBoundingBoxSize = [3.25 3.25];
settings.layoutPadding = 0.12;              % Outer figure padding, inches.
settings.titleGap = 0;                      % Gap above the axes box, inches.
% Signed gap to the relevant plot boundary; negative values allow overlap.
settings.colorbarGap = 0.14;
settings.colorbarThickness = 0.18;          % Short colorbar dimension, inches.
% Space reserved outside the bar for its tick labels.
settings.colorbarTickLabelMargin = 0.35;
settings.figureBackground = 'white';

%% Surface appearance and sampling
% The surface colors and opacity. surfaceAlpha must lie in [0,1].
settings.colormap = mplmap('RdYlBu_r',256);
settings.surfaceAlpha = 1;
% Maximum plotted samples after visual downsampling. These settings do not
% alter the underlying simulation data.
settings.surfaceTimeSamples = 1024;
settings.surfaceSpaceSamples = 512;

%% Raster export quality
% The entire PDF page is rasterized in one pass. 1200 DPI is suitable for
% small publication figures while remaining substantially lighter than a
% 3200-DPI full-page raster. Increase this only when extreme zoom is needed.
settings.resolution = 1200;

%% Lines drawn directly on the surface
% Spatial lines vary with s at t-axis ticks. Temporal lines vary with t at
% s-axis ticks. Automatic constant-z contours follow z-axis ticks.
settings.showSpatialLines = true;
settings.showTemporalLines = true;
settings.showSurfaceLevels = true;
% Keep all level locations tick-driven, but omit the z=0 contour by default.
settings.showZeroSurfaceLevel = false;
% Tolerances suppress numerical-noise contours and very short segments.
settings.surfaceLevelFlatTolerance = 1e-3;
settings.surfaceLevelMinRelativeLength = 1e-2;
% Add lines at unlabeled minor ticks as well as labeled major ticks.
settings.includeMinorTicksInSurfaceLines = true;

%% Major- and minor-tick surface-line styles
% Colors are RGB triples, alpha values are in [0,1], and widths are points.
settings.majorTickLineColor = [0 0 0];
settings.majorTickLineAlpha = 0.3;
settings.majorTickLineWidth = 0.4;
settings.majorTickLineStyle = '-';
settings.minorTickLineColor = [0 0 0];
settings.minorTickLineAlpha = 0.1;
settings.minorTickLineWidth = 0.2;
settings.minorTickLineStyle = '-';

%% Tick lengths and axis-name placement
settings.showZeroTickLabels = true;
% Exact normalized major-tick lengths: [] keeps MATLAB's native lengths;
% use a scalar for all axes or [t s z] for independent axis lengths.
settings.majorTickLength = [];
% Manually drawn minor ticks are this fraction of their major-tick length.
settings.minorTickLengthScale = 0.5;
% Put axis names into middle major tick labels, e.g. t=5. When the z label
% is on the colorbar, its middle major tick carries that label as well.
settings.axisNamesInMiddleTickLabels = true;
% Merge the z=0 label with the one ruler tick at its intersection, using
% (t,z) or (s,z), and suppress the corresponding separate value labels.
settings.combineZIntersectionTickLabels = true;

%% Major and minor tick locations
% Explicit *TickValues take precedence. When they are empty, a nonempty
% *MajorTickSpacing creates a regular lattice; [] retains automatic ticks.
settings.tTickValues = [];
settings.sTickValues = [];
settings.zTickValues = [];
settings.tMajorTickSpacing = 5;
settings.sMajorTickSpacing = 0.5;
settings.zMajorTickSpacing = [];
settings.tMajorTickOrigin = 0;
settings.sMajorTickOrigin = 0;
settings.zMajorTickOrigin = 0;
% Explicit minor ticks take precedence over *MinorTicksBetweenMajor.
settings.tMinorTickValues = [];
settings.sMinorTickValues = [];
settings.zMinorTickValues = [];
settings.tMinorTicksBetweenMajor = 10;
settings.sMinorTicksBetweenMajor = 5;
settings.zMinorTicksBetweenMajor = 10;

%% Three-dimensional ruler placement
% Place the t- and s-rulers at z=0 instead of at a bounding-box edge.
settings.axesAtZeroLevel = true;
% 'auto' selects foreground boundaries for the t- and s-rulers. The z-plane
% is placed on the opposite boundary, while the z-ruler uses the connected
% endpoint. Thus neither horizontal ruler lies in the plane, but z meets
% exactly one of them.
settings.tAxisSLocation = 'auto';
settings.sAxisTLocation = 'auto';

%% Built-in grid and vertical z-plane
settings.showAxesGrid = false;               % Built-in x/y grid.
settings.showZGrid = false;                  % Built-in z grid.
% Select the plane orientation: 's' varies with t and 't' varies with s.
% Its min/max face is chosen automatically opposite the viewing direction.
settings.showTZGrid = true;
settings.zPlaneLocation = 's';
settings.showTZFrame = true;
settings.tzFrameColor = [0 0 0];
settings.tzFrameAlpha = 1;
settings.tzFrameLineWidth = 0.55;
settings.tzFrameLineStyle = '-';
% Connect the z-ruler corner across the s interval at z=0.
settings.showTEndConnector = true;
% Also connect the t=0 end of the t-axis to an s-oriented z-plane.
settings.showTZeroConnector = true;
settings.tEndConnectorColor = [0 0 0];
settings.tEndConnectorAlpha = 1;
settings.tEndConnectorLineWidth = 0.55;
settings.tEndConnectorLineStyle = '-';
settings.showAxesBox = false;

%% Axes and grid style
% Explicit colors make raster exports independent of MATLAB's UI theme.
settings.axesColor = [0 0 0];
settings.textColor = [0 0 0];
settings.axesGridColor = [0.82 0.82 0.82];
settings.axesGridAlpha = 1;
settings.axesLineWidth = 0.55;
settings.axesGridLineWidth = 0.55;
settings.axesGridLineStyle = '-';

%% Camera, labels, and titles
settings.view = [-38 27];                    % [azimuth elevation] in degrees.
% Projection controls foreshortening. cameraViewAngle=[] lets MATLAB choose;
% a positive angle in degrees gives explicit perspective/zoom control.
settings.projection = 'orthographic';        % 'orthographic' or 'perspective'.
settings.cameraViewAngle = [];
% Remove camera roll so the plotted z-axis remains vertical on the page.
% For this PDE plot, that is the axis carrying z(t,s) or x(t,s).
settings.keepZAxisVertical = true;
settings.axisLabels = {'$t$','$s$','$z(t,s)$'};
settings.surfaceTitle = '';

%% Colorbar and typography
settings.colorbarLocation = 'southoutside';
settings.showColorbar = true;
% Put the third entry of axisLabels on the colorbar when one is shown.
% With no colorbar, the label remains attached to the z-axis.
settings.zLabelOnColorbar = true;
settings.fontName = 'Times New Roman';
settings.fontSize = 8;
settings.titleFontSize = 8;
settings.interpreter = 'latex';

% Apply user choices last so a partial settings struct can be passed directly
% to any public plotting function without first requesting the defaults.
names = fieldnames(overrides);
for k = 1:numel(names)
    settings.(names{k}) = overrides.(names{k});
end
end
