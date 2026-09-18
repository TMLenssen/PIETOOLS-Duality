function files=plot_Example_6(primal,dual,yLimits,figureHeight,differenceYLimits)
% Plot primal, dual, and primal-minus-dual versions of Figure 7.
% Saved bounds are plotted without running an optimization or filling gaps.
% differenceYLimits may be a positive scalar L (giving [-L,L]) or an
% explicit increasing [ymin,ymax] pair. Empty selects a symmetric range.
here=fileparts(mfilename('fullpath'));
if nargin<1 || isempty(primal), primal=load_side(here,'primal'); end
if nargin<2 || isempty(dual), dual=load_side(here,'dual'); end
if nargin<3, yLimits=[]; end
if nargin<4 || isempty(figureHeight), figureHeight=5; end
if nargin<5, differenceYLimits=[]; end
assert(isscalar(figureHeight) && isfinite(figureHeight) && figureHeight>1.25, ...
    'figureHeight must be a finite scalar greater than 1.25 inches.');
assert_matching_grids(primal,dual);
primal.side='primal';
dual.side='dual';

if isempty(yLimits)
    gains=[primal.gamma(:);dual.gamma(:)];
    gains=gains(isfinite(gains) & gains>0);
    assert(~isempty(gains),'No finite positive primal or dual bounds were found.');
    yLimits=[min(gains)/1.18,max(gains)*1.42];
end

previousPath=path;
addpath(fileparts(here));
pathCleanup=onCleanup(@()path(previousPath)); %#ok<NASGU>
codeRoot=fileparts(fileparts(fileparts(here)));
paperFigureDir=fullfile(fileparts(codeRoot),'Documentation', ...
    'Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations','Figures');
assert(isfolder(paperFigureDir),'The manuscript Figures directory was not found.');

files=struct;
f=plot_veenman_fig7(primal,yLimits,figureHeight);
files.primal=export_panel(f,paperFigureDir,'example1_primal');
f=plot_veenman_fig7(dual,yLimits,figureHeight);
files.dual=export_panel(f,paperFigureDir,'example1_dual');
f=plot_difference(primal,dual,figureHeight,differenceYLimits);
files.difference=export_panel(f,paperFigureDir,'example1_difference');
end

function result=load_side(here,side)
dataFile=fullfile(here,['Example_6_Fig7_' side '.mat']);
if ~isfile(dataFile) && strcmp(side,'dual')
    dataFile=fullfile(here,'Example_6_Fig7.mat');
end
assert(isfile(dataFile),'Missing saved %s sweep: %s',side,dataFile);
data=load(dataFile,'Results');
assert(isfield(data,'Results'),'Expected a Results variable in %s.',dataFile);
result=data.Results;
end

function assert_matching_grids(primal,dual)
required={'alpha','rho','nu','gamma'};
assert(all(isfield(primal,required)) && all(isfield(dual,required)), ...
    'Both inputs must contain alpha, rho, nu, and gamma.');
assert(isequal(primal.alpha,dual.alpha) && isequal(primal.rho,dual.rho) ...
    && isequal(primal.nu,dual.nu), ...
    'Primal and dual results must use identical alpha, rho, and nu grids.');
assert(isequal(size(primal.gamma),size(dual.gamma)), ...
    'Primal and dual gain arrays must have identical dimensions.');
end

function paths=export_panel(f,folder,stem)
assert(~isempty(f) && isgraphics(f),'No figure was produced for %s.',stem);
cleanup=onCleanup(@()close(f)); %#ok<NASGU>
paths.pdf=fullfile(folder,[stem '.pdf']);
% Width, Height, Units, Padding, and PreserveAspectRatio are not accepted
% by exportgraphics in MATLAB R2023a. The figure Position already specifies
% the intended dimensions, so use the broadly supported vector-PDF call.
exportgraphics(f,paths.pdf,'ContentType','vector');
end
function f=plot_difference(primal,dual,figureHeight,differenceYLimits)
% One side-by-side column per nu, with contiguous alpha strips in each.
alpha=primal.alpha(:);
rho=primal.rho(:).';
orders=primal.nu(:).';
difference=primal.gamma-dual.gamma;
difference(~isfinite(primal.gamma) | ~isfinite(dual.gamma))=NaN;
assert(any(isfinite(difference(:))), ...
    'No matched finite primal and dual bounds were found.');
% Mark the sampled pole at which all alpha curves are collectively closest
% to zero.  Using the worst absolute difference across alpha gives one
% shared reference line per dynamic filter order.
zeroCrossingPole=nan(size(orders));
for k=1:numel(orders)
    if orders(k)==0
        continue
    end
    orderDifference=abs(difference(:,:,k));
    worstDifference=max(orderDifference,[],1,'omitnan');
    worstDifference(all(~isfinite(orderDifference),1))=Inf;
    [minimumDifference,rhoIndex]=min(worstDifference);
    if isfinite(minimumDifference)
        zeroCrossingPole(k)=abs(rho(rhoIndex))
    end
end
% Use raw difference values, i.e., a fixed shared exponent of 10^0.
differenceScale=1;
if isempty(differenceYLimits)
    maxDifference=max(abs(difference(isfinite(difference))));
    if maxDifference==0
        differenceLimit=1;
    else
        differenceLimit=ceil(10*1.08*maxDifference)/10;
    end
    differenceYLimits=[-differenceLimit,differenceLimit];
elseif isnumeric(differenceYLimits) && isreal(differenceYLimits) ...
        && isscalar(differenceYLimits) && isfinite(differenceYLimits) ...
        && differenceYLimits>0
    differenceYLimits=[-differenceYLimits,differenceYLimits];
