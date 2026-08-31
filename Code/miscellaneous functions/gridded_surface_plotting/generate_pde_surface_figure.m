function fileName = generate_pde_surface_figure(fileName,s,t,z,settings)
%GENERATE_PDE_SURFACE_FIGURE Plot and export one PDE response surface.
%   FILE = GENERATE_PDE_SURFACE_FIGURE(FILE,S,T,Z) writes a high-resolution
%   rasterized PDF containing the complete rendered figure.
%
%   FILE = GENERATE_PDE_SURFACE_FIGURE(...,SETTINGS) accepts the same
%   surface-related settings as GENERATE_PDE_SIMULATION_FIGURES. Set
%   SETTINGS.surfaceTitle for the title.

if nargin < 5
    settings = struct;
end
settings = default_surface_plot_settings(settings);
[s,t,z] = normalize_surface(s,t,z);

[outDir,name,extension] = fileparts(fileName);
if isempty(extension)
    extension = '.pdf';
end
if ~strcmpi(extension,'.pdf')
    error('The surface figure output must be a PDF file.');
end
if isempty(outDir)
    outDir = pwd;
end
if ~isfolder(outDir)
    mkdir(outDir);
end
fileName = fullfile(outDir,[name,extension]);

timeIdx = sample_indices(numel(t),settings.surfaceTimeSamples);
spaceIdx = sample_indices(numel(s),settings.surfaceSpaceSamples);
t = t(timeIdx);
s = s(spaceIdx);
z = z(timeIdx,spaceIdx);

boxSize = validate_box_size(settings.surfaceBoundingBoxSize);
fig = figure('Color',settings.figureBackground,'Visible','off', ...
    'Units','inches','Position',[1 1 boxSize+[2 2]],'Renderer','opengl');
closeFigure = onCleanup(@()close_valid_figure(fig));
ax = axes(fig,'Units','inches');
[surfaceHandle,lineHandles,cb] = plot_pde_surface(ax,s,t,z,settings);
layout_surface_figure(fig,ax,cb,surfaceHandle,lineHandles,boxSize,settings);
drawnow;
export_pde_surface_pdf(fig,fileName,settings);
close(fig);
clear closeFigure
end

function layout_surface_figure(fig,ax,cb,surfaceHandle,lineHandles,boxSize,settings)
% Use absolute-inch geometry so changing the colorbar side does not change
% the requested surface box. Axes decorations are measured after rendering.
padding = validate_nonnegative_scalar(settings.layoutPadding,'layoutPadding');
titleGap = validate_nonnegative_scalar(settings.titleGap,'titleGap');
gap = validate_finite_scalar(settings.colorbarGap,'colorbarGap');
thickness = validate_positive_scalar( ...
    settings.colorbarThickness,'colorbarThickness');
tickMargin = validate_nonnegative_scalar( ...
    settings.colorbarTickLabelMargin,'colorbarTickLabelMargin');

if isempty(cb)
    location = 'none';
else
    location = lower(char(settings.colorbarLocation));
end

ax.Units = 'inches';
ax.Clipping = 'off';
if isprop(ax,'PositionConstraint')
    ax.PositionConstraint = 'innerposition';
end
if isprop(ax,'TitleHorizontalAlignment')
    ax.TitleHorizontalAlignment = 'center';
end
% Force the colorbar into manual positioning before fixing the axes box.
if ~isempty(cb)
    cb.Units = 'inches';
    if ismember(location,{'north','south','northoutside','southoutside'})
        cb.Position = [padding padding boxSize(1) thickness];
    else
        cb.Position = [padding padding thickness boxSize(2)];
    end
end
ax.Position = [1 1 boxSize];
drawnow;

% Locate the rendered surface and explicit 3-D lines in the axes viewport.
% In a perspective view their bounding rectangle is generally smaller than
% the axes Position, so the visible plot drives title and colorbar alignment.
projectedBox = projected_plot_box(ax,surfaceHandle,lineHandles,boxSize);

hasTitle = ~isempty(ax.Title.String) && ...
    any(strlength(string(ax.Title.String)) > 0);
if hasTitle
    % Put the complete title above the box instead of letting MATLAB overlap
    % its lower half with the axes rectangle.
    ax.Title.Units = 'inches';
    ax.Title.HorizontalAlignment = 'center';
    ax.Title.VerticalAlignment = 'bottom';
    ax.Title.Position = [projectedBox.centerX, ...
        projectedBox.top+titleGap,0];
    drawnow;
    titleExtent = ax.Title.Extent;
    titleHeight = titleExtent(4);
    titleBand = titleGap+titleHeight;
