function results = recreate_stn_gpe_centered_simulation(outputFile)
%RECREATE_STN_GPE_CENTERED_SIMULATION Recreate Fig. 5A--F with centered states.
%   RESULTS = RECREATE_STN_GPE_CENTERED_SIMULATION() simulates the STN--GPe
%   model for K = 0, 0.2, and 1 using both the published and exactly
%   centered formulations. The plotted published solution is shifted to the
%   same x-coordinates; no firing-rate midpoint is added to either curve.
%
%   RESULTS = RECREATE_STN_GPE_CENTERED_SIMULATION(OUTPUTFILE) writes the
%   comparison figure to OUTPUTFILE. Pass "" to skip exporting the figure.

if nargin < 1
    outputFile = default_output_file();
end

p.tauS = 6e-3;
p.tauG = 14e-3;
p.tauGS = 6e-3;
p.tauSG = 6e-3;
p.tauGG = 4e-3;
p.Ctx = 27;
p.Str = 2;
p.MS = 300;
p.BS = 17;
p.MG = 400;
p.BG = 75;
p.healthyWeights = [19.0,1.12,6.60,2.42,15.1];
p.diseasedWeights = [20.0,10.7,12.3,9.2,139.4];
p.stimulation = @(t) 0*t;

Kvalues = [0,0.2,1];
t = linspace(0,0.5,2001);
lags = [p.tauGS,p.tauGG];
midpoint = [p.MS/2;p.MG/2];
publishedHistory = [0;0];
centeredHistory = publishedHistory-midpoint;
solverOptions = ddeset('RelTol',1e-10,'AbsTol',1e-11, ...
    'MaxStep',2.5e-4);

results = repmat(struct('K',[],'t',[],'publishedCentered',[], ...
    'centered',[],'maxError',[]),numel(Kvalues),1);
for k = 1:numel(Kvalues)
    caseParameters = parameters_at_K(p,Kvalues(k));
    publishedSolution = dde23( ...
        @(time,state,delayed) published_rhs( ...
        time,state,delayed,caseParameters), ...
        lags,publishedHistory,[t(1),t(end)],solverOptions);
    centeredSolution = dde23( ...
        @(time,state,delayed) centered_rhs( ...
        time,state,delayed,caseParameters), ...
        lags,centeredHistory,[t(1),t(end)],solverOptions);

    publishedCentered = deval(publishedSolution,t)-midpoint;
    centered = deval(centeredSolution,t);
    maxError = max(abs(publishedCentered-centered),[],'all');
    assert(maxError < 1e-5, ...
        'Centered and published simulations disagree by %.3e.',maxError);

    results(k).K = Kvalues(k);
    results(k).t = t;
    results(k).publishedCentered = publishedCentered;
    results(k).centered = centered;
    results(k).maxError = maxError;
end

fig = comparison_figure(results);
if strlength(string(outputFile)) > 0
    outputDirectory = fileparts(outputFile);
    if ~isempty(outputDirectory) && ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    exportgraphics(fig,outputFile,'ContentType','vector');
end

for k = 1:numel(results)
    fprintf('K = %.1f: max centered/original discrepancy = %.3e\n', ...
        results(k).K,results(k).maxError);
end
if strlength(string(outputFile)) > 0
    fprintf('Comparison figure written to: %s\n',outputFile);
end
end

function p = parameters_at_K(p,K)
weights = p.healthyWeights+K*(p.diseasedWeights-p.healthyWeights);
p.wSG = weights(1);
p.wGS = weights(2);
p.wGG = weights(3);
p.wCS = weights(4);
p.wXG = weights(5);
p.cS = p.MS/4*log((p.MS-p.BS)/p.BS);
p.cG = p.MG/4*log((p.MG-p.BG)/p.BG);
p.bS = p.wCS*p.Ctx-p.wGS*p.MG/2-p.cS;
p.bG = p.wSG*p.MS/2-p.wGG*p.MG/2-p.wXG*p.Str-p.cG;
end

function derivative = published_rhs(time,state,delayed,p)
% The two unique delays are tauGS=tauSG and tauGG.
delayedSTN = delayed(1,1);
delayedGPeFromSTNLoop = delayed(2,1);
delayedGPeSelf = delayed(2,2);
inputS = -p.wGS*delayedGPeFromSTNLoop+p.wCS*p.Ctx;
inputG = p.wSG*delayedSTN-p.wGG*delayedGPeSelf-p.wXG*p.Str;
derivative = [
    (sigmoid(inputS,p.MS,p.BS)-state(1)+p.stimulation(time))/p.tauS;
    (sigmoid(inputG,p.MG,p.BG)-state(2))/p.tauG];
end

