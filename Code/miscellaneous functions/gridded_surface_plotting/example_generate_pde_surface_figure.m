%% Example: export one PDE response surface
% The plotting utilities live in the same directory as this script.
plottingDirectory = fileparts(mfilename('fullpath'));
addpath(plottingDirectory);

% Spatial and temporal coordinates. z may be numel(t)-by-numel(s), as
% below, or its transpose.
s = linspace(0,1,200);
t = linspace(0,10,5000).';
% A damped travelling wave, a counter-propagating mode, and a localized
% wave packet give the example nontrivial structure in both t and s.
decay = exp(-0.07*t);
startup = 1-exp(-1.5*t); % Enforces x(0,s)=0 for every spatial position.
travellingWave = sin(pi*s).*sin(2.3*t-2*pi*s);
reflectedMode = 0*0.35*sin(2*pi*s).*cos(1.1*t+3*pi*s);
wavePacket = 0.7*exp(-0.35*(t-4.5).^2).*sin(pi*s);%.*exp(-18*(s-0.72).^2).*cos(4.5*t-5*pi*s);
x = startup.*(decay.*(travellingWave+reflectedMode)+wavePacket);

% Start from the complete defaults and override only what this plot needs.
settings = default_surface_plot_settings();
settings.colormap = mplmap('magma',256); %mplmap contains some Python colormaps
settings.surfaceAlpha = 1;
settings.colorbarGap = -0.8;                % Gap to axes decorations, inches.
% settings.surfaceTitle = 'Example PDE response';
settings.axisLabels = {'$t$','$s$','$\mathbf{x}(t,s)$'};
settings.surfaceBoundingBoxSize = [3.25 3.25]; % Square axes box, in inches.
settings.colorbarLocation = 'south';
% The default 'auto' ruler locations follow the current camera view.
% Choose 's' or 't'; the plane is placed on the far face automatically.
settings.zPlaneLocation = 's';
settings.view = [45 45];
settings.projection = 'orthographic';
settings.cameraViewAngle = []; % Set an angle in degrees for manual zoom.
settings.keepZAxisVertical = true; % Remove camera roll from the x(t,s)-axis.

% Optional tick-aligned lines on the surface.
settings.showSpatialLines = true;
settings.showTemporalLines = true;
settings.showSurfaceLevels = true;
settings.showZeroSurfaceLevel = false; % Omit only the z=0 level contour.
settings.tMajorTickSpacing = 2;
settings.sMajorTickSpacing = 0.25;
settings.zMajorTickSpacing = 0.5;
settings.tMinorTicksBetweenMajor = 9;
settings.sMinorTicksBetweenMajor = 4;
settings.zMinorTicksBetweenMajor = 5;
settings.majorTickLength = [0.025 0.2 0.025];

% Optional zero-level rulers and t-z wall.
settings.axesAtZeroLevel = true;
settings.showAxesBox = false;
settings.showTZGrid = true;
settings.showTZFrame = true;

outputFile = fullfile(pwd,'pde_surface_example.pdf');
outputFile = generate_pde_surface_figure(outputFile,s,t,x,settings);
fprintf('Surface figure written to: %s\n',outputFile);

% See EXAMPLE_GENERATE_PDE_SURFACE_FIGURE_2X2 for a tiled comparison with
% four colormaps and four colorbar orientations.
