function [plotSettings] = example_2_plot_settings()
%EXAMPLE_2_PLOT_SETTINGS Configure optional Example 2 figure rendering.



% Combined state-figure size in inches and surface color lookup table.
plotSettings.figureSize = [7 3.5];
plotSettings.colormap = mplmap('RdYlBu_r',256);

% Rasterized surface-layer quality. PNG preserves sharp surface lines;
% JPEG produces smaller files, with jpegQuality in [1,100].
plotSettings.resolution = 3200;
plotSettings.rasterFormat = 'png';
plotSettings.jpegQuality = 100;
% Preserve all resolution*figureSize pixels in the final PDF. This uses
% pdflatex to place the native raster below MATLAB's vector overlay.
plotSettings.embedRasterAtNativeResolution = true;

% Surface opacity and plotting resolution. surfaceAlpha lies in [0,1].
% The sample counts control visual smoothness, not PIESIM accuracy.
plotSettings.surfaceAlpha = 0.8;
plotSettings.surfaceTimeSamples = 1024;
plotSettings.surfaceSpaceSamples = 512;

% Align each surface-line family with its corresponding axis ticks. Enabling
% the minor switch adds surface lines at minor ticks without labeling them.
plotSettings.alignSurfaceLinesWithTicks = true;
plotSettings.includeMinorTicksInSurfaceLines = true;

% Appearance shared by surface lines at labeled major ticks and unlabeled
% minor ticks, independent of their spatial, temporal, or level direction.
plotSettings.majorTickLineColor = [0 0 0];
plotSettings.majorTickLineAlpha = 0.3;
plotSettings.majorTickLineWidth = 0.4;
plotSettings.majorTickLineStyle = '-';
plotSettings.minorTickLineColor = [0 0 0];
plotSettings.minorTickLineAlpha = 0.1;
plotSettings.minorTickLineWidth = 0.2;
plotSettings.minorTickLineStyle = '-';

% Move only labeled major ticks outward according to the current axes size,
% font size, and longest label. Clearance is in pixels; the length bounds are
% fractions of the shorter axes dimension. Minor ticks retain their shorter
% length, scaled from MATLAB's original 3-D major-tick length.
plotSettings.autoExtendMajorTicks = false;
plotSettings.showZeroTickLabels = true;
plotSettings.majorTickClearancePixels = 5;
plotSettings.majorTickCharacterWidth = 0.55;
plotSettings.majorTickNativeLabelGap = 0.04;
plotSettings.majorTickLengthMinimum = 0.025;
% Per-axis [t s z] bounds keep short labels compact while allowing the
% longer z(t,s)=0 label enough room to clear the surface.
plotSettings.majorTickLengthMaximum = [0.14 0.15 0.18];
plotSettings.majorTickLengthStep = 0.01;
plotSettings.majorTickOverlapTimeSamples = 120;
plotSettings.majorTickOverlapSpaceSamples = 80;
plotSettings.minorTickLengthScale = 0.5;
% Put t and s in their middle major tick labels, e.g. t=20 and s=0.5.
% Keep z(t,s) as a separate axis label so the z=0 tick remains compact.
plotSettings.axisNamesInMiddleTickLabels = true;

% Spatial lines vary with s at selected fixed times. Set the switch to true
% to draw this family and then tune its tick locations.
% Explicit tTickValues override spacing; empty values use spacing or auto ticks.
plotSettings.showSpatialLines = true;
plotSettings.tTickValues = [];
plotSettings.tMajorTickSpacing = 5;
plotSettings.tMajorTickOrigin = 0;
plotSettings.tMinorTickValues = [];
plotSettings.tMinorTicksBetweenMajor = 10;

% Temporal lines vary with t at selected fixed spatial positions.
% Explicit sTickValues override spacing; empty values retain automatic ticks.
plotSettings.showTemporalLines = true;
plotSettings.sTickValues = [];
plotSettings.sMajorTickSpacing = 0.5;
plotSettings.sMajorTickOrigin = 0;
plotSettings.sMinorTickValues = [];
plotSettings.sMinorTicksBetweenMajor = 5;

