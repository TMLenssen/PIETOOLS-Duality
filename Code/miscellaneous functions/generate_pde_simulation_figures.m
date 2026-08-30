function files = generate_pde_simulation_figures(outDir,s,t,zOpen,zClosed, ...
    inputSignal,controlSignal,settings)
%GENERATE_PDE_SIMULATION_FIGURES Plot and export paired PDE simulations.
% The surface and optional depth-shaded axes are rasterized; titles,
% colorbars, optional vector surface lines, and ordinary plots remain vector.
% Spatial, temporal, and constant-level surface lines are styled separately.

if nargin < 8
    settings = struct;
end
settings = plotting_defaults(settings);
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
ax = gca;
draw_surface(ax,t(timeIdx),s(spaceIdx),zOpen(timeIdx,spaceIdx),settings);
format_preview_surface(ax,settings.previewSurfaceTitles{1},settings);
apply_tick_values(ax,settings,'open');
position_axes_at_zero(ax,settings);
prepare_axis_names_in_middle_ticks(ax,settings);
extend_major_tick_labels(ax,settings);
draw_surface_lines(ax,t(timeIdx),s(spaceIdx),zOpen(timeIdx,spaceIdx),settings);
draw_tz_plane_lines(ax,t(timeIdx),s(spaceIdx),settings);

subplot(2,2,2);
ax = gca;
draw_surface(ax,t(timeIdx),s(spaceIdx),zClosed(timeIdx,spaceIdx),settings);
format_preview_surface(ax,settings.previewSurfaceTitles{2},settings);
apply_tick_values(ax,settings,'closed');
position_axes_at_zero(ax,settings);
prepare_axis_names_in_middle_ticks(ax,settings);
extend_major_tick_labels(ax,settings);
draw_surface_lines(ax,t(timeIdx),s(spaceIdx),zClosed(timeIdx,spaceIdx),settings);
draw_tz_plane_lines(ax,t(timeIdx),s(spaceIdx),settings);

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

function format_preview_surface(ax,panelTitle,settings)
view(ax,settings.view);
axis(ax,'tight');
if settings.showAxesBox
    box(ax,'on');
else
    box(ax,'off');
end
if settings.showAxesGrid
    grid(ax,'on');
else
    grid(ax,'off');
end
if settings.showZGrid
    ax.ZGrid = 'on';
end
ax.GridColor = settings.axesGridColor;
ax.GridAlpha = settings.axesGridAlpha;
ax.GridLineStyle = settings.axesGridLineStyle;
ax.LineWidth = settings.axesLineWidth;
if settings.showColorbar
    cb = colorbar(ax,settings.colorbarLocation);
    cb.TickLabelInterpreter = settings.interpreter;
end
xlabel(ax,settings.axisLabels{1},'Interpreter',settings.interpreter);
ylabel(ax,settings.axisLabels{2},'Interpreter',settings.interpreter);
zlabel(ax,settings.axisLabels{3},'Interpreter',settings.interpreter);
title(ax,panelTitle,'Interpreter',settings.interpreter);
format_paper_axes(ax,settings);
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
exportgraphics(fig,fileName,'ContentType','vector', ...
    'BackgroundColor',settings.overlayBackground);
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
exportgraphics(fig,fileName,'ContentType','vector', ...
    'BackgroundColor',settings.overlayBackground);
close(fig);
end

function write_state_figure(fileName,s,t,zOpen,zClosed,settings)
fig = paper_figure(settings.figureSize,settings);
layout = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
spaceIdx = sample_indices(numel(s),settings.surfaceSpaceSamples);
axOpen = nexttile(layout);
[surfaceOpen,lineOpen,cbOpen] = write_surface_axes(axOpen,s(spaceIdx),t, ...
    zOpen(:,spaceIdx),settings.panelTitles{1},'open',settings);
axClosed = nexttile(layout);
[surfaceClosed,lineClosed,cbClosed] = write_surface_axes(axClosed,s(spaceIdx),t, ...
    zClosed(:,spaceIdx),settings.panelTitles{2},'closed',settings);
drawnow;
prepare_axis_names_in_middle_ticks(axOpen,settings);
prepare_axis_names_in_middle_ticks(axClosed,settings);
lineOpen = [lineOpen;extend_major_tick_labels(axOpen,settings)];
lineClosed = [lineClosed;extend_major_tick_labels(axClosed,settings)];
export_hybrid_surface_pdf(fig,fileName,[surfaceOpen,surfaceClosed], ...
    [lineOpen;lineClosed],[axOpen,axClosed],[cbOpen,cbClosed],settings);
close(fig);
end

function [surfaceHandle,lineHandles,cb] = write_surface_axes( ...
    ax,s,t,z,panelTitle,panelKind,settings)
surfaceHandle = draw_surface(ax,t,s,z,settings);
view(ax,settings.view);
axis(ax,'tight');
if settings.showAxesBox
    box(ax,'on');
else
    box(ax,'off');
end
ax.SortMethod = 'depth';
if settings.showAxesGrid
    grid(ax,'on');
else
    grid(ax,'off');
end
if settings.showZGrid
    ax.ZGrid = 'on';
end
ax.GridColor = settings.axesGridColor;
ax.GridAlpha = settings.axesGridAlpha;
ax.GridLineStyle = settings.axesGridLineStyle;
ax.LineWidth = settings.axesLineWidth;
colormap(ax,settings.colormap);
cb = gobjects(0);
if settings.showColorbar
    cb = colorbar(ax,settings.colorbarLocation);
    cb.FontSize = settings.fontSize-1;
    cb.TickLabelInterpreter = settings.interpreter;
end
xlabel(ax,settings.axisLabels{1},'Interpreter',settings.interpreter);
ylabel(ax,settings.axisLabels{2},'Interpreter',settings.interpreter);
zlabel(ax,settings.axisLabels{3},'Interpreter',settings.interpreter);
title(ax,panelTitle,'Interpreter',settings.interpreter, ...
    'FontSize',settings.titleFontSize);
format_paper_axes(ax,settings);
xlim(ax,data_limits(t));
ylim(ax,data_limits(s));
if settings.axesAtZeroLevel
    zLimits = data_limits([z(:);0]);
else
    zLimits = data_limits(z);
end
zlim(ax,zLimits);
caxis(ax,zLimits);
apply_tick_values(ax,settings,panelKind);
set(ax,'XLimMode','manual','YLimMode','manual', ...
    'ZLimMode','manual','CLimMode','manual');
position_axes_at_zero(ax,settings);
drawnow;
lineHandles = draw_surface_lines(ax,t,s,z,settings);
lineHandles = [lineHandles;draw_tz_plane_lines(ax,t,s,settings)];
end

function surfaceHandle = draw_surface(ax,t,s,z,settings)
surfaceHandle = surf(ax,t,s,z.','FaceColor','interp', ...
    'EdgeColor','none','FaceAlpha',settings.surfaceAlpha);
colormap(ax,settings.colormap);
end

