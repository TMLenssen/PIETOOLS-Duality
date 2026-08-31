function [surfaceHandle,lineHandles,cb] = plot_pde_surface(ax,s,t,z,settings)
%PLOT_PDE_SURFACE Draw one configured PDE response surface on an axes.
%   [SURFACE,LINES,COLORBAR] = PLOT_PDE_SURFACE(AX,S,T,Z,SETTINGS)
%   provides the surface-related capabilities used by
%   GENERATE_PDE_SIMULATION_FIGURES without creating or exporting a figure.
%   Z may be numel(T)-by-numel(S) or its transpose.

if nargin < 5
    settings = struct;
end
settings = default_surface_plot_settings(settings);
if ~isgraphics(ax,'axes')
    error('ax must be a valid axes handle.');
end
[s,t,z] = normalize_surface(s,t,z);
panelTitle = settings.surfaceTitle;

surfaceHandle = draw_surface(ax,t,s,z,settings);
view(ax,settings.view);
configure_camera(ax,settings);
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
    cb.Color = settings.axesColor;
    cb.Label.Color = settings.textColor;
    cb.TickLabelInterpreter = settings.interpreter;
    if settings.zLabelOnColorbar
        cb.Label.Interpreter = settings.interpreter;
        cb.Label.FontName = settings.fontName;
        cb.Label.FontSize = settings.fontSize;
        % Set the string only after its interpreter is active: MATLAB
        % validates text immediately when String is assigned.
        cb.Label.String = settings.axisLabels{3};
    end
end
xlabel(ax,settings.axisLabels{1},'Interpreter',settings.interpreter);
ylabel(ax,settings.axisLabels{2},'Interpreter',settings.interpreter);
if isempty(cb) || ~settings.zLabelOnColorbar
    zlabel(ax,settings.axisLabels{3},'Interpreter',settings.interpreter);
else
    zlabel(ax,'');
end
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
apply_tick_values(ax,settings);
set(ax,'XLimMode','manual','YLimMode','manual', ...
    'ZLimMode','manual','CLimMode','manual');
orient_camera_up(ax,settings);
drawnow;
synchronize_colorbar_ticks(cb,ax);
settings = resolve_axis_locations(ax,settings);
position_axes_at_zero(ax,settings);
lineHandles = draw_surface_lines(ax,t,s,z,settings);
lineHandles = [lineHandles;draw_z_plane_lines(ax,t,s,settings)];
combine_z_intersection_tick_labels(ax,settings);
prepare_axis_names_in_middle_ticks(ax,cb,settings);
lineHandles = [lineHandles;apply_manual_tick_lengths(ax,settings)];
end

function configure_camera(ax,settings)
projection = validatestring(settings.projection, ...
    {'orthographic','perspective'},mfilename,'settings.projection');
ax.Projection = projection;
orient_camera_up(ax,settings);
if isempty(settings.cameraViewAngle)
    ax.CameraViewAngleMode = 'auto';
    return
end
angle = settings.cameraViewAngle;
if ~isscalar(angle) || ~isfinite(angle) || angle <= 0 || angle >= 180
    error('cameraViewAngle must be empty or a scalar strictly between 0 and 180.');
end
ax.CameraViewAngle = angle;
ax.CameraViewAngleMode = 'manual';
end

function orient_camera_up(ax,settings)
keepVertical = settings.keepZAxisVertical;
validLogical = islogical(keepVertical) && isscalar(keepVertical);
validNumeric = isnumeric(keepVertical) && isscalar(keepVertical) && ...
    isfinite(keepVertical) && ismember(keepVertical,[0 1]);
if ~(validLogical || validNumeric)
    error('keepZAxisVertical must be a logical scalar.');
end
if ~logical(keepVertical)
    return
end

viewDirection = ax.CameraTarget-ax.CameraPosition;
viewDirection = viewDirection/norm(viewDirection);
zDirection = [0 0 1];
if norm(cross(viewDirection,zDirection)) > 1e-10
    ax.CameraUpVector = zDirection;
else
    % In an exact top/bottom view the z-axis projects to a point, so its
    % screen direction is undefined. Use the spatial axis as a stable up
    % direction and return to z-up as soon as the view tilts away again.
    ax.CameraUpVector = [0 1 0];
end
ax.CameraUpVectorMode = 'manual';
end

function settings = resolve_axis_locations(ax,settings)
% Put rulers on the foreground edges unless a boundary is requested.
settings.tAxisSLocation = resolve_axis_location( ...
    settings.tAxisSLocation,ax.CameraPosition(2),ax.CameraTarget(2), ...
    'tAxisSLocation');
settings.sAxisTLocation = resolve_axis_location( ...
    settings.sAxisTLocation,ax.CameraPosition(1),ax.CameraTarget(1), ...
    'sAxisTLocation');