function derivative = centered_rhs(time,state,delayed,p)
delayedX1 = delayed(1,1);
delayedX2FromSTNLoop = delayed(2,1);
delayedX2Self = delayed(2,2);
zS = -p.wGS*delayedX2FromSTNLoop+p.bS;
zG = p.wSG*delayedX1-p.wGG*delayedX2Self+p.bG;
derivative = [
    (centered_sigmoid(zS,p.MS)-state(1)+p.stimulation(time))/p.tauS;
    (centered_sigmoid(zG,p.MG)-state(2))/p.tauG];
end

function value = sigmoid(input,M,B)
value = M./(1+exp(-4*input/M)*(M-B)/B);
end

function value = centered_sigmoid(input,M)
value = M./(1+exp(-4*input/M))-M/2;
end

function fig = comparison_figure(results)
originalColors = [0.82 0.45 0.45;0.55 0.69 0.84];
centeredColors = [0.55 0.00 0.00;0.00 0.25 0.55];
allStates = cat(2,results.centered);
stateRange = [min(allStates,[],'all'),max(allStates,[],'all')];
statePadding = max(5,0.05*diff(stateRange));
timeLimits = stateRange+[-statePadding,statePadding];
x1Range = [min(allStates(1,:)),max(allStates(1,:))];
x2Range = [min(allStates(2,:)),max(allStates(2,:))];
x1Padding = max(3,0.05*diff(x1Range));
x2Padding = max(5,0.05*diff(x2Range));

fig = figure('Color','w','Units','inches','Position',[1 1 7.2 4.7]);
layout = tiledlayout(fig,2,numel(results),'TileSpacing','compact', ...
    'Padding','compact');
title(layout,'Published and centered STN--GPe models', ...
    'Interpreter','latex','FontSize',11);

for k = 1:numel(results)
    ax = nexttile(layout,k);
    hold(ax,'on');
    plot(ax,results(k).t,results(k).publishedCentered(1,:),'-', ...
        'Color',originalColors(1,:),'LineWidth',2.4);
    plot(ax,results(k).t,results(k).publishedCentered(2,:),'-', ...
        'Color',originalColors(2,:),'LineWidth',2.4);
    plot(ax,results(k).t,results(k).centered(1,:),'--', ...
        'Color',centeredColors(1,:),'LineWidth',1.0);
    plot(ax,results(k).t,results(k).centered(2,:),'--', ...
        'Color',centeredColors(2,:),'LineWidth',1.0);
    hold(ax,'off');
    title(ax,sprintf('$K=%.1f$',results(k).K),'Interpreter','latex');
    xlabel(ax,'Time (s)','Interpreter','latex');
    if k == 1
        ylabel(ax,'Centered state','Interpreter','latex');
        legend(ax,{'Published $x_1$','Published $x_2$', ...
            'Centered $x_1$','Centered $x_2$'}, ...
            'Interpreter','latex','Location','best','FontSize',7);
    end
    xlim(ax,[results(k).t(1),results(k).t(end)]);
    ylim(ax,timeLimits);
    format_axes(ax);

    ax = nexttile(layout,numel(results)+k);
    hold(ax,'on');
    plot(ax,results(k).publishedCentered(1,:), ...
        results(k).publishedCentered(2,:),'-', ...
        'Color',[0.72 0.72 0.72],'LineWidth',2.8);
    plot(ax,results(k).centered(1,:),results(k).centered(2,:),'--', ...
        'Color',[0 0 0],'LineWidth',1.0);
    plot(ax,results(k).centered(1,1),results(k).centered(2,1),'o', ...
        'MarkerSize',4,'MarkerFaceColor','w','MarkerEdgeColor','k');
    hold(ax,'off');
    xlabel(ax,'$x_1$','Interpreter','latex');
    if k == 1
        ylabel(ax,'$x_2$','Interpreter','latex');
    end
    xlim(ax,x1Range+[-x1Padding,x1Padding]);
    ylim(ax,x2Range+[-x2Padding,x2Padding]);
    text(ax,0.04,0.94,sprintf('$\\max |\\Delta x|=%.1e$', ...
        results(k).maxError),'Units','normalized','Interpreter','latex', ...
        'VerticalAlignment','top','FontSize',7);
    format_axes(ax);
end
end

function format_axes(ax)
ax.FontName = 'Times New Roman';
ax.FontSize = 8;
ax.TickLabelInterpreter = 'latex';
ax.Box = 'on';
ax.LineWidth = 0.6;
ax.XGrid = 'off';
ax.YGrid = 'off';
end

function outputFile = default_output_file()
scriptDirectory = fileparts(mfilename('fullpath'));
outputFile = fullfile(scriptDirectory,'stn_gpe_centered_comparison.pdf');
end