else
    titleExtent = [];
    titleBand = 0;
end
tight = max(ax.TightInset,0);
left = tight(1);
bottom = tight(2);
right = tight(3);
titleTop = projectedBox.top+titleBand;

% Work in coordinates relative to the axes, then translate the complete
% layout into the figure. This makes all eight colorbar locations obey the
% same projected-box geometry without changing the requested axes size.
% TightInset is used as decoration clearance around the projected plot,
% rather than around the larger MATLAB axes viewport. This omits empty
% camera viewport regions from the exported page.
contentLeft = projectedBox.left-left;
contentBottom = projectedBox.bottom-bottom;
% Endpoint tick labels can extend beyond MATLAB's reported right inset in
% a perspective view. Reserve two font heights so they remain unclipped.
rightLabelClearance = 2*settings.fontSize/72;
contentRight = projectedBox.left+projectedBox.width+right+ ...
    rightLabelClearance;
contentTop = projectedBox.top+tight(4);
% Custom 3-D crossover rulers are not represented reliably by TightInset.
% Include every visible tick label using its rendered axis side and the
% ruler's actual (possibly manually specified) major-tick length.
tickLabelBounds = tick_label_export_bounds(ax,boxSize,settings);
% MATLAB can place crossover tick text slightly beyond its documented
% extent. Keep one font height of safety around the measured estimate.
tickLabelSafety = settings.fontSize/72;
contentLeft = min(contentLeft,tickLabelBounds(1)-tickLabelSafety);
contentBottom = min(contentBottom,tickLabelBounds(2)-tickLabelSafety);
contentRight = max(contentRight,tickLabelBounds(3)+tickLabelSafety);
contentTop = max(contentTop,tickLabelBounds(4)+tickLabelSafety);
% The configured bounding-box width, rather than the narrower projected
% mesh or the wider tick-label extent, determines horizontal bar length.
plotBoxWidth = boxSize(1);
plotBoxLeft = projectedBox.centerX-plotBoxWidth/2;
if ~isempty(titleExtent)
    contentLeft = min(contentLeft,titleExtent(1));
    contentBottom = min(contentBottom,titleExtent(2));
    contentRight = max(contentRight,titleExtent(1)+titleExtent(3));
    contentTop = max(contentTop,titleExtent(2)+titleExtent(4));
end
% TightInset is unreliable for rotated 3-D labels and custom ruler
% crossover locations. Include the labels' actual rendered rectangles.
labelExtents = axis_label_extents_in_inches(ax);
labelPadding = 0.5*settings.fontSize/72;
for k = 1:size(labelExtents,1)
    extent = labelExtents(k,:);
    contentLeft = min(contentLeft,extent(1)-labelPadding);
    contentBottom = min(contentBottom,extent(2)-labelPadding);
    contentRight = max(contentRight,extent(1)+extent(3)+labelPadding);
    contentTop = max(contentTop,extent(2)+extent(4)+labelPadding);
end

switch location
    case 'westoutside'
        cbRelative = [contentLeft-gap-thickness, ...
            projectedBox.bottom,thickness,titleTop-projectedBox.bottom];
        contentLeft = min(contentLeft,cbRelative(1)-tickMargin);
        contentBottom = min(contentBottom,cbRelative(2));
        contentTop = max(contentTop,cbRelative(2)+cbRelative(4));
    case 'eastoutside'
        cbRelative = [contentRight+gap,projectedBox.bottom,thickness, ...
            titleTop-projectedBox.bottom];
        contentRight = max(contentRight, ...
            cbRelative(1)+cbRelative(3)+tickMargin);
        contentBottom = min(contentBottom,cbRelative(2));
        contentTop = max(contentTop,cbRelative(2)+cbRelative(4));
    case 'southoutside'
        cbRelative = [plotBoxLeft,contentBottom-gap-thickness, ...
            plotBoxWidth,thickness];
        contentLeft = min(contentLeft,cbRelative(1));
        contentRight = max(contentRight,cbRelative(1)+cbRelative(3));
        contentBottom = min(contentBottom,cbRelative(2)-tickMargin);
    case 'northoutside'
        cbRelative = [plotBoxLeft,max(contentTop,titleTop)+gap, ...
            plotBoxWidth,thickness];
        contentLeft = min(contentLeft,cbRelative(1));
        contentRight = max(contentRight,cbRelative(1)+cbRelative(3));
        contentTop = max(contentTop, ...
            cbRelative(2)+cbRelative(4)+tickMargin);
    case 'west'
        cbRelative = [projectedBox.left+gap,projectedBox.bottom, ...
            thickness,projectedBox.height];
    case 'east'
        cbRelative = [projectedBox.left+projectedBox.width-gap-thickness, ...
            projectedBox.bottom,thickness,projectedBox.height];
    case 'south'
        cbRelative = [plotBoxLeft,projectedBox.bottom+gap, ...
            plotBoxWidth,thickness];
    case 'north'
        cbRelative = [plotBoxLeft,projectedBox.top-gap-thickness, ...
            plotBoxWidth,thickness];
    otherwise
        cbRelative = [];
