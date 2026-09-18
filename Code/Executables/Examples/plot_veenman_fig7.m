function f=plot_veenman_fig7(result,yLimits,figureHeight)
% Figure 7 layout from Veenman, Scherer and Koroglu (2016).
% Plot saved bounds only: no optimization, interpolation or gap filling.
% Optional yLimits=[lower upper] gives identical vertical limits across runs.
required={'alpha','rho','nu','gamma'};
assert(all(isfield(result,required)),'Expected alpha, rho, nu and gamma.');
alpha=result.alpha(:); rho=result.rho(:).'; orders=result.nu(:).';
assert(size(result.gamma,1)==numel(alpha) && size(result.gamma,2)==numel(rho) ...
    && size(result.gamma,3)==numel(orders),'Gain-array dimensions do not match the grids.');
assert(all(isfinite(rho) & rho<0),'Pole locations must be finite and negative.');
assert(~isempty(orders) && all(isfinite(orders) & orders>=0 & orders==floor(orders)) ...
    && numel(unique(orders))==numel(orders),'Use distinct nonnegative integer filter orders.');
bounds=result.gamma;
bounds(~isfinite(bounds) | bounds<=0)=NaN;
minima=nan(numel(alpha),numel(orders));
for k=1:numel(orders)
    for i=1:numel(alpha)
        values=bounds(i,:,k); values=values(isfinite(values));
        if ~isempty(values), minima(i,k)=min(values); end
    end
end
validMinima=minima(isfinite(minima));
if isempty(validMinima)
    warning('No positive finite gain bounds: no Figure 7 plot was produced.');
    f=gobjects(0); return
end
if nargin<2 || isempty(yLimits)
    % The source clips the high sides of the U-shaped curves, keeping all
    % labelled minima visible. Adapt its padding to the actual computed gains.
    yLimits=[min(validMinima)/1.18,max(validMinima)*1.42];
end
assert(isnumeric(yLimits) && numel(yLimits)==2 && all(isfinite(yLimits)) ...
    && yLimits(1)>0 && yLimits(2)>yLimits(1),'Use positive increasing yLimits.');
if nargin<3 || isempty(figureHeight)
    figureHeight=min(3.25,1.45+.45*numel(orders));
end
assert(isscalar(figureHeight) && isfinite(figureHeight) && figureHeight>1.25, ...
    'figureHeight must be a finite scalar greater than 1.25 inches.');

% One panel per requested degree, preserving the supplied order. Keep the
% paper's panel proportions as the number of panels changes.
panelWidths=1.15*ones(size(orders)); panelWidths(orders==0)=.165;
leftMargin=1.05; rightMargin=.20; gap=.80;
figureWidth=leftMargin+sum(panelWidths)+gap*(numel(orders)-1)+rightMargin;
f=figure('Visible','off','Color','w','Units','inches',...
    'Position',[1,1,figureWidth,figureHeight],'Renderer','painters');
left=leftMargin+[0,cumsum(panelWidths(1:end-1)+gap)];
bottom=.95; height=figureHeight-1.25;
xLimits=[min([1e-3,abs(rho)]),max([1e3,abs(rho)])];
[poleMagnitude,poleOrder]=sort(abs(rho),'descend');
isDual=~isfield(result,'side') || strcmp(result.side,'dual');
for k=1:numel(orders)
    order=orders(k);
    ax=axes('Parent',f,'Units','inches',...
        'Position',[left(k),bottom,panelWidths(k),height]);
    hold(ax,'on');
    set(ax,'YScale','log','YLim',yLimits,'Box','on',...
        'FontName','Times New Roman','FontSize',8,'LineWidth',.9,...
        'TickDir','in','TickLabelInterpreter','latex',...
        'XGrid','off','YGrid','off','YMinorTick','off',...
        'XMinorGrid','off','YMinorGrid','off','Layer','top');
    title(ax,sprintf('$\\nu=%d$',order),'Interpreter','latex',...
        'FontSize',10,'FontWeight','normal');
    if order==0
        set(ax,'XLim',[0,1],'XTick',[],'XMinorTick','off');
    else
        set(ax,'XScale','log','XDir','reverse','XLim',xLimits,...
            'XTick',10.^(-3:3),'XMinorTick','on',...
            'XTickLabel',{'$-0.001$','$-0.01$','$-0.1$','$-1$',...
                         '$-10$','$-100$','$-1000$'},...
            'XTickLabelRotation',60);
    end
        for i=1:numel(alpha)
            best=minima(i,k);
            if ~isfinite(best), continue; end
            if order==0
                plot(ax,[0,1],[best,best],'r-','LineWidth',.8);
            else
                % Reference lines identify alpha | minimum over sampled poles.
                plot(ax,xLimits,[best,best],':','Color',[.45,.45,.45],...
                    'LineWidth',.55,'HandleVisibility','off');
                if numel(poleMagnitude)==1
                    plot(ax,poleMagnitude,bounds(i,poleOrder,k),'ro', ...
                        'LineWidth',.8,'MarkerSize',4,'MarkerFaceColor','r');
                else
                    plot(ax,poleMagnitude,bounds(i,poleOrder,k),'r-', ...
                        'LineWidth',.8);
                end
            end
        end
    visible=isfinite(minima(:,k)) & minima(:,k)>=yLimits(1) ...
        & minima(:,k)<=yLimits(2);
    levels=minima(visible,k); radii=alpha(visible);
    [ticks,~,groups]=unique(levels);
    labels=cell(numel(ticks),1);
    for j=1:numel(ticks)
        % Combine exactly coincident levels instead of dropping an alpha.
        radiusLabels=arrayfun(@(a)sprintf('%.2f',a),radii(groups==j),'UniformOutput',false);
        labels{j}=sprintf('$%s\\,|\\,%.2f$',strjoin(radiusLabels,','),ticks(j));
    end
    set(ax,'YTick',ticks,'YTickLabel',labels);
    if k==1
        if isDual, label='$\alpha\,|\,\underline{\gamma}_{\star}$';
        else, label='$\alpha\,|\,\gamma_{\star}$'; end
        ylabel(ax,label,'Interpreter','latex','FontSize',10);
    end
end
nonZeroCols=find(orders>0);
for k=nonZeroCols
    annotation(f,'textbox',[left(k)/figureWidth,.018, ...
        panelWidths(k)/figureWidth,.08], ...
        'String','pole location $\rho$','Interpreter','latex', ...
        'FontName','Times New Roman','FontSize',10, ...
        'HorizontalAlignment','center','EdgeColor','none');
end
end