% Constant-z contours use the selected z-axis ticks when no values are supplied.
plotSettings.showSurfaceLevels = true;
plotSettings.surfaceLevelValues = [];
plotSettings.surfaceLevelExcludedValues = 0;
% Suppress tiny contours caused by numerical noise on nearly flat regions.
plotSettings.surfaceLevelFlatTolerance = 1e-3;
plotSettings.surfaceLevelMinRelativeLength = 1e-2;
plotSettings.zTickValues = [];
plotSettings.zMajorTickSpacing = [];
plotSettings.zMajorTickOrigin = 0;
plotSettings.zMinorTickValues = [];
plotSettings.zMinorTicksBetweenMajor = 10;
% Open- and closed-loop z ticks can be tuned independently. A nonempty
% panel setting overrides the shared z setting above.
% plotSettings.openZTickValues = -10:5:10;
% plotSettings.openZMajorTickSpacing = [];
% plotSettings.openZMajorTickOrigin = [];
% plotSettings.openZMinorTickValues = [];
% plotSettings.openZMinorTicksBetweenMajor = [];
% plotSettings.closedZTickValues = -1.5:0.5:1.5;
% plotSettings.closedZMajorTickSpacing = [];
% plotSettings.closedZMajorTickOrigin = [];
% plotSettings.closedZMinorTickValues = [];
% plotSettings.closedZMinorTicksBetweenMajor = [];

% Rasterizing the depth-occluded surface lines keeps the state PDF compact
% and fast to display. The axes overlay, labels, and colorbars remain vector.
% Set true only when individually editable vector surface lines are required.
plotSettings.vectorizeSurfaceLines = false;
plotSettings.hiddenSurfaceLineAlphaScale = 0.2;
plotSettings.lineVisibilityTolerance = 1e-5;
% Occlusion uses its own coarse mesh; this does not reduce surface quality.
plotSettings.lineOcclusionTimeSamples = 1600;
plotSettings.lineOcclusionSpaceSamples = 1600;
plotSettings.lineOcclusionBins = [160 90];
plotSettings.vectorDashSamples = 8;
plotSettings.vectorGapSamples = 5;
plotSettings.vectorDotSpacingSamples = 5;
plotSettings.vectorDotMarkerScale = 6;

% Raster depth shading is the fallback when vectorizeSurfaceLines is false.
plotSettings.depthShadeSurfaceLines = true;

% Surface lines replace the t- and s-grids. Draw ZTick levels only on the
% t-z wall; MATLAB's built-in ZGrid would repeat them on the s-z wall.
plotSettings.showAxesGrid = false;
plotSettings.showZGrid = false;
plotSettings.showTZGrid = true;
plotSettings.tzGridSLocation = 'max';
plotSettings.showTZFrame = true;
plotSettings.tzFrameColor = [0 0 0];
plotSettings.tzFrameAlpha = 1;
plotSettings.tzFrameLineWidth = 0.55;
plotSettings.tzFrameLineStyle = '-';
% Thick connector from the front t-axis endpoint to the rear t-z plane.
plotSettings.showTEndConnector = true;
plotSettings.tEndConnectorColor = [0 0 0];
plotSettings.tEndConnectorAlpha = 1;
plotSettings.tEndConnectorLineWidth = 0.55;
plotSettings.tEndConnectorLineStyle = '-';
plotSettings.showAxesBox = false;

% Put the t- and s-rulers at z=0 and depth-occlude their hidden segments.
plotSettings.axesAtZeroLevel = true;
plotSettings.tAxisSLocation = 'min';
plotSettings.sAxisTLocation = 'min';
plotSettings.positionZAxisOnTZPlane = true;
plotSettings.zAxisTLocation = 'min';
plotSettings.depthShadeAxesLines = true;
plotSettings.occludeAxesLinesBehindSurface = true;
plotSettings.axesLineWidth = 0.55;
plotSettings.axesGridLineWidth = 0.55;

% Camera azimuth/elevation, axis text, and panel titles.
plotSettings.view = [-38 27];
plotSettings.axisLabels = {'$t$','$s$','$z(t,s)$'};
plotSettings.panelTitles = {'(a) Open-loop response', ...
    '(b) Closed-loop response'};
plotSettings.filePrefix = 'example2';
plotSettings.previewFigureName = 'Example 2 nonlinear simulation';
plotSettings.previewSurfaceTitles = {'Open-loop Sine-Gordon', ...
    'Closed-loop Sine-Gordon'};
plotSettings.amplitudeYLabel = '$\max_{s\in[0,1]}|z(t,s)|$';
plotSettings.signalLegend = {'$d(t)$','$x(t)$'};

% Colorbar and typography shared by the paper figures.
plotSettings.colorbarLocation = 'southoutside';
plotSettings.showColorbar = true;
plotSettings.fontName = 'Times New Roman';
plotSettings.fontSize = 8;
plotSettings.titleFontSize = 8;
plotSettings.interpreter = 'latex';

% Layer backgrounds. rasterBackground must be a solid color because the
% surface layer is raster; 'none' keeps the vector axes overlay transparent.
plotSettings.figureBackground = 'white';
plotSettings.rasterBackground = 'white';
plotSettings.axesBackground = 'none';
plotSettings.overlayBackground = 'none';
end
