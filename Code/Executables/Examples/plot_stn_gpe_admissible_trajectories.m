clear; close all;

examplesRoot = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(fileparts(fileparts(examplesRoot)));
paperRoot = fullfile(repositoryRoot,'Documentation', ...
    'Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations');
exampleDirectory = fullfile(examplesRoot,'Example_4');
addpath(exampleDirectory);

alphaSector = 0.492;
alphaSlope = 0.562;
diseaseLevel = 1;

[sectorLimit,~] = stn_gpe_admissible_trajectories( ...
    alphaSector,diseaseLevel);
[~,slopeLimit] = stn_gpe_admissible_trajectories( ...
    alphaSlope,diseaseLevel);
[~,zEquilibrium,~,parameters] = stn_gpe_equilibrium(diseaseLevel);

maximumRate = [parameters.MS,parameters.MG];
channelName = {'STN','GPe'};
channelSymbol = {'S','G'};
sectorColor = [0.08,0.40,0.72];
slopeColor = [0.88,0.32,0.18];
gridColor = [0.82,0.82,0.82];
fontSize = 12;
% Figure 8 uses two .495-column panels, each 7*252/522 inches wide.
% Figure 9 occupies one full column, so this canvas gives the same font scale.
pageSize = [2*(7*252/522)/0.99,3.65];

figureHandle = figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1,1,pageSize],'Renderer','painters');

for channel = 1:2
    M = maximumRate(channel);
    zStar = zEquilibrium(channel);
    zMaximum =4*max(sectorLimit(channel),slopeLimit(channel));
    z = linspace(0,zMaximum,1400);
    delta = (M/2)*(tanh(2*(zStar+z)/M)-tanh(2*zStar/M));
    sectorRatio = delta./z;
    slope = sech(2*(zStar+z)/M).^2;
    sectorRatio(1) = slope(1);

    axesHandle = axes(figureHandle,'Units','normalized', ...
        'Position',[0.11+(channel-1)*0.505,0.20,0.355,0.52]);
    hold(axesHandle,'on');
    sectorCurve = plot(z,sectorRatio,'Color',sectorColor, ...
        'LineWidth',1.2);
    slopeCurve = plot(z,slope,'Color',slopeColor,'LineWidth',1.2);
    yline(alphaSector,'--','Color',sectorColor,'LineWidth',0.85, ...
        'HandleVisibility','off');
    yline(alphaSlope,'--','Color',slopeColor,'LineWidth',0.85, ...
        'HandleVisibility','off');
    xline(sectorLimit(channel),':','Color',sectorColor, ...
        'LineWidth',0.85,'HandleVisibility','off');
    xline(slopeLimit(channel),':','Color',slopeColor, ...
        'LineWidth',0.85,'HandleVisibility','off');
    sectorPoint = scatter(sectorLimit(channel),alphaSector,30, ...
        sectorColor,'s','filled','MarkerEdgeColor','w','LineWidth',0.55);
    slopePoint = scatter(slopeLimit(channel),alphaSlope,30, ...
        slopeColor,'o','filled','MarkerEdgeColor','w','LineWidth',0.55);
    hold(axesHandle,'off');

    xlim(axesHandle,[0,zMaximum]);
    ylim(axesHandle,[0,1.02]);
    axesHandle.XGrid = 'off';
    axesHandle.YGrid = 'on';
    axesHandle.XMinorTick = 'on';
    tickSpacing = 100*channel;
    axesHandle.XTick = 0:tickSpacing:zMaximum;
    axesHandle.XRuler.MinorTickValues = setdiff( ...
        0:tickSpacing/10:zMaximum,axesHandle.XTick);
    axesHandle.YTick = 0:0.25:1;
    axesHandle.XTickLabelRotation = 0;
    axesHandle.Color = 'w';
    axesHandle.GridColor = gridColor;
    axesHandle.GridAlpha = 1;
    axesHandle.GridLineStyle = '-';
    axesHandle.TickDir = 'out';
    axesHandle.TickLength = [0.015,0.015];
    axesHandle.LineWidth = 0.55;
    box(axesHandle,'off');
    xlabel(sprintf('$z_{\\mathrm{%s}}$', ...
        channelSymbol{channel}),'Interpreter','latex','FontSize',fontSize);
    if channel==1
        ylabel('Quotient / slope','Interpreter','latex','FontSize',fontSize);
        legendAxes = axesHandle;
        legendHandles = [sectorCurve,slopeCurve,sectorPoint,slopePoint];
    end
    title(channelName{channel},'Interpreter','latex','FontWeight','normal', ...
        'FontSize',fontSize);
    set(axesHandle,'TickLabelInterpreter','latex','FontSize',fontSize, ...
        'FontName','Times New Roman','Layer','top','XColor','k','YColor','k');
end

legendHandle = legend(legendAxes,legendHandles, ...
    {'$\delta_i(z_i)/z_i$','$\delta_i''(z_i)$', ...
     '$\alpha_{\mathrm{sec}}^\star=0.492$', ...
     '$\alpha_{\mathrm{ZF}}^\star=0.562$'}, ...
    'Interpreter','latex','Orientation','horizontal', ...
    'NumColumns',2,'FontSize',fontSize,'Box','off','Units','normalized');
legendHandle.Position = [0.25 0.82 0.50 0.14];

outputBase = fullfile(paperRoot,'Figures', ...
    'stn_gpe_admissible_trajectories');
set(figureHandle,'PaperUnits','inches','PaperSize',pageSize, ...
    'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual');
print(figureHandle,[outputBase,'.pdf'],'-dpdf','-painters');
close(figureHandle);