[settings.zPlaneLocation,settings.resolvedZAxisTLocation, ...
    settings.resolvedZAxisSLocation,settings.resolvedZAxisEdgeAxis] = ...
    resolve_z_plane_geometry(settings.zPlaneLocation, ...
    settings.tAxisSLocation,settings.sAxisTLocation, ...
    ax.CameraPosition,ax.CameraTarget);
end

function location = resolve_axis_location(location,cameraValue,targetValue,name)
location = validatestring(location,{'auto','min','max'}, ...
    mfilename,['settings.',name]);
if ~strcmpi(location,'auto')
    return
end

offset = cameraValue-targetValue;
tolerance = 1e-12*max([1,abs(cameraValue),abs(targetValue)]);
if offset > tolerance
    location = 'max';
else
    % Use the minimum edge when the camera is on the negative side or when
    % both edges are equivalent in an exactly perpendicular view.
    location = 'min';
end
end

function [planeLocation,tLocation,sLocation,edgeAxis] = ...
        resolve_z_plane_geometry(planeAxis,tAxisSLocation,sAxisTLocation, ...
        cameraPosition,cameraTarget)
planeAxis = validatestring(planeAxis,{'s','t'}, ...
    mfilename,'settings.zPlaneLocation');
switch planeAxis
    case 's'
        % The wall is on the s boundary farthest from the camera. Its
        % t-coordinate follows the s-axis so the z-axis intersects it.
        foregroundSide = resolve_axis_location('auto',cameraPosition(2), ...
            cameraTarget(2),'zPlaneLocation');
        planeSide = opposite_axis_location(foregroundSide);
        tLocation = sAxisTLocation;
        sLocation = planeSide;
        edgeAxis = 't';
    case 't'
        % The wall is on the t boundary farthest from the camera. Its
        % s-coordinate follows the t-axis so the z-axis intersects it.
        foregroundSide = resolve_axis_location('auto',cameraPosition(1), ...
            cameraTarget(1),'zPlaneLocation');
        planeSide = opposite_axis_location(foregroundSide);
        tLocation = planeSide;
        sLocation = tAxisSLocation;
        edgeAxis = 's';
end
planeLocation = [planeAxis,planeSide];
end

function location = opposite_axis_location(location)
switch lower(location)
    case 'min'
        location = 'max';
    case 'max'
        location = 'min';
    otherwise
        error('Axis boundary location must be ''min'' or ''max''.')
end
end

function synchronize_colorbar_ticks(cb,ax)
if isempty(cb) || ~isgraphics(cb)
    return
end

% Use one numerical and textual tick lattice for height and color.
cb.Ticks = ax.ZTick;
cb.TickLabels = ax.ZTickLabel;
end

function surfaceHandle = draw_surface(ax,t,s,z,settings)
surfaceHandle = surf(ax,t,s,z.','FaceColor','interp', ...
    'EdgeColor','none','FaceAlpha',settings.surfaceAlpha);
colormap(ax,settings.colormap);
end

function lineHandles = draw_surface_lines(ax,t,s,z,settings)
hold(ax,'on');
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

function lineHandles = draw_z_plane_lines(ax,t,s,settings)
lineHandles = gobjects(0,1);
if ~settings.showTZGrid && ~settings.showTZFrame && ...
        ~settings.showTEndConnector && ~settings.showTZeroConnector
    return
end

planeLocation = validatestring(settings.zPlaneLocation, ...
    {'smin','smax','tmin','tmax'},mfilename,'settings.zPlaneLocation');
planeSide = planeLocation(2:end);
zLimits = ax.ZLim;
switch planeLocation(1)
    case 's'
        fixedValue = axis_boundary(ax.YLim,planeSide);
        freeValues = t(:);
        planePoints = @(values,zValues) ...
            [values(:),fixedValue*ones(numel(values),1),zValues(:)];
    case 't'
        fixedValue = axis_boundary(ax.XLim,planeSide);
        freeValues = s(:);
        planePoints = @(values,zValues) ...
            [fixedValue*ones(numel(values),1),values(:),zValues(:)];
end

hold(ax,'on');
if settings.showTZGrid
    zValues = ticks_in_interval(ax.ZTick,ax.ZLim);
    for k = 1:numel(zValues)
        points = planePoints(freeValues, ...
            zValues(k)*ones(size(freeValues)));
        lineHandles(end+1,1) = plot3(ax, ...
            points(:,1),points(:,2),points(:,3), ...
            'Color',[settings.axesGridColor,settings.axesGridAlpha], ...
            'LineWidth',settings.axesGridLineWidth, ...
            'LineStyle',settings.axesGridLineStyle, ...
            'Tag','TZGridLine'); %#ok<AGROW>
    end