end

% A negative gap can move either an inside or outside colorbar across the
% nominal plot boundary. Include its actual rectangle in the layout on all
% sides, then reserve tick-label space on the side associated with the
% requested location. For nonnegative gaps these bounds reduce to the
% existing layout in the usual cases.
if ~isempty(cbRelative)
    contentLeft = min(contentLeft,cbRelative(1));
    contentBottom = min(contentBottom,cbRelative(2));
    contentRight = max(contentRight,cbRelative(1)+cbRelative(3));
    contentTop = max(contentTop,cbRelative(2)+cbRelative(4));
    switch location
        case {'west','westoutside'}
            contentLeft = min(contentLeft,cbRelative(1)-tickMargin);
        case {'east','eastoutside'}
            contentRight = max(contentRight, ...
                cbRelative(1)+cbRelative(3)+tickMargin);
        case {'south','southoutside'}
            contentBottom = min(contentBottom,cbRelative(2)-tickMargin);
        case {'north','northoutside'}
            contentTop = max(contentTop, ...
                cbRelative(2)+cbRelative(4)+tickMargin);
    end
end

axX = padding-contentLeft;
axY = padding-contentBottom;
figureSize = [contentRight-contentLeft+2*padding, ...
    contentTop-contentBottom+2*padding];
if isempty(cbRelative)
    cbPosition = [];
else
    cbPosition = cbRelative+[axX axY 0 0];
end
fig.Position(3:4) = figureSize;
ax.Position = [axX axY boxSize];
if hasTitle
    % Axes relocation can reactivate MATLAB's automatic 3-D title placement.
    % Reapply the box-relative position after the final axes move.
    ax.Title.Units = 'inches';
    ax.Title.HorizontalAlignment = 'center';
    ax.Title.VerticalAlignment = 'bottom';
    ax.Title.Position = [projectedBox.centerX, ...
        projectedBox.top+titleGap,0];
end
if ~isempty(cb) && ~isempty(cbPosition)
    cb.Position = cbPosition;
end
drawnow;
expand_figure_for_colorbar_label(fig,ax,cb,padding,labelPadding);
drawnow;
add_render_safety_margin(fig,ax,cb);
drawnow;
end

function add_render_safety_margin(fig,ax,cb)
% Give all crossover labels room to render before content-aware cropping.
margin = 0.25;
fig.Position(3:4) = fig.Position(3:4)+2*margin;
ax.Position(1:2) = ax.Position(1:2)+margin;
if ~isempty(cb) && isgraphics(cb)
    cb.Position(1:2) = cb.Position(1:2)+margin;
end
end

function expand_figure_for_colorbar_label(fig,ax,cb,padding,labelPadding)
% Include the colorbar label's measured rectangle without adding a fixed
% margin to colorbars that do not need it.
if isempty(cb) || ~isgraphics(cb) || isempty(cb.Label.String) || ...
        ~any(strlength(string(cb.Label.String)) > 0)
    return
end

oldUnits = cb.Label.Units;
cb.Label.Units = 'inches';
drawnow;
extent = cb.Label.Extent;
cb.Label.Units = oldUnits;
if numel(extent) ~= 4 || any(~isfinite(extent)) || ...
        any(extent(3:4) < 0)
    return
end

% Text extents are relative to the colorbar; convert to figure inches.
bounds = [cb.Position(1:2)+extent(1:2),extent(3:4)];
figureSize = fig.Position(3:4);
clearance = padding+labelPadding;
leftExtra = max(0,clearance-bounds(1));
bottomExtra = max(0,clearance-bounds(2));
rightExtra = max(0,bounds(1)+bounds(3)-(figureSize(1)-clearance));
topExtra = max(0,bounds(2)+bounds(4)-(figureSize(2)-clearance));
if ~any([leftExtra,bottomExtra,rightExtra,topExtra] > 0)
    return
end