function lineHandles = draw_surface_lines(ax,t,s,z,settings)
hold(ax,'on');
if settings.alignSurfaceLinesWithTicks
    timeTicks = ax.XTick;
    spaceTicks = ax.YTick;
    if settings.includeMinorTicksInSurfaceLines
        timeTicks = [timeTicks,ax.XRuler.MinorTickValues];
        spaceTicks = [spaceTicks,ax.YRuler.MinorTickValues];
    end
    timeValues = ticks_in_interval(timeTicks,t);
    spaceValues = ticks_in_interval(spaceTicks,s);
    timeIsMinor = minor_tick_mask(timeValues,ax.XTick, ...
        ax.XRuler.MinorTickValues);
    spaceIsMinor = minor_tick_mask(spaceValues,ax.YTick, ...
        ax.YRuler.MinorTickValues);
    spatialZ = interp1(t(:),z,timeValues(:),'linear');
    temporalZ = interp1(s(:),z.',spaceValues(:),'linear').';
else
    timeIdx = sample_indices(numel(t),settings.spatialLineCount);
    spaceIdx = sample_indices(numel(s),settings.temporalLineCount);
    timeValues = t(timeIdx);
    spaceValues = s(spaceIdx);
    timeIsMinor = false(size(timeValues));
    spaceIsMinor = false(size(spaceValues));
    spatialZ = z(timeIdx,:);
    temporalZ = z(:,spaceIdx);
end
if ~settings.showSpatialLines
    timeValues = [];
    timeIsMinor = false(1,0);
    spatialZ = zeros(0,numel(s));
end
if ~settings.showTemporalLines
    spaceValues = [];
    spaceIsMinor = false(1,0);
    temporalZ = zeros(numel(t),0);
end
[levelSegments,levelIsMinor] = surface_level_segments(ax,t,s,z,settings);
lineHandles = gobjects( ...
    numel(timeValues)+numel(spaceValues)+numel(levelSegments),1);
n = 0;
for k = 1:numel(timeValues)
    n = n+1;
    style = tick_line_style(timeIsMinor(k),settings);
    lineHandles(n) = plot3(ax,timeValues(k)*ones(size(s)),s, ...
        spatialZ(k,:).', ...
        'Color',[style.color,style.alpha], ...
        'LineWidth',style.width,'LineStyle',style.lineStyle, ...
        'Tag','SpatialSurfaceLine','UserData',style.tickClass);
end
for k = 1:numel(spaceValues)
    n = n+1;
    style = tick_line_style(spaceIsMinor(k),settings);
    lineHandles(n) = plot3(ax,t,spaceValues(k)*ones(size(t)), ...
        temporalZ(:,k), ...
        'Color',[style.color,style.alpha], ...
        'LineWidth',style.width,'LineStyle',style.lineStyle, ...
        'Tag','TemporalSurfaceLine','UserData',style.tickClass);
end
for k = 1:numel(levelSegments)
    n = n+1;
    points = levelSegments{k};
    style = tick_line_style(levelIsMinor(k),settings);
    lineHandles(n) = plot3(ax,points(:,1),points(:,2),points(:,3), ...
        'Color',[style.color,style.alpha], ...
        'LineWidth',style.width,'LineStyle',style.lineStyle, ...
        'Tag','SurfaceLevelLine','UserData',style.tickClass);
end
hold(ax,'off');
end

function style = tick_line_style(isMinor,settings)
if isMinor
    style.color = settings.minorTickLineColor;
    style.alpha = settings.minorTickLineAlpha;
    style.width = settings.minorTickLineWidth;
    style.lineStyle = settings.minorTickLineStyle;
    style.tickClass = 'minor';
else
    style.color = settings.majorTickLineColor;
    style.alpha = settings.majorTickLineAlpha;
    style.width = settings.majorTickLineWidth;
    style.lineStyle = settings.majorTickLineStyle;
    style.tickClass = 'major';
end
end

function lineHandles = draw_tz_plane_lines(ax,t,s,settings)
lineHandles = gobjects(0,1);
if ~settings.showTZGrid && ~settings.showTZFrame && ...
        ~settings.showTEndConnector
    return
end

switch lower(settings.tzGridSLocation)
    case 'min'
        sPlane = min(s);
    case 'max'
        sPlane = max(s);
    otherwise
        error('tzGridSLocation must be ''min'' or ''max''.');
end

hold(ax,'on');
if settings.showTZGrid
    zValues = ticks_in_interval(ax.ZTick,ax.ZLim);
    for k = 1:numel(zValues)
        lineHandles(end+1,1) = plot3(ax,t,sPlane*ones(size(t)), ...
            zValues(k)*ones(size(t)), ...
            'Color',[settings.axesGridColor,settings.axesGridAlpha], ...
            'LineWidth',settings.axesGridLineWidth, ...
            'LineStyle',settings.axesGridLineStyle, ...
            'Tag','TZGridLine'); %#ok<AGROW>
    end
end
if settings.showTZFrame
    tLimits = [min(t),max(t)];
    zLimits = ax.ZLim;
    zSamples = linspace(zLimits(1),zLimits(2),max(40,numel(s))).';
    frameSegments = {
        [t(:),sPlane*ones(numel(t),1),zLimits(1)*ones(numel(t),1)];
        [t(:),sPlane*ones(numel(t),1),zLimits(2)*ones(numel(t),1)];
        [tLimits(1)*ones(numel(zSamples),1),sPlane*ones(numel(zSamples),1),zSamples];
        [tLimits(2)*ones(numel(zSamples),1),sPlane*ones(numel(zSamples),1),zSamples]};
    for k = 1:numel(frameSegments)
        points = frameSegments{k};
        lineHandles(end+1,1) = plot3(ax,points(:,1),points(:,2),points(:,3), ...
            'Color',[settings.tzFrameColor,settings.tzFrameAlpha], ...
            'LineWidth',settings.tzFrameLineWidth, ...
            'LineStyle',settings.tzFrameLineStyle, ...
            'Tag','TZFrameLine'); %#ok<AGROW>
    end
end
if settings.showTEndConnector
    lineHandles(end+1,1) = plot3(ax,max(t)*ones(size(s)),s,zeros(size(s)), ...
        'Color',[settings.tEndConnectorColor,settings.tEndConnectorAlpha], ...
        'LineWidth',settings.tEndConnectorLineWidth, ...
        'LineStyle',settings.tEndConnectorLineStyle, ...
        'Tag','TEndConnectorLine');
end
hold(ax,'off');
end

function values = ticks_in_interval(ticks,data)
if isempty(data)
    values = [];
    return
end
limits = [min(data),max(data)];
tolerance = max(1,abs(diff(limits)))*1e-10;
values = ticks(ticks >= limits(1)-tolerance & ticks <= limits(2)+tolerance);
values = unique(values(:).','stable');
end

function [segments,segmentIsMinor] = surface_level_segments(ax,t,s,z,settings)
segments = cell(0,1);
segmentIsMinor = false(0,1);
if ~settings.showSurfaceLevels
    return
end

if isempty(settings.surfaceLevelValues)
    if settings.alignSurfaceLinesWithTicks
        levelTicks = ax.ZTick;
        if settings.includeMinorTicksInSurfaceLines
            levelTicks = [levelTicks,ax.ZRuler.MinorTickValues];
        end
        values = ticks_in_interval(levelTicks,z(isfinite(z)));
    else
        finiteValues = z(isfinite(z));
        count = max(0,round(settings.surfaceLevelCount));
        if count == 0 || isempty(finiteValues)
            return
        end
        limits = [min(finiteValues),max(finiteValues)];
        if limits(1) == limits(2)
            return
        end
        values = linspace(limits(1),limits(2),count+2);
        values = values(2:end-1);
    end
else
    values = unique(settings.surfaceLevelValues(:).');
    values = values(isfinite(values));
end
for excludedValue = settings.surfaceLevelExcludedValues(:).'
    tolerance = 1e-12*max(1,abs(excludedValue));
    values(abs(values-excludedValue) <= tolerance) = [];
end
if isempty(values)
    return
end

finiteValues = z(isfinite(z));
dataRange = max(finiteValues)-min(finiteValues);
flatTolerance = settings.surfaceLevelFlatTolerance*max(dataRange,eps);
tScale = max(max(t)-min(t),eps);
sScale = max(max(s)-min(s),eps);
for requestedLevel = values
    requestedLevelIsMinor = is_tick_value(requestedLevel, ...
        ax.ZRuler.MinorTickValues) && ...
        ~is_tick_value(requestedLevel,ax.ZTick);
    contourData = z;
    if flatTolerance > 0
        nearlyFlat = abs(contourData-requestedLevel) <= flatTolerance;
        contourData(nearlyFlat) = requestedLevel+flatTolerance;
    end
    matrix = contourc(t(:).',s(:).',contourData.', ...
        [requestedLevel,requestedLevel]);
    column = 1;
    while column < size(matrix,2)
        level = matrix(1,column);
        pointCount = round(matrix(2,column));
        lastColumn = column+pointCount;
        if pointCount >= 2 && lastColumn <= size(matrix,2)
            xy = matrix(:,column+1:lastColumn).';
            normalizedLength = sum(hypot( ...
                diff(xy(:,1))/tScale,diff(xy(:,2))/sScale));
            if normalizedLength >= settings.surfaceLevelMinRelativeLength
                segments{end+1,1} = ...
                    [xy,level*ones(pointCount,1)]; %#ok<AGROW>
                segmentIsMinor(end+1,1) = requestedLevelIsMinor; %#ok<AGROW>
            end
        end
        column = lastColumn+1;
    end
end
end

function mask = minor_tick_mask(values,majorTicks,minorTicks)
mask = false(size(values));
for k = 1:numel(values)
    mask(k) = is_tick_value(values(k),minorTicks) && ...
        ~is_tick_value(values(k),majorTicks);
end
end

function tf = is_tick_value(value,ticks)
if isempty(ticks)
    tf = false;
    return
end
tolerance = 1e-10*max([1,abs(value),abs(ticks(:).')]);
tf = any(abs(ticks-value) <= tolerance);
end

function position_axes_at_zero(ax,settings)
if ~settings.axesAtZeroLevel
    return
end
if ~isprop(ax.XRuler,'SecondCrossoverValue') || ...
        ~isprop(ax.YRuler,'SecondCrossoverValue')
    error('This MATLAB release cannot position 3-D rulers at z=0.');
end
ax.XRuler.SecondCrossoverValue = 0;
ax.YRuler.SecondCrossoverValue = 0;
ax.XRuler.FirstCrossoverValue = axis_boundary( ...
    ax.YLim,settings.tAxisSLocation);
ax.YRuler.FirstCrossoverValue = axis_boundary( ...
    ax.XLim,settings.sAxisTLocation);
if settings.positionZAxisOnTZPlane
    ax.ZRuler.FirstCrossoverValue = axis_boundary( ...
        ax.YLim,settings.tzGridSLocation);
    ax.ZRuler.SecondCrossoverValue = axis_boundary( ...
        ax.XLim,settings.zAxisTLocation);
end
end

function apply_tick_values(ax,settings,panelKind)
configure_ruler_ticks(ax.XRuler,ax.XLim,settings.tTickValues, ...
    settings.tMajorTickSpacing,settings.tMajorTickOrigin, ...
    settings.tMinorTickValues,settings.tMinorTicksBetweenMajor);
configure_ruler_ticks(ax.YRuler,ax.YLim,settings.sTickValues, ...
    settings.sMajorTickSpacing,settings.sMajorTickOrigin, ...
    settings.sMinorTickValues,settings.sMinorTicksBetweenMajor);
zTickValues = panel_z_setting(settings,panelKind,'ZTickValues');
zMajorTickSpacing = panel_z_setting(settings,panelKind,'ZMajorTickSpacing');
zMajorTickOrigin = panel_z_setting(settings,panelKind,'ZMajorTickOrigin');
zMinorTickValues = panel_z_setting(settings,panelKind,'ZMinorTickValues');
zMinorTicksBetweenMajor = panel_z_setting( ...
    settings,panelKind,'ZMinorTicksBetweenMajor');
configure_ruler_ticks(ax.ZRuler,ax.ZLim,zTickValues,zMajorTickSpacing, ...
    zMajorTickOrigin,zMinorTickValues,zMinorTicksBetweenMajor);
if settings.showZeroTickLabels
    rulers = {ax.XRuler,ax.YRuler,ax.ZRuler};
    limits = {ax.XLim,ax.YLim,ax.ZLim};
    for k = 1:numel(rulers)
        if limits{k}(1) <= 0 && limits{k}(2) >= 0
            force_zero_tick_label(rulers{k});
        end
    end
end
end

function value = panel_z_setting(settings,panelKind,suffix)
specificName = [lower(panelKind),suffix];
sharedName = [lower(suffix(1)),suffix(2:end)];
value = settings.(specificName);
if isempty(value)
    value = settings.(sharedName);
end
end

function force_zero_tick_label(ruler)
ticks = sort(unique([ruler.TickValues,0]));
ruler.TickValues = ticks;
drawnow;
labels = string(ruler.TickLabels);
if numel(labels) ~= numel(ticks)
    labels = string(ticks);
end
zeroIndex = find(abs(ticks) <= 1e-12,1);
labels(zeroIndex) = "0";
ruler.TickLabels = cellstr(labels);
end

function configure_ruler_ticks(ruler,limits,explicitMajor,spacing,origin, ...
    explicitMinor,minorTicksBetween)
if ~isempty(explicitMajor)
    major = explicitMajor(:).';
    latticeSpacing = [];
elseif ~isempty(spacing)
    if ~isscalar(spacing) || ~isfinite(spacing) || spacing <= 0
        error('Major tick spacing must be a positive finite scalar.');
    end
    firstIndex = ceil((limits(1)-origin)/spacing-1e-12);
    lastIndex = floor((limits(2)-origin)/spacing+1e-12);
    major = origin+(firstIndex:lastIndex)*spacing;
    latticeSpacing = spacing;
else
    major = ruler.TickValues;
    latticeSpacing = [];
end
major = major(isfinite(major) & major >= limits(1) & major <= limits(2));
major = unique(major,'stable');
ruler.TickValues = major;

if ~isempty(explicitMinor)
    minor = explicitMinor(:).';
else
    count = max(0,round(minorTicksBetween));
    lattice = extended_major_tick_lattice( ...
        major,limits,latticeSpacing,origin);
    minor = zeros(1,max(0,(numel(lattice)-1)*count));
    cursor = 1;
    for k = 1:numel(lattice)-1
        interval = linspace(lattice(k),lattice(k+1),count+2);
        values = interval(2:end-1);
        minor(cursor:cursor+count-1) = values;
        cursor = cursor+count;
    end
end
minor = minor(isfinite(minor) & minor > limits(1) & minor < limits(2));
minor = setdiff(unique(minor,'stable'),major,'stable');
ruler.MinorTickValues = minor;
if isempty(minor)
    ruler.MinorTick = 'off';
else
    ruler.MinorTick = 'on';
end
end

function lattice = extended_major_tick_lattice(major,limits,spacing,origin)
% Include virtual unlabeled majors outside the limits so minor ticks cover
% partial intervals at both ends of an axis.
if ~isempty(spacing)
    firstIndex = floor((limits(1)-origin)/spacing+1e-12);
    lastIndex = ceil((limits(2)-origin)/spacing-1e-12);
    lattice = origin+(firstIndex:lastIndex)*spacing;
    return
end

lattice = sort(unique(major(:).'));
if numel(lattice) < 2
    return
end
leftSpacing = lattice(2)-lattice(1);
rightSpacing = lattice(end)-lattice(end-1);
if leftSpacing > 0 && lattice(1) > limits(1)
    count = ceil((lattice(1)-limits(1))/leftSpacing);
    lattice = [lattice(1)-(count:-1:1)*leftSpacing,lattice];
end
if rightSpacing > 0 && lattice(end) < limits(2)
    count = ceil((limits(2)-lattice(end))/rightSpacing);
    lattice = [lattice,lattice(end)+(1:count)*rightSpacing];
end
end

function lineHandles = extend_major_tick_labels(ax,settings)
% MATLAB couples major and minor 3-D tick lengths. Lengthen the labeled
% major ticks natively, then replace the minor ticks at their original size.
lineHandles = gobjects(0,1);
if ~settings.autoExtendMajorTicks
    return
end

drawnow;
axesPixels = getpixelposition(ax,true);
normalizer = max(1,min(axesPixels(3:4)));
pixelsPerPoint = get(groot,'ScreenPixelsPerInch')/72;
rulers = {ax.XRuler,ax.YRuler,ax.ZRuler};
overlapContext = tick_label_overlap_context(ax,settings,axesPixels);
originalLengths = zeros(1,numel(rulers));
for k = 1:numel(rulers)
    ruler = rulers{k};
    minimumLength = axis_setting_value( ...
        settings.majorTickLengthMinimum,k,'majorTickLengthMinimum');
    maximumLength = axis_setting_value( ...
        settings.majorTickLengthMaximum,k,'majorTickLengthMaximum');
    if maximumLength < minimumLength
        error('majorTickLengthMaximum must not be smaller than its minimum.')
    end
    tickLength = ruler.TickLength;
    originalLengths(k) = tickLength(2);
    labels = string(ruler.TickLabels);
    if isempty(labels)
        maxCharacters = 1;
    else
        maxCharacters = max(strlength(labels),[],'all');
    end
    labelWidth = ruler.FontSize*pixelsPerPoint* ...
        settings.majorTickCharacterWidth*max(1,double(maxCharacters));
    targetLength = (0.5*labelWidth+settings.majorTickClearancePixels)/ ...
        normalizer;
    targetLength = min(maximumLength,max(minimumLength,targetLength));
    targetLength = clear_surface_tick_labels(ax,k,ruler,labels, ...
        targetLength,maximumLength,overlapContext,settings,pixelsPerPoint);
    tickLength(2) = max(tickLength(2),targetLength);
    ruler.TickLength = tickLength;
    ruler.TickDirection = 'out';
end

if settings.axesAtZeroLevel
    lineHandles = draw_minor_tick_lines(ax,settings,originalLengths);
    for k = 1:numel(rulers)
        if ~isempty(rulers{k}.MinorTickValues)
            rulers{k}.MinorTick = 'off';
        end
    end
end
end

function value = axis_setting_value(setting,rulerIndex,name)
if isscalar(setting)
    value = setting;
elseif numel(setting) == 3
    value = setting(rulerIndex);
else
    error('%s must be a scalar or a three-element [t s z] vector.',name)
end
if ~isfinite(value) || value < 0
    error('%s values must be finite and nonnegative.',name)
end
end

function context = tick_label_overlap_context(ax,settings,axesPixels)
context.valid = false;
if ~settings.axesAtZeroLevel
    return
end
surfaceHandle = findobj(ax,'Type','surface');
if isempty(surfaceHandle)
    return
end
surfaceHandle = surfaceHandle(1);
X = surfaceHandle.XData;
Y = surfaceHandle.YData;
Z = surfaceHandle.ZData;
if isvector(X)
    X = repmat(X(:).',size(Z,1),1);
end
if isvector(Y)
    Y = repmat(Y(:),1,size(Z,2));
end
timeIdx = sample_indices(size(Z,2),settings.majorTickOverlapTimeSamples);
spaceIdx = sample_indices(size(Z,1),settings.majorTickOverlapSpaceSamples);
points = [reshape(X(spaceIdx,timeIdx),[],1), ...
    reshape(Y(spaceIdx,timeIdx),[],1), ...
    reshape(Z(spaceIdx,timeIdx),[],1)];
points = points(all(isfinite(points),2),:);
if isempty(points)
    return
end

camera = axes_camera_projection(ax);
[context.surfaceU,context.surfaceV] = project_to_camera_plane( ...
    points./camera.scale,camera);
[xCorner,yCorner,zCorner] = ndgrid(ax.XLim,ax.YLim,ax.ZLim);
corners = [xCorner(:),yCorner(:),zCorner(:)]./camera.scale;
[cornerU,cornerV] = project_to_camera_plane(corners,camera);
uSpan = max(max(cornerU)-min(cornerU),eps);
vSpan = max(max(cornerV)-min(cornerV),eps);
context.pixelsPerProjectionUnit = min(axesPixels(3)/uSpan, ...
    axesPixels(4)/vSpan);
context.camera = camera;
context.valid = isfinite(context.pixelsPerProjectionUnit) && ...
    context.pixelsPerProjectionUnit > 0;
end

function camera = axes_camera_projection(ax)
camera.scale = reshape(ax.DataAspectRatio,1,3);
camera.cameraPosition = ax.CameraPosition./camera.scale;
cameraTarget = ax.CameraTarget./camera.scale;
cameraUp = ax.CameraUpVector./camera.scale;
camera.cameraForward = cameraTarget-camera.cameraPosition;
camera.cameraForward = camera.cameraForward/norm(camera.cameraForward);
camera.cameraRight = cross(camera.cameraForward,cameraUp);
camera.cameraRight = camera.cameraRight/norm(camera.cameraRight);
camera.cameraUp = cross(camera.cameraRight,camera.cameraForward);
camera.isPerspective = strcmpi(ax.Projection,'perspective');
end

function lengthValue = clear_surface_tick_labels(ax,rulerIndex,ruler,labels, ...
    lengthValue,maximumLength,context,settings,pixelsPerPoint)
if ~context.valid || isempty(ruler.TickValues)
    return
end
while tick_labels_overlap_surface(ax,rulerIndex,ruler.TickValues,labels, ...
        lengthValue,context,settings,pixelsPerPoint) && ...
        lengthValue < maximumLength
    lengthValue = min(maximumLength, ...
        lengthValue+settings.majorTickLengthStep);
end
end

function overlap = tick_labels_overlap_surface(ax,rulerIndex,ticks,labels, ...
    lengthValue,context,settings,pixelsPerPoint)
[anchors,direction] = major_tick_geometry(ax,rulerIndex,ticks);
centers = anchors+(lengthValue+settings.majorTickNativeLabelGap)*direction;
[centerU,centerV] = project_to_camera_plane( ...
    centers./context.camera.scale,context.camera);
fontPixels = settings.fontSize*pixelsPerPoint;
overlap = false;
for k = 1:numel(ticks)
    labelIndex = min(k,numel(labels));
    characterCount = max(1,double(strlength(labels(labelIndex))));
    halfWidth = 0.5*fontPixels*settings.majorTickCharacterWidth* ...
        characterCount+settings.majorTickClearancePixels;
    halfHeight = 0.5*fontPixels+settings.majorTickClearancePixels;
    du = abs(context.surfaceU-centerU(k))* ...
        context.pixelsPerProjectionUnit;
    dv = abs(context.surfaceV-centerV(k))* ...
        context.pixelsPerProjectionUnit;
    if any(du <= halfWidth & dv <= halfHeight)
        overlap = true;
        return
    end
end
end

function [anchors,direction] = major_tick_geometry(ax,rulerIndex,ticks)
switch rulerIndex
    case 1
        boundary = axis_boundary(ax.YLim,'min');
        if ax.XRuler.FirstCrossoverValue == ax.YLim(2)
            boundary = ax.YLim(2);
        end
        anchors = [ticks(:),boundary*ones(numel(ticks),1), ...
            zeros(numel(ticks),1)];
        direction = [0,outward_sign(ax.YLim,boundary)*diff(ax.YLim),0];
    case 2
        boundary = axis_boundary(ax.XLim,'min');
        if ax.YRuler.FirstCrossoverValue == ax.XLim(2)
            boundary = ax.XLim(2);
        end
        anchors = [boundary*ones(numel(ticks),1),ticks(:), ...
            zeros(numel(ticks),1)];
        direction = [outward_sign(ax.XLim,boundary)*diff(ax.XLim),0,0];
    case 3
        tBoundary = ax.ZRuler.SecondCrossoverValue;
        sBoundary = ax.ZRuler.FirstCrossoverValue;
        anchors = [tBoundary*ones(numel(ticks),1), ...
            sBoundary*ones(numel(ticks),1),ticks(:)];
        direction = [outward_sign(ax.XLim,tBoundary)*diff(ax.XLim),0,0];
    otherwise
        error('Unknown ruler index.')
end
end

function signValue = outward_sign(limits,boundary)
if abs(boundary-limits(1)) <= abs(boundary-limits(2))
    signValue = -1;
else
    signValue = 1;
end
end

function prepare_axis_names_in_middle_ticks(ax,settings)
if ~settings.axisNamesInMiddleTickLabels
    return
end
rulers = {ax.XRuler,ax.YRuler,ax.ZRuler};
labels = [ax.XLabel,ax.YLabel,ax.ZLabel];
limits = {ax.XLim,ax.YLim,ax.ZLim};
for k = 1:2
    ticks = rulers{k}.TickValues;
    middleIndex = middle_tick_index(ticks,limits{k});
    tickLabels = string(rulers{k}.TickLabels);
    valueText = erase(tickLabels(middleIndex),"$");
    axisName = erase(join(string(labels(k).String),""),"$");
    combinedLabel = "$"+axisName+"="+valueText+"$";
    tickLabels(middleIndex) = combinedLabel;
    rulers{k}.TickLabels = cellstr(tickLabels);
    labels(k).String = '';
end
end

function index = middle_tick_index(ticks,limits)
distance = abs(ticks-mean(limits));
index = find(distance <= min(distance)+1e-12*max(1,diff(limits)),1,'last');
end

function lineHandles = draw_minor_tick_lines(ax,settings,originalLengths)
lineHandles = gobjects(0,1);
holdState = ishold(ax);
hold(ax,'on');

tMinor = ticks_in_interval(ax.XRuler.MinorTickValues,ax.XLim);
sMinor = ticks_in_interval(ax.YRuler.MinorTickValues,ax.YLim);
zMinor = ticks_in_interval(ax.ZRuler.MinorTickValues,ax.ZLim);
sAxis = axis_boundary(ax.YLim,settings.tAxisSLocation);
sTip = outward_tick_tip(ax.YLim,settings.tAxisSLocation, ...
    originalLengths(1)*settings.minorTickLengthScale);
tAxis = axis_boundary(ax.XLim,settings.sAxisTLocation);
tTip = outward_tick_tip(ax.XLim,settings.sAxisTLocation, ...
    originalLengths(2)*settings.minorTickLengthScale);
zAxisT = axis_boundary(ax.XLim,settings.zAxisTLocation);
zTipT = outward_tick_tip(ax.XLim,settings.zAxisTLocation, ...
    originalLengths(3)*settings.minorTickLengthScale);
zAxisS = axis_boundary(ax.YLim,settings.tzGridSLocation);

for value = tMinor
    lineHandles(end+1,1) = plot3(ax,[value,value],[sAxis,sTip],[0,0], ...
        'Color',ax.XRuler.Color,'LineWidth',settings.axesLineWidth, ...
        'Clipping','off','Tag','MinorTickLine'); %#ok<AGROW>
end
for value = sMinor
    lineHandles(end+1,1) = plot3(ax,[tAxis,tTip],[value,value],[0,0], ...
        'Color',ax.YRuler.Color,'LineWidth',settings.axesLineWidth, ...
        'Clipping','off','Tag','MinorTickLine'); %#ok<AGROW>
end
for value = zMinor
    lineHandles(end+1,1) = plot3(ax,[zAxisT,zTipT],[zAxisS,zAxisS], ...
        [value,value],'Color',ax.ZRuler.Color, ...
        'LineWidth',settings.axesLineWidth,'Clipping','off', ...
        'Tag','MinorTickLine'); %#ok<AGROW>
end
if ~holdState
    hold(ax,'off');
end
end

function value = outward_tick_tip(limits,location,normalizedLength)
span = diff(limits);
switch lower(location)
    case 'min'
        value = limits(1)-normalizedLength*span;
    case 'max'
        value = limits(2)+normalizedLength*span;
    otherwise
        error('Axis boundary location must be ''min'' or ''max''.')
end
end

function value = axis_boundary(limits,location)
switch lower(location)
    case 'min'
        value = limits(1);
    case 'max'
        value = limits(2);
    otherwise
        error('Axis boundary location must be ''min'' or ''max''.');
end
end

function export_hybrid_surface_pdf(fig,fileName,surfaceHandles,lineHandles, ...
    axesHandles,colorbars,settings)
outDir = fileparts(fileName);
rasterPrefix = tempname(outDir);
rasterPng = [rasterPrefix,'.png'];
rasterJpeg = [rasterPrefix,'.jpg'];
overlayPdf = [rasterPrefix,'_overlay.pdf'];
composeTex = [rasterPrefix,'_compose.tex'];
composePdf = [rasterPrefix,'_compose.pdf'];
composeAux = [rasterPrefix,'_compose.aux'];
composeLog = [rasterPrefix,'_compose.log'];
cleanup = onCleanup(@()delete_temp_files(rasterPng,rasterJpeg, ...
    overlayPdf,composeTex,composePdf,composeAux,composeLog));

axisState = cell(numel(axesHandles),16);
for k = 1:numel(axesHandles)
    ax = axesHandles(k);
    axisState(k,:) = {ax.XRuler.Color,ax.YRuler.Color,ax.ZRuler.Color, ...
        ax.XRuler.TickLabelColor,ax.YRuler.TickLabelColor, ...
        ax.ZRuler.TickLabelColor,ax.GridColor,ax.MinorGridColor, ...
        ax.XLabel.Color,ax.YLabel.Color,ax.ZLabel.Color,ax.Title.Color, ...
        ax.XGrid,ax.YGrid,ax.ZGrid,ax.Layer};
    if settings.depthShadeAxesLines
        % Keep the complete rulers in the OpenGL pass so their lines use the
        % same depth buffer as the surface.
        ax.Layer = 'bottom';
    else
        ax.XRuler.Color = settings.rasterBackground;
        ax.YRuler.Color = settings.rasterBackground;
        ax.ZRuler.Color = settings.rasterBackground;
        ax.XLabel.Color = settings.rasterBackground;
        ax.YLabel.Color = settings.rasterBackground;
        ax.ZLabel.Color = settings.rasterBackground;
    end
    if settings.depthShadeAxesGrid
        ax.Layer = 'bottom';
    end
    ax.Title.Color = settings.rasterBackground;
    if ~settings.depthShadeAxesGrid
        ax.GridColor = settings.rasterBackground;
        ax.MinorGridColor = settings.rasterBackground;
        ax.XGrid = 'off';
        ax.YGrid = 'off';
        ax.ZGrid = 'off';
    end
end
lineState = set_surface_line_layer(lineHandles,'raster',settings);
colorbarState = cell(numel(colorbars),2);
for k = 1:numel(colorbars)
    colorbarState(k,:) = {colorbars(k).Color,colorbars(k).Visible};
    colorbars(k).Visible = 'off';
end
surfaceDepthState = apply_opaque_surface_depth( ...
    surfaceHandles,axesHandles,settings);

drawnow;
figureSize = fig.Position(3:4);
set(fig,'PaperUnits','inches','PaperPosition',[0 0 figureSize], ...
    'PaperSize',figureSize,'InvertHardcopy','off');
print(fig,rasterPng,'-dpng',sprintf('-r%d',settings.resolution),'-opengl');
rasterFile = rasterPng;
raster = [];
switch lower(settings.rasterFormat)
    case 'png'
        % Keep the lossless OpenGL render for sharp depth-buffered lines.
        if ~settings.embedRasterAtNativeResolution
            raster = imread(rasterPng);
        end
    case {'jpg','jpeg'}
        raster = imread(rasterPng);
        imwrite(raster,rasterJpeg,'Quality',settings.jpegQuality);
        rasterFile = rasterJpeg;
        if settings.embedRasterAtNativeResolution
            clear raster
        else
            raster = imread(rasterJpeg);
        end
    otherwise
        error('rasterFormat must be ''png'', ''jpg'', or ''jpeg''.');
end
restore_surface_depth(surfaceHandles,axesHandles,surfaceDepthState);

for k = 1:numel(axesHandles)
    ax = axesHandles(k);
    ax.XRuler.Color = axisState{k,1};
    ax.YRuler.Color = axisState{k,2};
    ax.ZRuler.Color = axisState{k,3};
    ax.XRuler.TickLabelColor = axisState{k,4};
    ax.YRuler.TickLabelColor = axisState{k,5};
    ax.ZRuler.TickLabelColor = axisState{k,6};
    ax.GridColor = axisState{k,7};
    ax.MinorGridColor = axisState{k,8};
    ax.XLabel.Color = axisState{k,9};
    ax.YLabel.Color = axisState{k,10};
    ax.ZLabel.Color = axisState{k,11};
    ax.Title.Color = axisState{k,12};
    ax.XGrid = axisState{k,13};
    ax.YGrid = axisState{k,14};
    ax.ZGrid = axisState{k,15};
    ax.Layer = axisState{k,16};
    if settings.depthShadeAxesLines
        % The complete rulers already exist in the aligned raster layer.
        ax.XRuler.Color = 'none';
        ax.YRuler.Color = 'none';
        ax.ZRuler.Color = 'none';
    end
    if settings.depthShadeAxesGrid
        ax.XGrid = 'off';
        ax.YGrid = 'off';
        ax.ZGrid = 'off';
    end
    ax.Color = settings.axesBackground;
end
set_surface_line_layer(lineHandles,'overlay',settings,lineState);
if settings.vectorizeSurfaceLines
    draw_depth_shaded_vector_lines(surfaceHandles,lineHandles,settings);
end
for k = 1:numel(colorbars)
    colorbars(k).Color = colorbarState{k,1};
    colorbars(k).Visible = colorbarState{k,2};
end
set(surfaceHandles,'Visible','off');

if settings.embedRasterAtNativeResolution
    exportgraphics(fig,overlayPdf,'ContentType','vector', ...
        'BackgroundColor',settings.overlayBackground);
    compose_native_raster_pdf(rasterFile,overlayPdf,composeTex,composePdf, ...
        fileName,figureSize);
else
    backgroundAxes = axes(fig,'Units','normalized','Position',[0 0 1 1], ...
        'Visible','off','HitTest','off','HandleVisibility','off');
    image(backgroundAxes,'CData',raster,'XData',[0 1],'YData',[0 1]);
    set(backgroundAxes,'XLim',[0 1],'YLim',[0 1],'YDir','reverse', ...
        'DataAspectRatioMode','auto','PlotBoxAspectRatioMode','auto');
    uistack(backgroundAxes,'bottom');
    drawnow;
    exportgraphics(fig,fileName,'ContentType','vector', ...
        'BackgroundColor',settings.overlayBackground);
end
clear cleanup
end

function compose_native_raster_pdf(rasterFile,overlayPdf,texFile, ...
    composedPdf,fileName,figureSize)
% pdfTeX embeds the raster without MATLAB's 576-dpi image downsampling.
rasterFile = strrep(rasterFile,'\','/');
overlayPdf = strrep(overlayPdf,'\','/');
fid = fopen(texFile,'w');
if fid < 0
    error('Unable to create temporary PDF composition file: %s',texFile);
end
closeFile = onCleanup(@()fclose(fid));
fprintf(fid,'\\documentclass[border=0pt]{standalone}\n');
fprintf(fid,'\\usepackage{graphicx}\n');
fprintf(fid,'\\begin{document}\n');
fprintf(fid,['\\includegraphics[width=%.12gin,height=%.12gin]', ...
    '{\\detokenize{%s}}%%\n'],figureSize(1),figureSize(2),rasterFile);
fprintf(fid,['\\llap{\\includegraphics[width=%.12gin,height=%.12gin]', ...
    '{\\detokenize{%s}}}\n'],figureSize(1),figureSize(2),overlayPdf);
fprintf(fid,'\\end{document}\n');
clear closeFile

[texDir,~] = fileparts(texFile);
texCommandDir = strrep(texDir,'\','/');
texCommandFile = strrep(texFile,'\','/');
command = sprintf(['pdflatex -interaction=nonstopmode -halt-on-error ', ...
    '-output-directory="%s" "%s"'],texCommandDir,texCommandFile);
[status,output] = system(command);
if status ~= 0 || ~isfile(composedPdf)
    error('Native-resolution PDF composition failed:\n%s',output);
end
[moved,message] = movefile(composedPdf,fileName,'f');
if ~moved
    error('Unable to write PDF %s: %s',fileName,message);
end
end

function state = apply_opaque_surface_depth(surfaceHandles,axesHandles,settings)
% Simulate surface transparency through color blending while retaining an
% opaque depth mask, so rear Cartesian grid lines cannot bleed through.
occludeGrid = settings.depthShadeAxesGrid && ...
    settings.occludeAxesGridBehindSurface;
occludeAxes = settings.depthShadeAxesLines && ...
    settings.occludeAxesLinesBehindSurface;
state.enabled = (occludeGrid || occludeAxes) && settings.surfaceAlpha < 1;
state.faceAlpha = cell(numel(surfaceHandles),1);
state.colormap = cell(numel(axesHandles),1);
if ~state.enabled
    return
end

background = validatecolor(settings.rasterBackground,'one');
alpha = settings.surfaceAlpha;
for k = 1:numel(surfaceHandles)
    state.faceAlpha{k} = surfaceHandles(k).FaceAlpha;
    surfaceHandles(k).FaceAlpha = 1;
end
for k = 1:numel(axesHandles)
    state.colormap{k} = colormap(axesHandles(k));
    blendedMap = alpha*state.colormap{k}+(1-alpha)*background;
    colormap(axesHandles(k),blendedMap);
end
end

function restore_surface_depth(surfaceHandles,axesHandles,state)
if ~state.enabled
    return
end
for k = 1:numel(surfaceHandles)
    surfaceHandles(k).FaceAlpha = state.faceAlpha{k};
end
for k = 1:numel(axesHandles)
    colormap(axesHandles(k),state.colormap{k});
end
end

function state = set_surface_line_layer(lineHandles,layer,settings,state)
% The raster pass gives line segments the surface's depth-buffer occlusion.
if nargin < 4
    state.colors = cell(numel(lineHandles),1);
    state.visible = cell(numel(lineHandles),1);
    for k = 1:numel(lineHandles)
        state.colors{k} = lineHandles(k).Color;
        state.visible{k} = lineHandles(k).Visible;
    end
end
if isempty(lineHandles)
    return
end
switch layer
    case 'raster'
        if settings.vectorizeSurfaceLines
            set(lineHandles,'Visible','off');
        elseif ~settings.depthShadeSurfaceLines
            set(lineHandles,'Color',settings.rasterBackground);
        end
    case 'overlay'
        if settings.vectorizeSurfaceLines || settings.depthShadeSurfaceLines
            set(lineHandles,'Visible','off');
        else
            for k = 1:numel(lineHandles)
                lineHandles(k).Color = state.colors{k};
                lineHandles(k).Visible = state.visible{k};
            end
        end
    otherwise
        error('Unknown surface-line export layer "%s".',layer);
end
end

function draw_depth_shaded_vector_lines(surfaceHandles,lineHandles,settings)
for k = 1:numel(surfaceHandles)
    ax = ancestor(surfaceHandles(k),'axes');
    belongsToAxes = arrayfun(@(h)isequal(ancestor(h,'axes'),ax),lineHandles);
    axesLines = lineHandles(belongsToAxes);
    if isempty(axesLines)
        continue
    end
    mesh = triangulate_surface(surfaceHandles(k),ax,settings);
    for j = 1:numel(axesLines)
        source = axesLines(j);
        points = [source.XData(:),source.YData(:),source.ZData(:)];
        visible = points_visible_from_camera(points,mesh,ax,settings);
        draw_masked_line(ax,source,visible,1,settings);
        hiddenAlphaScale = settings.hiddenSurfaceLineAlphaScale;
        if ismember(source.Tag, ...
                {'TZGridLine','TZFrameLine','TEndConnectorLine'})
            hiddenAlphaScale = 0;
        end
        if hiddenAlphaScale > 0
            draw_masked_line(ax,source,~visible, ...
                hiddenAlphaScale,settings);
        end
    end
end
end

function mesh = triangulate_surface(surfaceHandle,ax,settings)
X = surfaceHandle.XData;
Y = surfaceHandle.YData;
Z = surfaceHandle.ZData;
if isvector(X)
    X = repmat(X(:).',size(Z,1),1);
end
if isvector(Y)
    Y = repmat(Y(:),1,size(Z,2));
end
timeIdx = sample_indices(size(Z,2),settings.lineOcclusionTimeSamples);
spaceIdx = sample_indices(size(Z,1),settings.lineOcclusionSpaceSamples);
X = X(spaceIdx,timeIdx);
Y = Y(spaceIdx,timeIdx);
Z = Z(spaceIdx,timeIdx);

x00 = X(1:end-1,1:end-1); y00 = Y(1:end-1,1:end-1); z00 = Z(1:end-1,1:end-1);
x10 = X(1:end-1,2:end);   y10 = Y(1:end-1,2:end);   z10 = Z(1:end-1,2:end);
x01 = X(2:end,1:end-1);   y01 = Y(2:end,1:end-1);   z01 = Z(2:end,1:end-1);
x11 = X(2:end,2:end);     y11 = Y(2:end,2:end);     z11 = Z(2:end,2:end);
v00 = [x00(:),y00(:),z00(:)];
v10 = [x10(:),y10(:),z10(:)];
v01 = [x01(:),y01(:),z01(:)];
v11 = [x11(:),y11(:),z11(:)];
scale = reshape(ax.DataAspectRatio,1,3);
mesh.a = [v00;v00]./scale;
mesh.b = [v10;v11]./scale;
mesh.c = [v11;v01]./scale;
valid = all(isfinite(mesh.a),2) & all(isfinite(mesh.b),2) & ...
    all(isfinite(mesh.c),2);
mesh.a = mesh.a(valid,:);
mesh.b = mesh.b(valid,:);
mesh.c = mesh.c(valid,:);
mesh.edge1 = mesh.b-mesh.a;
mesh.edge2 = mesh.c-mesh.a;
mesh.scale = scale;
ranges = max([X(:),Y(:),Z(:)],[],1)-min([X(:),Y(:),Z(:)],[],1);
mesh.diameter = max(norm(ranges./scale),1);
mesh = build_occlusion_bins(mesh,ax,settings);
end

function mesh = build_occlusion_bins(mesh,ax,settings)
mesh.cameraPosition = ax.CameraPosition./mesh.scale;
cameraTarget = ax.CameraTarget./mesh.scale;
cameraUp = ax.CameraUpVector./mesh.scale;
mesh.cameraForward = cameraTarget-mesh.cameraPosition;
mesh.cameraForward = mesh.cameraForward/norm(mesh.cameraForward);
mesh.cameraRight = cross(mesh.cameraForward,cameraUp);
mesh.cameraRight = mesh.cameraRight/norm(mesh.cameraRight);
mesh.cameraUp = cross(mesh.cameraRight,mesh.cameraForward);
mesh.orthographicDirection = -mesh.cameraForward;
mesh.isPerspective = strcmpi(ax.Projection,'perspective');

[ua,va] = project_to_camera_plane(mesh.a,mesh);
[ub,vb] = project_to_camera_plane(mesh.b,mesh);
[uc,vc] = project_to_camera_plane(mesh.c,mesh);
uTriangle = [ua,ub,uc];
vTriangle = [va,vb,vc];
mesh.uMin = min(uTriangle,[],'all');
mesh.uMax = max(uTriangle,[],'all');
mesh.vMin = min(vTriangle,[],'all');
mesh.vMax = max(vTriangle,[],'all');
mesh.uSpan = max(mesh.uMax-mesh.uMin,eps);
mesh.vSpan = max(mesh.vMax-mesh.vMin,eps);

binCount = max(1,round(settings.lineOcclusionBins(:).'));
if isscalar(binCount)
    binCount = [binCount,binCount];
end
mesh.numBinsX = binCount(1);
mesh.numBinsY = binCount(2);
mesh.bins = cell(mesh.numBinsX*mesh.numBinsY,1);
ixFirst = bin_index(min(uTriangle,[],2),mesh.uMin,mesh.uSpan,mesh.numBinsX);
ixLast = bin_index(max(uTriangle,[],2),mesh.uMin,mesh.uSpan,mesh.numBinsX);
iyFirst = bin_index(min(vTriangle,[],2),mesh.vMin,mesh.vSpan,mesh.numBinsY);
iyLast = bin_index(max(vTriangle,[],2),mesh.vMin,mesh.vSpan,mesh.numBinsY);

for triangle = 1:size(mesh.a,1)
    for iy = iyFirst(triangle):iyLast(triangle)
        for ix = ixFirst(triangle):ixLast(triangle)
            id = ix+(iy-1)*mesh.numBinsX;
            mesh.bins{id}(end+1) = triangle;
        end
    end
end
end

function [u,v] = project_to_camera_plane(points,mesh)
relative = points-mesh.cameraPosition;
u = relative*mesh.cameraRight.';
v = relative*mesh.cameraUp.';
if mesh.isPerspective
    depth = relative*mesh.cameraForward.';
    depth(abs(depth) < eps) = eps;
    u = u./depth;
    v = v./depth;
end
end

function index = bin_index(value,minimum,span,numBins)
index = floor((value-minimum)./span*numBins)+1;
index = min(numBins,max(1,index));
end

function candidates = projected_candidates(point,mesh)
[u,v] = project_to_camera_plane(point,mesh);
ix = bin_index(u,mesh.uMin,mesh.uSpan,mesh.numBinsX);
iy = bin_index(v,mesh.vMin,mesh.vSpan,mesh.numBinsY);
candidates = mesh.bins{ix+(iy-1)*mesh.numBinsX};
end

function visible = points_visible_from_camera(points,mesh,~,settings)
points = points./mesh.scale;
tolerance = settings.lineVisibilityTolerance*mesh.diameter;
visible = true(size(points,1),1);

for k = 1:size(points,1)
    point = points(k,:);
    triangleIds = projected_candidates(point,mesh);
    if isempty(triangleIds)
        continue
    end
    if mesh.isPerspective
        direction = mesh.cameraPosition-point;
        maxDistance = norm(direction);
        direction = direction/maxDistance;
    else
        direction = mesh.orthographicDirection;
        maxDistance = inf;
    end
    edge1 = mesh.edge1(triangleIds,:);
    edge2 = mesh.edge2(triangleIds,:);
    triangleA = mesh.a(triangleIds,:);
    h = cross(repmat(direction,size(edge2,1),1),edge2,2);
    determinant = sum(edge1.*h,2);
    candidates = abs(determinant) > 1e-12;
    inverseDeterminant = zeros(size(determinant));
    inverseDeterminant(candidates) = 1./determinant(candidates);
    offset = point-triangleA;
    u = inverseDeterminant.*sum(offset.*h,2);
    q = cross(offset,edge1,2);
    v = inverseDeterminant.*sum(repmat(direction,size(q,1),1).*q,2);
    distance = inverseDeterminant.*sum(edge2.*q,2);
    hit = candidates & u >= -1e-9 & v >= -1e-9 & ...
        u+v <= 1+1e-9 & distance > tolerance & ...
        distance < maxDistance-tolerance;
    visible(k) = ~any(hit);
end
end

function handle = draw_masked_line(ax,source,mask,alphaScale,settings)
mask = mask(:);
if numel(mask) < 2 || ~any(mask(1:end-1) | mask(2:end))
    handle = gobjects(0);
    return
end
points = [source.XData(:),source.YData(:),source.ZData(:)];
polyline = zeros(0,3);
k = 1;
while k <= numel(mask)
    if ~mask(k)
        k = k+1;
        continue
    end
    runStart = k;
    while k < numel(mask) && mask(k+1)
        k = k+1;
    end
    runEnd = k;
    run = points(runStart:runEnd,:);
    if runStart > 1
        run = [0.5*(points(runStart-1,:)+points(runStart,:));run]; %#ok<AGROW>
    end
    if runEnd < size(points,1)
        run = [run;0.5*(points(runEnd,:)+points(runEnd+1,:))]; %#ok<AGROW>
    end
    polyline = [polyline;run;nan(1,3)]; %#ok<AGROW>
    k = runEnd+1;
end
switch source.Tag
    case {'SpatialSurfaceLine','TemporalSurfaceLine','SurfaceLevelLine'}
        style = tick_line_style(strcmp(source.UserData,'minor'),settings);
        color = [style.color,style.alpha];
        lineWidth = style.width;
        lineStyle = style.lineStyle;
    case 'TZGridLine'
        color = [settings.axesGridColor,settings.axesGridAlpha];
        lineWidth = settings.axesGridLineWidth;
        lineStyle = settings.axesGridLineStyle;
    case 'TZFrameLine'
        color = [settings.tzFrameColor,settings.tzFrameAlpha];
        lineWidth = settings.tzFrameLineWidth;
        lineStyle = settings.tzFrameLineStyle;
    case 'TEndConnectorLine'
        color = [settings.tEndConnectorColor,settings.tEndConnectorAlpha];
        lineWidth = settings.tEndConnectorLineWidth;
        lineStyle = settings.tEndConnectorLineStyle;
    otherwise
        color = source.Color;
        if numel(color) == 3
            color(4) = 1;
        end
        lineWidth = source.LineWidth;
        lineStyle = source.LineStyle;
end
color(4) = color(4)*alphaScale;
[strokePoints,markerPoints] = vector_line_style(polyline,lineStyle,settings);
handle = gobjects(0);
if ~isempty(strokePoints)
    handle(end+1) = line(ax,strokePoints(:,1),strokePoints(:,2), ...
        strokePoints(:,3),'Color',color,'LineWidth',lineWidth, ...
        'LineStyle','-','Clipping',source.Clipping);
end
if ~isempty(markerPoints)
    handle(end+1) = line(ax,markerPoints(:,1),markerPoints(:,2), ...
        markerPoints(:,3),'Color',color,'LineStyle','none', ...
        'Marker','.','MarkerSize',max(2,settings.vectorDotMarkerScale*lineWidth), ...
        'Clipping',source.Clipping);
end
end

function [strokePoints,markerPoints] = vector_line_style(polyline,lineStyle,settings)
strokePoints = zeros(0,3);
markerPoints = zeros(0,3);
finitePoints = all(isfinite(polyline),2);
transitions = diff([false;finitePoints;false]);
runStarts = find(transitions == 1);
runEnds = find(transitions == -1)-1;

for k = 1:numel(runStarts)
    run = polyline(runStarts(k):runEnds(k),:);
    switch lineStyle
        case ':'
            spacing = max(1,round(settings.vectorDotSpacingSamples));
            markerPoints = [markerPoints;run(1:spacing:end,:)]; %#ok<AGROW>
        case '--'
            strokePoints = [strokePoints;dash_run(run,settings);nan(1,3)]; %#ok<AGROW>
        case '-.'
            [dashPoints,dotPoints] = dash_dot_run(run,settings);
            strokePoints = [strokePoints;dashPoints;nan(1,3)]; %#ok<AGROW>
            markerPoints = [markerPoints;dotPoints]; %#ok<AGROW>
        otherwise
            strokePoints = [strokePoints;run;nan(1,3)]; %#ok<AGROW>
    end
end
end

function points = dash_run(run,settings)
dashLength = max(1,round(settings.vectorDashSamples));
gapLength = max(1,round(settings.vectorGapSamples));
period = dashLength+gapLength;
points = zeros(0,3);
for first = 1:period:size(run,1)
    last = min(first+dashLength,size(run,1));
    points = [points;run(first:last,:);nan(1,3)]; %#ok<AGROW>
end
end

function [dashPoints,dotPoints] = dash_dot_run(run,settings)
dashLength = max(1,round(settings.vectorDashSamples));
gapLength = max(1,round(settings.vectorGapSamples));
period = dashLength+2*gapLength+1;
dashPoints = zeros(0,3);
dotPoints = zeros(0,3);
for first = 1:period:size(run,1)
    last = min(first+dashLength,size(run,1));
    dashPoints = [dashPoints;run(first:last,:);nan(1,3)]; %#ok<AGROW>
    dotIndex = first+dashLength+gapLength;
    if dotIndex <= size(run,1)
        dotPoints(end+1,:) = run(dotIndex,:); %#ok<AGROW>
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

function settings = plotting_defaults(settings)
defaults.filePrefix = 'simulation';
defaults.showPreview = true;
defaults.previewFigureName = 'PDE simulation';
defaults.previewSurfaceTitles = {'Open-loop state','Closed-loop state'};
defaults.figureSize = [7 3.5];
defaults.lineFigureSize = [3.5 2.35];
defaults.colormap = turbo(256);
defaults.resolution = 600;
defaults.rasterFormat = 'png';
defaults.jpegQuality = 95;
defaults.embedRasterAtNativeResolution = false;
defaults.surfaceAlpha = 1;
defaults.surfaceTimeSamples = 126;
defaults.surfaceSpaceSamples = 50;
defaults.showSpatialLines = false;
defaults.spatialLineCount = 14;
defaults.showTemporalLines = false;
defaults.temporalLineCount = 9;
defaults.showSurfaceLevels = false;
defaults.surfaceLevelCount = 8;
defaults.surfaceLevelValues = [];
defaults.surfaceLevelExcludedValues = [];
defaults.surfaceLevelFlatTolerance = 1e-3;
defaults.surfaceLevelMinRelativeLength = 1e-2;
defaults.alignSurfaceLinesWithTicks = false;
defaults.includeMinorTicksInSurfaceLines = false;
defaults.majorTickLineColor = [0.25 0.25 0.25];
defaults.majorTickLineAlpha = 1;
defaults.majorTickLineWidth = 0.45;
defaults.majorTickLineStyle = '-';
defaults.minorTickLineColor = [0.45 0.45 0.45];
defaults.minorTickLineAlpha = 0.5;
defaults.minorTickLineWidth = 0.25;
defaults.minorTickLineStyle = '-';
defaults.autoExtendMajorTicks = false;
defaults.showZeroTickLabels = false;
defaults.majorTickClearancePixels = 4;
defaults.majorTickCharacterWidth = 0.55;
defaults.majorTickNativeLabelGap = 0.04;
defaults.majorTickLengthMinimum = 0.025;
defaults.majorTickLengthMaximum = 0.25;
defaults.majorTickLengthStep = 0.01;
defaults.majorTickOverlapTimeSamples = 120;
defaults.majorTickOverlapSpaceSamples = 80;
defaults.minorTickLengthScale = 0.5;
defaults.axisNamesInMiddleTickLabels = false;
defaults.tTickValues = [];
defaults.sTickValues = [];
defaults.zTickValues = [];
defaults.tMajorTickSpacing = [];
defaults.sMajorTickSpacing = [];
defaults.zMajorTickSpacing = [];
defaults.tMajorTickOrigin = 0;
defaults.sMajorTickOrigin = 0;
defaults.zMajorTickOrigin = 0;
defaults.tMinorTickValues = [];
defaults.sMinorTickValues = [];
defaults.zMinorTickValues = [];
defaults.tMinorTicksBetweenMajor = 0;
defaults.sMinorTicksBetweenMajor = 0;
defaults.zMinorTicksBetweenMajor = 0;
defaults.openZTickValues = [];
defaults.closedZTickValues = [];
defaults.openZMajorTickSpacing = [];
defaults.closedZMajorTickSpacing = [];
defaults.openZMajorTickOrigin = [];
defaults.closedZMajorTickOrigin = [];
defaults.openZMinorTickValues = [];
defaults.closedZMinorTickValues = [];
defaults.openZMinorTicksBetweenMajor = [];
defaults.closedZMinorTicksBetweenMajor = [];
defaults.axesAtZeroLevel = false;
defaults.tAxisSLocation = 'min';
defaults.sAxisTLocation = 'min';
defaults.positionZAxisOnTZPlane = true;
defaults.zAxisTLocation = 'min';
defaults.vectorizeSurfaceLines = true;
defaults.hiddenSurfaceLineAlphaScale = 0;
defaults.lineVisibilityTolerance = 1e-5;
defaults.lineOcclusionTimeSamples = 80;
defaults.lineOcclusionSpaceSamples = 40;
defaults.lineOcclusionBins = [120 60];
defaults.vectorDashSamples = 8;
defaults.vectorGapSamples = 5;
defaults.vectorDotSpacingSamples = 5;
defaults.vectorDotMarkerScale = 6;
defaults.depthShadeSurfaceLines = true;
defaults.occludeAxesGridBehindSurface = true;
defaults.occludeAxesLinesBehindSurface = true;
defaults.showAxesGrid = false;
defaults.showZGrid = false;
defaults.showTZGrid = false;
defaults.tzGridSLocation = 'max';
defaults.showTZFrame = false;
defaults.tzFrameColor = [0 0 0];
defaults.tzFrameAlpha = 1;
defaults.tzFrameLineWidth = 0.55;
defaults.tzFrameLineStyle = '-';
defaults.showTEndConnector = false;
defaults.tEndConnectorColor = [0 0 0];
defaults.tEndConnectorAlpha = 1;
defaults.tEndConnectorLineWidth = 0.55;
defaults.tEndConnectorLineStyle = '-';
defaults.showAxesBox = true;
defaults.depthShadeAxesGrid = true;
defaults.depthShadeAxesLines = false;
defaults.axesGridColor = [0.82 0.82 0.82];
defaults.axesGridAlpha = 1;
defaults.axesLineWidth = 0.55;
defaults.axesGridLineWidth = 0.55;
defaults.axesGridLineStyle = '-';
defaults.view = [-38 27];
defaults.axisLabels = {'$t$','$s$','$z(t,s)$'};
defaults.panelTitles = {'(a) Open-loop response','(b) Closed-loop response'};
defaults.amplitudeYLabel = '$\max_s |z(t,s)|$';
defaults.amplitudeLegend = {'Open loop','Closed loop'};
defaults.amplitudeTitle = 'Spatial-amplitude comparison';
defaults.signalYLabel = '';
defaults.signalLegend = {'Input','Control'};
defaults.signalTitle = 'Input and control effort';
defaults.colorbarLocation = 'southoutside';
defaults.showColorbar = true;
defaults.fontName = 'Times New Roman';
defaults.fontSize = 8;
defaults.titleFontSize = 8;
defaults.interpreter = 'latex';
defaults.figureBackground = 'white';
defaults.rasterBackground = 'white';
defaults.axesBackground = 'none';
defaults.overlayBackground = 'none';

names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(settings,names{k})
        settings.(names{k}) = defaults.(names{k});
    end
end
end

function idx = sample_indices(numSamples,numSelected)
idx = unique(round(linspace(1,numSamples,min(numSamples,numSelected))));
end

function limits = data_limits(values)
limits = [min(values,[],'all'),max(values,[],'all')];
if limits(1) == limits(2)
    padding = max(1,abs(limits(1)))*1e-6;
    limits = limits+[-padding,padding];
end
end

function delete_temp_files(varargin)
for k = 1:nargin
    if isfile(varargin{k})
        delete(varargin{k});
    end
end
end

function fig = paper_figure(sizeInches,settings)
fig = figure('Color',settings.figureBackground,'Visible','off', ...
    'Units','inches','Position',[1 1 sizeInches],'Renderer','opengl');
end

function format_paper_axes(ax,settings)
set(ax,'FontName',settings.fontName,'FontSize',settings.fontSize, ...
    'TickLabelInterpreter',settings.interpreter);
end