end
if settings.showTZFrame
    freeLimits = [min(freeValues),max(freeValues)];
    zSamples = linspace(zLimits(1),zLimits(2), ...
        max(40,numel(freeValues))).';
    frameSegments = {
        planePoints(freeValues,zLimits(1)*ones(size(freeValues)));
        planePoints(freeValues,zLimits(2)*ones(size(freeValues)));
        planePoints(freeLimits(1)*ones(size(zSamples)),zSamples);
        planePoints(freeLimits(2)*ones(size(zSamples)),zSamples)};
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
    connectorT = axis_boundary( ...
        ax.XLim,settings.resolvedZAxisTLocation);
    lineHandles(end+1,1) = plot3(ax, ...
        connectorT*ones(size(s)),s,zeros(size(s)), ...
        'Color',[settings.tEndConnectorColor,settings.tEndConnectorAlpha], ...
        'LineWidth',settings.tEndConnectorLineWidth, ...
        'LineStyle',settings.tEndConnectorLineStyle, ...
        'Tag','TEndConnectorLine');
end
if settings.showTZeroConnector && planeLocation(1) == 's' && ...
        ax.XLim(1) <= 0 && ax.XLim(2) >= 0
    lineHandles(end+1,1) = plot3(ax, ...
        zeros(size(s)),s,zeros(size(s)), ...
        'Color',[settings.tEndConnectorColor,settings.tEndConnectorAlpha], ...
        'LineWidth',settings.tEndConnectorLineWidth, ...
        'LineStyle',settings.tEndConnectorLineStyle, ...
        'Tag','TZeroConnectorLine');
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

levelTicks = ax.ZTick;
if settings.includeMinorTicksInSurfaceLines
    levelTicks = [levelTicks,ax.ZRuler.MinorTickValues];
end
values = ticks_in_interval(levelTicks,z(isfinite(z)));
showZero = settings.showZeroSurfaceLevel;
validLogical = islogical(showZero) && isscalar(showZero);
validNumeric = isnumeric(showZero) && isscalar(showZero) && ...
    isfinite(showZero) && ismember(showZero,[0 1]);
if ~(validLogical || validNumeric)
    error('showZeroSurfaceLevel must be a logical scalar.');
end
if ~logical(showZero)
    values(arrayfun(@(value)is_tick_value(value,0),values)) = [];
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
% MATLAB can swap the first crossover axis after an azimuth change. Lock
% the order used below: first=x/t and second=y/s.
if isprop(ax.ZRuler,'FirstCrossoverAxis')
    ax.ZRuler.FirstCrossoverAxis = 0;
end
ax.ZRuler.FirstCrossoverValue = axis_boundary( ...
    ax.XLim,settings.resolvedZAxisTLocation);
ax.ZRuler.SecondCrossoverValue = axis_boundary( ...
    ax.YLim,settings.resolvedZAxisSLocation);
end

function apply_tick_values(ax,settings)
configure_ruler_ticks(ax.XRuler,ax.XLim,settings.tTickValues, ...
    settings.tMajorTickSpacing,settings.tMajorTickOrigin, ...
    settings.tMinorTickValues,settings.tMinorTicksBetweenMajor);
configure_ruler_ticks(ax.YRuler,ax.YLim,settings.sTickValues, ...
    settings.sMajorTickSpacing,settings.sMajorTickOrigin, ...
    settings.sMinorTickValues,settings.sMinorTicksBetweenMajor);
configure_ruler_ticks(ax.ZRuler,ax.ZLim,settings.zTickValues, ...
    settings.zMajorTickSpacing,settings.zMajorTickOrigin, ...
    settings.zMinorTickValues,settings.zMinorTicksBetweenMajor);
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

function lineHandles = apply_manual_tick_lengths(ax,settings)
% MATLAB couples major and minor 3-D tick lengths. Apply the requested
% major-tick lengths natively, then draw the minor ticks at a scaled length.
lineHandles = gobjects(0,1);
if isempty(settings.majorTickLength)
    return
end

rulers = {ax.XRuler,ax.YRuler,ax.ZRuler};
nativeLengths = zeros(1,numel(rulers));
for k = 1:numel(rulers)
    ruler = rulers{k};
    tickLength = ruler.TickLength;
    nativeLengths(k) = tickLength(2);
    targetLength = axis_setting_value( ...
        settings.majorTickLength,k,'majorTickLength');
    tickLength(2) = targetLength;
    ruler.TickLength = tickLength;
    ruler.TickDirection = 'out';
end

if settings.axesAtZeroLevel
    lineHandles = draw_minor_tick_lines(ax,settings,nativeLengths);
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

function combine_z_intersection_tick_labels(ax,settings)
if ~settings.combineZIntersectionTickLabels || ~settings.axesAtZeroLevel
    return
end