shift = [leftExtra,bottomExtra];
fig.Position(3:4) = figureSize+[leftExtra+rightExtra, ...
    bottomExtra+topExtra];
ax.Position(1:2) = ax.Position(1:2)+shift;
cb.Position(1:2) = cb.Position(1:2)+shift;
end

function extents = axis_label_extents_in_inches(ax)
labels = [ax.XLabel,ax.YLabel,ax.ZLabel];
extents = zeros(0,4);
for k = 1:numel(labels)
    label = labels(k);
    if isempty(label.String) || ...
            ~any(strlength(string(label.String)) > 0)
        continue
    end
    oldUnits = label.Units;
    label.Units = 'inches';
    drawnow;
    extent = label.Extent;
    label.Units = oldUnits;
    if numel(extent) == 4 && all(isfinite(extent)) && ...
            all(extent(3:4) >= 0)
        extents(end+1,:) = extent; %#ok<AGROW>
    end
end
end

function box = projected_plot_box(ax,surfaceHandle,lineHandles,viewportSize)
% Return screen-space bounds of plotted 3-D geometry, relative to the axes.
points = surface_points(surfaceHandle);
for k = 1:numel(lineHandles)
    if isgraphics(lineHandles(k),'line')
        linePoints = [lineHandles(k).XData(:),lineHandles(k).YData(:), ...
            lineHandles(k).ZData(:)];
        points = [points;linePoints]; %#ok<AGROW>
    end
end
points = points(all(isfinite(points),2),:);
if isempty(points)
    [xCorner,yCorner,zCorner] = ndgrid(ax.XLim,ax.YLim,ax.ZLim);
    points = [xCorner(:),yCorner(:),zCorner(:)];
end

[x,y] = project_points_to_viewport(ax,points,viewportSize);
box.left = min(x);
box.bottom = min(y);
box.width = max(x)-box.left;
box.height = max(y)-box.bottom;
box.top = box.bottom+box.height;
box.centerX = box.left+box.width/2;
end

function bounds = tick_label_export_bounds(ax,viewportSize,settings)
bounds = [inf,inf,-inf,-inf];
if ~settings.axesAtZeroLevel
    return
end

rulers = {ax.XRuler,ax.YRuler,ax.ZRuler};
for rulerIndex = 1:numel(rulers)
    ruler = rulers{rulerIndex};
    ticks = reshape(ruler.TickValues,1,[]);
    labels = reshape(string(ruler.TickLabels),1,[]);
    if isempty(ticks) || isempty(labels)
        continue
    end
    if numel(labels) ~= numel(ticks)
        labels = string(ticks);
    end
    visible = strlength(labels) > 0;
    if ~any(visible)
        continue
    end
    ticks = ticks(visible);
    labels = labels(visible);
    [anchors,directionPoints] = major_tick_export_geometry( ...
        ax,rulerIndex,ticks,1,settings);
    [anchorX,anchorY] = project_points_to_viewport( ...
        ax,anchors,viewportSize);
    [directionX,directionY] = project_points_to_viewport( ...
        ax,directionPoints,viewportSize);
    direction = [directionX-anchorX,directionY-anchorY];
    directionNorm = hypot(direction(:,1),direction(:,2));
    validDirection = directionNorm > eps;
    direction(validDirection,:) = direction(validDirection,:)./ ...
        directionNorm(validDirection);
    direction(~validDirection,:) = 0;
    % MATLAB defines 3-D TickLength relative to the shorter axes-viewport
    % dimension, not independently in each data direction.
    screenTickLength = ruler.TickLength(2)*min(viewportSize);
    tipX = anchorX+screenTickLength*direction(:,1);
    tipY = anchorY+screenTickLength*direction(:,2);

    fontHeight = ruler.FontSize/72;
    labelGap = 0.5*fontHeight;
    labelPadding = 0.5*fontHeight;
    for k = 1:numel(ticks)
        labelText = erase(labels(k),"$");
        labelWidth = 0.55*fontHeight*max(1,double(strlength(labelText)));
        labelHeight = 1.25*fontHeight;
        centerX = tipX(k)+direction(k,1)*(labelGap+labelWidth/2);
        centerY = tipY(k)+direction(k,2)*(labelGap+labelHeight/2);
        bounds(1) = min(bounds(1),centerX-labelWidth/2-labelPadding);
        bounds(2) = min(bounds(2),centerY-labelHeight/2-labelPadding);
        bounds(3) = max(bounds(3),centerX+labelWidth/2+labelPadding);
        bounds(4) = max(bounds(4),centerY+labelHeight/2+labelPadding);
    end
end
end

