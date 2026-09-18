function files = plot_Example_nonlinear_figures(data,style,example,outputDirectory)
%PLOT_EXAMPLE_NONLINEAR_FIGURES Render nonlinear examples for Figures 7 and 8.
% Uses fixed page and axes dimensions for each RD/wave pair. Both figures
% have the same printed font size under the paper's includegraphics widths.
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
style = default_surface_plot_settings(style);
plantTitles = {'Reaction--diffusion','Damped wave'};
files.state = fullfile(outputDirectory,sprintf('example%d_state.pdf',example));
files.effort = fullfile(outputDirectory,sprintf('example%d_effort.pdf',example));
files.amplitude = '';
files.preview = gobjects(0);
if ~isfield(style,'paperEffortOnly') || ~style.paperEffortOnly
    plot_states(data,style,files.state,style.resolution);
end
plot_effort(data,style,plantTitles{example-1},example-1,files.effort);
end

function plot_states(data,style,fileName,resolution)
pageSize = [7 3.6];
fig = figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1 1 pageSize],'Renderer','opengl');
cleanup = onCleanup(@()close(fig));
timeIdx = unique(round(linspace(1,numel(data.t),min(2048,numel(data.t)))));
spaceIdx = unique(round(linspace(1,numel(data.s),min(1024,numel(data.s)))));
states = {data.zOpen,data.zClosed};
titles = {'(a) Open-loop response','(b) Closed-loop response'};
for panel = 1:2
    left = 0.27+(panel-1)*3.5;
    ax = axes(fig,'Units','inches','Position',[left 0.75 2.65 2.45]);
    style.surfaceTitle = '';
    [~,~,cb] = plot_pde_surface(ax,data.s(spaceIdx),data.t(timeIdx), ...
        states{panel}(timeIdx,spaceIdx),style);
    % Manual positioning prevents content-dependent colorbar/axes resizing.
    cb.Units = 'inches';
    cb.Position = [left 0.34 2.65 0.12];
    cb.FontSize = style.fontSize;
    if isprop(cb,'TickLabelRotation'), cb.TickLabelRotation = 0; end
    ax.Position = [left 0.75 2.65 2.45];
    ax.XTickLabelRotation = 0;
    ax.YTickLabelRotation = 0;
    ax.ZTickLabelRotation = 0;
    annotation(fig,'textbox',[left/7 3.22/3.6 2.65/7 0.25/3.6], ...
        'String',titles{panel},'Interpreter',style.interpreter, ...
        'FontSize',style.titleFontSize,'FontName',style.fontName, ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'EdgeColor','none','Margin',0);
end
set(fig,'PaperUnits','inches','PaperSize',pageSize, ...
    'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual');
print(fig,fileName,'-dpdf','-opengl',sprintf('-r%d',resolution));
end

function plot_effort(data,style,plantTitle,index,fileName)
% Match Figure 10's blue/gray curves, light grid, and LaTeX labels.
% Keep the Figure 8 page dimensions and printed font size.
pageSize = [7*252/522 3.65];
fig = figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1 1 pageSize],'Renderer','painters');
cleanup = onCleanup(@()close(fig));
ax = axes(fig,'Units','normalized','Position',[0.17 0.20 0.77 0.52]);
hold(ax,'on');
disturbance = plot(ax,data.t,data.inputSignal,'--', ...
    'Color',[0.53 0.56 0.60],'LineWidth',1.15);
effort = plot(ax,data.t,data.boundarySignal,'-', ...
    'Color',[0.08 0.40 0.72],'LineWidth',1.5);
set(ax,'FontName','Times New Roman','FontSize',style.fontSize, ...
    'TickLabelInterpreter','latex','XLim',[0 35], ...
    'YLim',[-9 9],'XTick',0:5:35,'YTick',[-8 0 8], ...
    'XTickLabelRotation',0,'TickDir','out', ...
    'LineWidth',0.6,'Box','off','XColor',[0.15 0.17 0.20], ...
    'YColor',[0.15 0.17 0.20],'Color','w','XGrid','off','YGrid','on', ...
    'GridColor',[0.7 0.74 0.78],'GridAlpha',0.25,'Layer','top');
xlabel(ax,'$t$','Interpreter','latex','FontSize',style.fontSize);
ylabel(ax,'Amplitude','Interpreter','latex','FontSize',style.fontSize);
title(ax,plantTitle,'Interpreter','latex', ...
    'FontSize',style.titleFontSize,'FontWeight','normal');
lg = legend(ax,[disturbance effort], ...
    {'Disturbance $w_{\mathrm p}(t)$',sprintf('Control effort $x_%d(t)$',index)}, ...
    'Interpreter','latex','FontSize',style.fontSize, ...
    'Box','off','Units','normalized');
lg.Position = [0.17 0.82 0.77 0.14];
set(fig,'PaperUnits','inches','PaperSize',pageSize, ...
    'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual');
print(fig,fileName,'-dpdf','-painters');
end