[zLabels,zIndex] = labels_and_index(ax.ZRuler,0);
if isempty(zIndex)
    return
end

t0 = ax.ZRuler.FirstCrossoverValue;
s0 = ax.ZRuler.SecondCrossoverValue;
if settings.resolvedZAxisEdgeAxis == 't'
    otherRuler = ax.YRuler;
    otherValue = s0;
else
    otherRuler = ax.XRuler;
    otherValue = t0;
end
[otherLabels,otherIndex] = labels_and_index(otherRuler,otherValue);
if isempty(otherIndex)
    return
end

zValue = clean_label_text(zLabels(zIndex));
otherValue = clean_label_text(otherLabels(otherIndex));
combined = "("+otherValue+","+zValue+")";
if strcmpi(settings.interpreter,'latex')
    combined = "$"+combined+"$";
end
zLabels(zIndex) = combined;
ax.ZRuler.TickLabels = cellstr(zLabels);
% The z ruler owns the shared mark. Remove the coincident t/s tick instead
% of merely hiding its label, otherwise two independently sized ticks are
% drawn on top of one another.
otherTicks = reshape(otherRuler.TickValues,1,[]);
otherTicks(otherIndex) = [];
otherLabels(otherIndex) = [];
otherRuler.TickValues = otherTicks;
otherRuler.TickLabels = cellstr(otherLabels);
end

function [labels,index] = labels_and_index(ruler,value)
ticks = ruler.TickValues(:).';
tolerance = 1e-10*max([1,abs(value),abs(ticks)]);
index = find(abs(ticks-value) <= tolerance,1);
labels = reshape(string(ruler.TickLabels),1,[]);
if numel(labels) ~= numel(ticks)
    labels = string(ticks);
end
end

function text = clean_label_text(text)
text = erase(join(string(text),""),"$");
end

function prepare_axis_names_in_middle_ticks(ax,cb,settings)
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

% When the z label has been moved to the colorbar, treat its major ticks as
% the z tick labels and merge the name into the middle one in the same way.
if isempty(cb) || ~isgraphics(cb) || isempty(cb.Label.String) || ...
        ~any(strlength(string(cb.Label.String)) > 0) || isempty(cb.Ticks)
    return
end
ticks = cb.Ticks(:).';
middleIndex = middle_tick_index(ticks,ax.ZLim);
tickLabels = reshape(string(cb.TickLabels),1,[]);
if numel(tickLabels) ~= numel(ticks)
    tickLabels = string(ticks);
end
valueText = clean_label_text(tickLabels(middleIndex));
axisName = clean_label_text(cb.Label.String);
tickLabels(middleIndex) = "$"+axisName+"="+valueText+"$";
cb.TickLabels = cellstr(tickLabels);
cb.Label.String = '';
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
zAxisT = axis_boundary(ax.XLim,settings.resolvedZAxisTLocation);
zAxisS = axis_boundary(ax.YLim,settings.resolvedZAxisSLocation);
zTipT = zAxisT;
zTipS = zAxisS;
if settings.resolvedZAxisEdgeAxis == 't'
    zTipT = outward_tick_tip(ax.XLim,settings.resolvedZAxisTLocation, ...
        originalLengths(3)*settings.minorTickLengthScale);
else
    zTipS = outward_tick_tip(ax.YLim,settings.resolvedZAxisSLocation, ...
        originalLengths(3)*settings.minorTickLengthScale);
end

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
    lineHandles(end+1,1) = plot3(ax,[zAxisT,zTipT],[zAxisS,zTipS], ...
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


function limits = data_limits(values)
limits = [min(values,[],'all'),max(values,[],'all')];
if limits(1) == limits(2)
    padding = max(1,abs(limits(1)))*1e-6;
    limits = limits+[-padding,padding];
end
end

function format_paper_axes(ax,settings)
set(ax,'FontName',settings.fontName,'FontSize',settings.fontSize, ...
    'TickLabelInterpreter',settings.interpreter, ...
    'Color',settings.figureBackground, ...
    'XColor',settings.axesColor,'YColor',settings.axesColor, ...
    'ZColor',settings.axesColor);
ax.XRuler.TickLabelColor = settings.textColor;
ax.YRuler.TickLabelColor = settings.textColor;
ax.ZRuler.TickLabelColor = settings.textColor;
ax.XLabel.Color = settings.textColor;
ax.YLabel.Color = settings.textColor;
ax.ZLabel.Color = settings.textColor;
ax.Title.Color = settings.textColor;
end

function [s,t,z] = normalize_surface(s,t,z)
s = s(:);
t = t(:);
if isequal(size(z),[numel(t),numel(s)])
    return
end
if isequal(size(z),[numel(s),numel(t)])
    z = z.';
    return
end
error('z must have size numel(t)-by-numel(s), or its transpose.');
end