function [anchors,tips] = major_tick_export_geometry( ...
        ax,rulerIndex,ticks,normalizedLength,settings)
switch rulerIndex
    case 1
        boundary = ax.XRuler.FirstCrossoverValue;
        anchors = [ticks(:),boundary*ones(numel(ticks),1), ...
            zeros(numel(ticks),1)];
        tips = anchors;
        tips(:,2) = boundary+outward_sign(ax.YLim,boundary)* ...
            normalizedLength*diff(ax.YLim);
    case 2
        boundary = ax.YRuler.FirstCrossoverValue;
        anchors = [boundary*ones(numel(ticks),1),ticks(:), ...
            zeros(numel(ticks),1)];
        tips = anchors;
        tips(:,1) = boundary+outward_sign(ax.XLim,boundary)* ...
            normalizedLength*diff(ax.XLim);
    case 3
        tBoundary = ax.ZRuler.FirstCrossoverValue;
        sBoundary = ax.ZRuler.SecondCrossoverValue;
        anchors = [tBoundary*ones(numel(ticks),1), ...
            sBoundary*ones(numel(ticks),1),ticks(:)];
        tips = anchors;
        if strcmpi(settings.zPlaneLocation,'s')
            tips(:,1) = tBoundary+outward_sign(ax.XLim,tBoundary)* ...
                normalizedLength*diff(ax.XLim);
        else
            tips(:,2) = sBoundary+outward_sign(ax.YLim,sBoundary)* ...
                normalizedLength*diff(ax.YLim);
        end
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

function [x,y] = project_points_to_viewport(ax,points,viewportSize)

scale = reshape(ax.DataAspectRatio,1,3);
cameraPosition = ax.CameraPosition./scale;
cameraTarget = ax.CameraTarget./scale;
cameraUp = ax.CameraUpVector./scale;
forward = cameraTarget-cameraPosition;
forward = forward/norm(forward);
right = cross(forward,cameraUp);
right = right/norm(right);
up = cross(right,forward);

relative = points./scale-cameraPosition;
horizontal = relative*right.';
vertical = relative*up.';
targetDistance = dot(cameraTarget-cameraPosition,forward);
halfHeight = targetDistance*tand(ax.CameraViewAngle/2);
if strcmpi(ax.Projection,'perspective')
    depth = relative*forward.';
    if any(depth <= 0)
        error('The camera lies inside or behind the plotted data box.');
    end
    horizontal = horizontal./depth;
    vertical = vertical./depth;
    halfHeight = tand(ax.CameraViewAngle/2);
end

halfWidth = halfHeight*viewportSize(1)/viewportSize(2);
if ~isfinite(halfWidth) || ~isfinite(halfHeight) || ...
        halfWidth <= 0 || halfHeight <= 0
    error('Unable to determine the projected 3-D data-box bounds.');
end
x = viewportSize(1)/2+horizontal*viewportSize(1)/(2*halfWidth);
y = viewportSize(2)/2+vertical*viewportSize(2)/(2*halfHeight);
end

function points = surface_points(surfaceHandle)
if ~isgraphics(surfaceHandle,'surface')
    points = zeros(0,3);
    return
end
z = surfaceHandle.ZData;
x = surfaceHandle.XData;
y = surfaceHandle.YData;
if isvector(x)
    x = repmat(x(:).',size(z,1),1);
end
if isvector(y)
    y = repmat(y(:),1,size(z,2));
end
points = [x(:),y(:),z(:)];
end

function boxSize = validate_box_size(boxSize)
boxSize = boxSize(:).';
if isscalar(boxSize)
    boxSize = [boxSize boxSize];
end
if numel(boxSize) ~= 2 || any(~isfinite(boxSize)) || any(boxSize <= 0)
    error('surfaceBoundingBoxSize must be a positive scalar or [width height].');
end
end

function value = validate_positive_scalar(value,name)
if ~isscalar(value) || ~isfinite(value) || value <= 0
    error('%s must be a positive scalar.',name);
end
end

function value = validate_nonnegative_scalar(value,name)
if ~isscalar(value) || ~isfinite(value) || value < 0
    error('%s must be a nonnegative scalar.',name);
end
end

function value = validate_finite_scalar(value,name)
if ~isscalar(value) || ~isfinite(value)
    error('%s must be a finite scalar.',name);
end
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

function idx = sample_indices(numSamples,numSelected)
idx = unique(round(linspace(1,numSamples,min(numSamples,numSelected))));
end

function close_valid_figure(fig)
if isgraphics(fig)
    close(fig);
end
end