else
    assert(isnumeric(differenceYLimits) && isreal(differenceYLimits) ...
        && numel(differenceYLimits)==2 && all(isfinite(differenceYLimits)) ...
        && differenceYLimits(1)<differenceYLimits(2), ...
        'differenceYLimits must be a positive scalar or increasing [ymin,ymax] pair.');
    differenceYLimits=differenceYLimits(:).';
end
scaledDifference=difference/differenceScale;
panelWidths=1.15*ones(size(orders));
panelWidths(orders==0)=.165;
leftMargin=1.05; rightMargin=.20; gap=.80;
figureWidth=leftMargin+sum(panelWidths)+gap*(numel(orders)-1)+rightMargin;
f=figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1,1,figureWidth,figureHeight],'Renderer','painters');
left=leftMargin+[0,cumsum(panelWidths(1:end-1)+gap)];
bottom=.95; height=figureHeight-1.25;
xLimits=[min([1e-3,abs(rho)]),max([1e3,abs(rho)])];
[poleMagnitude,poleOrder]=sort(abs(rho),'descend');

stripHeight=height/numel(alpha);
for k=1:numel(orders)
    order=orders(k);
    for i=1:numel(alpha)
        ax=axes('Parent',f,'Units','inches', ...
            'Position',[left(k),bottom+(i-1)*stripHeight, ...
            panelWidths(k),stripHeight]);
        hold(ax,'on');
        set(ax,'YLim',differenceYLimits, ...
            'YTick',0, ...
            'YTickLabel',{sprintf('$%.2f\\,|\\,0$',alpha(i))}, ...
            'Box','off','FontName','Times New Roman','FontSize',8, ...
            'LineWidth',.9,'TickDir','in','TickLabelInterpreter','latex', ...
            'XGrid','off','YGrid','off','XMinorGrid','off', ...
            'YMinorGrid','off','Layer','top');
        yline(ax,0,'-','Color',[.35,.35,.35],'LineWidth',.55, ...
            'HandleVisibility','off');
        if order==0
            set(ax,'XLim',[0,1],'XTick',[],'XMinorTick','off');
        else
            set(ax,'XScale','log','XDir','reverse','XLim',xLimits, ...
                'XTick',[],'XMinorTick','off');
        end
        % if order>0 && isfinite(zeroCrossingPole(k))
        %     xline(ax,zeroCrossingPole(k),'--','Color',[.35,.35,.35], ...
        %         'LineWidth',.55,'HandleVisibility','off');
        % end
        ax.XAxis.Visible='off';
        values=squeeze(scaledDifference(i,:,k));
        if any(isfinite(values))
            if order==0
                plot(ax,[0,1],[values(1),values(1)],'r-','LineWidth',.8);
            elseif numel(poleMagnitude)==1
                plot(ax,poleMagnitude,values(poleOrder),'ro', ...
                    'LineWidth',.8,'MarkerSize',4,'MarkerFaceColor','r');
            else
                plot(ax,poleMagnitude,values(poleOrder),'r-','LineWidth',.8);
            end
        end
        if i==numel(alpha)
            title(ax,sprintf('$\\nu=%d$',order),'Interpreter','latex', ...
                'FontSize',10,'FontWeight','normal');
        end
    end
    % Restore the complete outer frame without restoring internal axes.
    frameAxis=axes('Parent',f,'Units','inches', ...
        'Position',[left(k),bottom,panelWidths(k),height], ...
        'Color','none','Box','on','YTick',[], ...
        'XColor','k','YColor','k','LineWidth',.9, ...
        'FontName','Times New Roman','FontSize',8,'TickDir','in', ...
        'TickLabelInterpreter','latex','Layer','top', ...
        'HitTest','off','PickableParts','none');
    if order==0
        set(frameAxis,'XLim',[0,1],'XTick',[],'XMinorTick','off');
    else
        set(frameAxis,'XScale','log','XDir','reverse','XLim',xLimits, ...
            'XTick',10.^(-3:3),'XMinorTick','on', ...
            'XTickLabel',{'$-0.001$','$-0.01$','$-0.1$','$-1$', ...
                '$-10$','$-100$','$-1000$'},'XTickLabelRotation',60);
    end
    % Separate adjacent alpha strips by a plain line matching the frame.
    for dividerIndex=1:numel(alpha)-1
        dividerY=(bottom+dividerIndex*stripHeight)/figureHeight;
        annotation(f,'line',left(k)/figureWidth+ ...
            [0,panelWidths(k)/figureWidth],[dividerY,dividerY], ...
            'Color','k','LineWidth',.9);
    end
end
labelAxis=axes('Parent',f,'Units','inches', ...
    'Position',[0,bottom,leftMargin-.05,height],'Visible','off', ...
    'XLim',[0,1],'YLim',[0,1]);
text(labelAxis,0.5,0.5, ...
    sprintf('$\\alpha\\,|\\,\\gamma-\\underline{\\gamma}\\in[%.3g,%.3g]$', ...
        differenceYLimits(1),differenceYLimits(2)), ...
    'Interpreter','latex','FontSize',10,'FontName','Times New Roman', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'Rotation',90);
nonZeroCols=find(orders>0);
for k=nonZeroCols
    annotation(f,'textbox',[left(k)/figureWidth,.018, ...
        panelWidths(k)/figureWidth,.08], ...
        'String','pole location $\rho$','Interpreter','latex', ...
        'FontName','Times New Roman','FontSize',10, ...
        'HorizontalAlignment','center','EdgeColor','none');
end
end
