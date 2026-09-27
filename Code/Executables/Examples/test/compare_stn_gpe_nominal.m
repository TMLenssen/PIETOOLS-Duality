function Comparison = compare_stn_gpe_nominal(mode)
% Figure 10 plus Delta=0 nominal feedback acting on the nonlinear STN--GPe.
% Run compare_stn_gpe_nominal, or compare_stn_gpe_nominal('plot') to replot.
% All generated files stay beside this function; paper files are untouched.
if nargin==0, mode='run'; end
assert(ismember(mode,{'run','plot'}),'Use run or plot.');
testRoot=fileparts(mfilename('fullpath'));
examplesRoot=fileparts(testRoot);
codeRoot=fileparts(fileparts(examplesRoot));
addpath(genpath('C:\Program Files\MATLAB\PIETOOLS\PIETOOLS'));
addpath(genpath('C:\Program Files\Mosek\11.0\toolbox\r2019b'));
addpath(genpath(codeRoot));
cacheFile=fullfile(testRoot,'stn_gpe_nominal_comparison.mat');
if strcmp(mode,'plot')
    data=load(cacheFile,'Comparison'); Comparison=data.Comparison;
else
    diaryFile=fullfile(testRoot,'stn_gpe_nominal_comparison.log');
    diary(diaryFile); cleanupDiary=onCleanup(@() diary('off')); %#ok<NASGU>
    sourceFile=fullfile(examplesRoot,'stn_gpe_sector_simulation.mat');
    data=load(sourceFile,'Results','provenance');
    R=data.Results; provenance=data.provenance;
    assert(provenance.lambdaSector==1 && provenance.lambdaZF==0);
    assert(strcmp(provenance.coordinates,'equilibrium deviations'));
    assert(all(provenance.initialHistory==0));
    assert(isequal(size(R.K.P),[1,2]));
    nominal=synthesize_nominal(R.synthesis.P);
    % Keep the exact Figure 10 baseline arrays; only simulate the new law.
    [simNominal,validation]=simulate_nominal(R,provenance,nominal.K);
    Comparison=struct('baseline',R,'provenance',provenance, ...
        'baselineSource',sourceFile,'nominal',nominal, ...
        'simNominal',simNominal,'validation',validation, ...
        'designDelta',0,'simulationNonlinearity','full shifted sigmoid', ...
        'created',char(datetime('now')));
    Comparison.sourceText=fileread([mfilename('fullpath') '.m']);
    assert(isequaln(Comparison.baseline.simOpen,data.Results.simOpen));
    assert(isequaln(Comparison.baseline.simClosed,data.Results.simClosed));
    save(cacheFile,'Comparison','-v7.3');
end
plot_trajectories(Comparison.baseline,Comparison.provenance,testRoot, ...
    Comparison.simNominal);
write_summary(Comparison,testRoot);
fprintf('Comparison exported to %s\n',testRoot);
end

function result=synthesize_nominal(P)
% Delta=0 means w_Delta=0, so the nominal dynamics are T*x_dot=A*x+B2*u.
% Apply exactly the stability-only dual synthesis LPI used by the sector
% example, with the same storage/controller degrees and solver settings.
% Zero the disconnected nonlinearity ports and retain a decoupled negative
% identity block to use the existing executive without empty port blocks.
% The resulting state inequality is T*X*A'+T*Z*B2' + adjoint <= 0.
P0=P;
P0.B1=zerosPI(P.B1.dim(:,1),P.B1.dim(:,2),P.vars,P.dom);
P0.C1=zerosPI(P.C1.dim(:,1),P.C1.dim(:,2),P.vars,P.dom);
P0.D11=zerosPI(P.D11.dim(:,1),P.D11.dim(:,2),P.vars,P.dom);
P0.D12=zerosPI(P.D12.dim(:,1),P.D12.dim(:,2),P.vars,P.dom);
F=id_filter(P.B1.dim(:,2),P.C1.dim(:,1),P.vars,P.dom);
settings=lpisettings('veryheavy');
settings.sos_opts.solver='mosek';
settings.multiplierUpper=1e8;
settings.inverseFloor=1e-8;
settings.kypMarginUpper=100;
settings.kypSlackMode='normal';
settings.controllerCleanTol=1e-10;
settings.options1.sep=1;
settings.options12.sep=1;
prog=lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
V=diag([0,0,-1,-1]);
fprintf('\nNominal stability synthesis: Delta=0\n');
started=tic;
[K,Z,X,prog]=PIETOOLS_IQC_controller_synthesis(prog,settings,P0,F,V);
info=prog.solinfo.info;
residual=double(prog.solinfo.residual);
relativeResidual=residual/(1+norm(vertcat(prog.expr.b{:})));
feasible=info.pinf==0 && info.dinf==0 && info.numerr<=1 ...
    && isfinite(info.feasratio) && abs(info.feasratio-1)<=0.4 ...
    && isfinite(relativeResidual) && relativeResidual<1e-5 && ~isempty(K);
assert(feasible,'Nominal synthesis failed its solver/residual checks.');
result=struct('K',K,'Z',Z,'storage',X,'settings',settings, ...
    'info',info,'residual',residual,'relativeResidual',relativeResidual, ...
    'feasible',feasible,'seconds',toc(started),'designDelta',0, ...
    'objective','stability feasibility (same as sector design)');
fprintf('Nominal synthesis relative residual: %.3g\n',relativeResidual);
disp('Nominal finite-state gain (code units):'); disp(K.P);
end

function F=id_filter(d1,d2,vars,dom)
d0=[0;0];
F.T=zerosPI(d0,d0,vars,dom); F.A=F.T;
F.B1=zerosPI(d0,d1,vars,dom); F.B2=zerosPI(d0,d2,vars,dom);
F.C1=zerosPI(d1,d0,vars,dom); F.C2=zerosPI(d2,d0,vars,dom);
F.D11=eyePI(d1,vars,dom); F.D22=eyePI(d2,vars,dom);
F.D12=zerosPI(d1,d2,vars,dom); F.D21=zerosPI(d2,d1,vars,dom);
end

function [sim,validation]=simulate_nominal(R,provenance,K)
p=R.parameters;
delta=@(z) [p.MS/2*(tanh(2*(p.tildeZSStar+z(1))/p.MS)-tanh(2*p.tildeZSStar/p.MS)); ...
    p.MG/2*(tanh(2*(p.tildeZGStar+z(2))/p.MG)-tanh(2*p.tildeZGStar/p.MG))];
G=unscaled_simulation_plant(R.synthesis.P,K,true);
x0.ode=provenance.initialHistory;
x0.pde={0,0,0};
opts.nwd0=2; opts.splot=linspace(0,1,151).';
opts.wp=@(t) provenance.disturbanceAmplitude* ...
    sin(pi*(t-0.10)/0.04)^2*(t>=0.10 && t<=0.14);
opts.ode=odeset('RelTol',1e-8,'AbsTol',1e-10,'MaxStep',2.5e-4);
for order=[24,32]
    opts.N=order;
    fprintf('Simulating nominal controller on full nonlinear system, N=%d\n',order);
    sim=PIE_sim_nl(G,delta,R.simClosed.t,x0,opts);
    primary=sim.Dop.Tcheb_2PDEstate*sim.x.';
    sim.xS=primary(1,:).'; sim.xG=primary(2,:).';
    sim.zDelta=sim.zFinite(:,1:2); sim.u=sim.outputFinite(:,3:end);
    signals=[sim.xS,sim.xG,sim.zDelta,provenance.controlScaleToPaper*sim.u];
    assert(all(isfinite(signals),'all'),'Nonfinite nominal trajectory.');
    % At Delta=0 the discretized closed-loop generator is Atotal itself.
    spectralAbscissa=max(real(eig(sim.Dop.Atotal)));
    assert(spectralAbscissa<0,'Recovered nominal controller is unstable at Delta=0.');
    validation.nominalSpectralAbscissa(order/8-2)=spectralAbscissa;
    if order==24
        coarse=signals;
    else
        validation.spatialRelativeError=max(abs(signals-coarse),[],1)./ ...
            max(1,max(abs(signals),[],1));
        assert(max(validation.spatialRelativeError)<1e-3, ...
            'Nominal nonlinear trajectory failed the N=24/32 convergence check.');
    end
end
assert(isequal(sim.t,R.simClosed.t),'Comparison time grids differ.');
assert(max(abs(sim.wp-R.simClosed.wp),[],'all')<1e-12, ...
    'Comparison disturbance differs from Figure 10.');
validation.orders=[24,32];
validation.baselineTrajectoriesUnchanged=true;
fprintf('Nominal nonlinear spatial relative errors:');
fprintf(' %.3g',validation.spatialRelativeError); fprintf('\n');
fprintf('Delta=0 closed-loop spectral abscissae:');
fprintf(' %.6g',validation.nominalSpectralAbscissa); fprintf('\n');
end

function write_summary(C,testRoot)
R=C.baseline; sims={R.simOpen,R.simClosed,C.simNominal};
names={'Open loop';'Sector controller';'Nominal controller'};
peakXS=zeros(3,1); peakXG=peakXS; peakU=peakXS; finalNorm=peakXS;
maxZS=peakXS; maxZG=peakXS;
for k=1:3
    s=sims{k}; peakXS(k)=max(abs(s.xS)); peakXG(k)=max(abs(s.xG));
    if k>1, peakU(k)=C.provenance.controlScaleToPaper*max(abs(s.u)); end
    finalNorm(k)=hypot(s.xS(end),s.xG(end));
    maxZS(k)=max(s.zDelta(:,1)); maxZG(k)=max(s.zDelta(:,2));
end
summary=table(names,peakXS,peakXG,peakU,finalNorm,maxZS,maxZG, ...
    'VariableNames',{'Controller','PeakAbsXS','PeakAbsXG','PeakAbsU', ...
    'FinalStateNorm','MaxZS','MaxZG'});
writetable(summary,fullfile(testRoot,'stn_gpe_comparison_metrics.csv'));
disp(summary);
end

function plot_trajectories(R,provenance,figureRoot,nominal)
closed = R.simClosed; open = R.simOpen;
alpha = R.synthesis.betaBar;
[limits,~] = stn_gpe_admissible_trajectories(alpha,R.Kd);
originalCoordinates = isfield(provenance,'coordinates') && ...
    strcmp(provenance.coordinates,'original firing rates and sigmoid inputs');
if originalCoordinates
    limits = limits+[R.parameters.uS0,R.parameters.uG0];
end
% The synthesis plant uses xS_dot = ... + 4600*u_code; the paper uses
% tauS*xS_dot = ... + u. Plot u_paper = tauS*4600*u_code.
u = provenance.controlScaleToPaper*closed.u;
assert(all(isfinite([closed.xS;closed.xG;closed.zDelta(:);u(:)])));
maxZ = max(closed.zDelta,[],1);
% assert(all(maxZ<=limits),'Simulated inputs exceed the sector intervals.');
% Keep the original styling, with readable text at single-column width.
blue = [0.08 0.40 0.72];
nominalColor = [0.55 0.20 0.65];
fig = new_figure([7.0 6.6]);
positions = [0.125 0.70 0.335 0.21;0.625 0.70 0.335 0.21; ...
             0.125 0.40 0.335 0.21;0.625 0.40 0.335 0.21; ...
             0.125 0.10 0.335 0.21;0.625 0.10 0.335 0.21];
closedSignals = {closed.xS,closed.xG,closed.zDelta(:,1),closed.zDelta(:,2),u,closed.wp(:,1)};
openSignals = {open.xS,open.xG,open.zDelta(:,1),open.zDelta(:,2),zeros(size(open.t)),open.wp(:,2)};
labels = {'$x_{\mathrm S}(t)\;[\mathrm{spikes/s}]$','$x_{\mathrm G}(t)\;[\mathrm{spikes/s}]$', ...
    '$z_{\mathrm S}(t)$','$z_{\mathrm G}(t)$', ...
    '$u(t)\;[\mathrm{spikes/s}]$','$d(t)\;[\mathrm{spikes/s}]$'};
if originalCoordinates
    labels(1:4) = {'$\mathrm{STN}(t)\;[\mathrm{spikes/s}]$', ...
        '$\mathrm{GP}(t)\;[\mathrm{spikes/s}]$','$q_{\mathrm S}(t)$','$q_{\mathrm G}(t)$'};
end
nominalSignals = {nominal.xS,nominal.xG,nominal.zDelta(:,1), ...
    nominal.zDelta(:,2),provenance.controlScaleToPaper*nominal.u};
for i=1:6
    ax = axes(fig,'Position',positions(i,:)); hold(ax,'on');
    if i<=4
        ho = plot(ax,open.t,openSignals{i},'--','Color',[0.53 0.56 0.60], ...
            'LineWidth',1.15);
    elseif i==6
        ho = plot(ax,open.t,openSignals{i},'--','Color',[0.85 0.32 0.13],'LineWidth',1.3);
    end
    hc = plot(ax,closed.t,closedSignals{i},'Color',blue,'LineWidth',1.5);
    if i<=5
        hn = plot(ax,nominal.t,nominalSignals{i},'-.', ...
            'Color',nominalColor,'LineWidth',1.35);
    end
    if i==3 || i==4
        bound = limits(i-2);
        symbol = char('S'*(i==3)+'G'*(i==4));
        hl = yline(ax,bound,':','Color',[0.16 0.18 0.21], ...
            'LineWidth',1.25);
        values = [closedSignals{i};openSignals{i};nominalSignals{i}];
        limitsY = [min([values;bound]),max([values;bound])];
        padding = 0.08*max(diff(limitsY),0.01);
        ylim(ax,limitsY+[-padding padding]);
        drawnow;
        baseTicks = ax.YTick;
        if numel(baseTicks)>1
            tickSpacing = median(diff(baseTicks));
            baseTicks(abs(baseTicks-bound)<0.45*tickSpacing) = [];
        end
        ticks = sort([baseTicks bound]);
        ax.YTick = ticks;
        tickLabels = compose('$%.4g$',ticks);
        [~,boundIndex] = min(abs(ticks-bound));
        tickLabels{boundIndex} = sprintf('$z_{\\mathrm{%s}}^{\\max}$',symbol);
        if originalCoordinates
            tickLabels{boundIndex} = sprintf('$q_{\\mathrm{%s}}^{\\max}$',symbol);
        end
        ax.YTickLabel = tickLabels;
    else
        values = closedSignals{i};
        if i<=5, values = [values;nominalSignals{i}]; end
        if i<=2, values = [values;openSignals{i}]; end
        if i==6, values = [values;openSignals{i}]; end
        limitsY = [min(values) max(values)];
        padding = 0.08*max(diff(limitsY),0.01);
        ylim(ax,limitsY+[-padding padding]);
    end
    xlim(ax,[closed.t(1) 0.5]);
    ylabel(ax,labels{i},'Interpreter','latex','FontSize',12);
    if i>=5
        xlabel(ax,'$t\;[\mathrm{s}]$','Interpreter','latex','FontSize',12);
    end
    style_axes(ax,12);
    xticks(ax,0:0.1:0.5);
    if i==3, legendAxes = ax; handles = [hc hn ho hl]; end
    if i==6
        legend(ax,[hc ho],{'$d_{\mathrm S}$','$d_{\mathrm G}$'}, ...
            'Interpreter','latex','Box','off','Location','northeast','FontSize',12);
    end
end
lg = legend(legendAxes,handles,{'Sector controller','Nominal controller ($\Delta=0$)','Open loop','Sector limit'}, ...
    'Interpreter','latex','NumColumns',2,'Box','off','FontSize',12);
lg.Units='normalized'; lg.Position=[0.08 0.924 0.88 0.074];
export_pdf(fig,fullfile(figureRoot,'stn_gpe_sector_vs_nominal.pdf'));
fprintf('Actual certified alpha: %.10g\n',alpha);
fprintf('Sector upper limits [S,G]: %.9g %.9g\n',limits);
fprintf('Closed-loop maxima z [S,G]: %.9g %.9g\n',maxZ);
fprintf('Final closed-loop states [S,G]: %.9g %.9g\n',closed.xS(end),closed.xG(end));
fprintf('Peak paper control effort: %.9g\n',max(abs(u),[],'all'));
end


function G=unscaled_simulation_plant(P,K,closedLoop)
G=P;
if closedLoop
    G.A=P.A+P.B2*K;
    outputDims=ioDimensions(["nonlinearity","control"], ...
        [P.C1.dim(:,1).';K.dim(:,1).']);
    stateDims=ioDimensions("state",P.C1.dim(:,2).');
    grid=gridBuilder(outputDims,stateDims,P.vars,P.dom);
    grid(1,1)=P.C1+P.D12*K; grid(2,1)=K;
    G.C1=grid();
end
% Append a duplicate disturbance input without modifying the synthesis PIE.
inputDims=ioDimensions(["nonlinearity","pulse"], ...
    [P.B1.dim(:,2).';P.B1.dim(:,2).']);
stateDims=ioDimensions("state",P.B1.dim(:,1).');
grid=gridBuilder(stateDims,inputDims,P.vars,P.dom);
grid(1,1)=P.B1; grid(1,2)=P.B1; G.B1=grid();
zop=@(rows,cols) mat2opvar(zeros(sum(rows),sum(cols)), ...
    [rows,cols],P.vars,P.dom);
G.Tw=zop(G.T.dim(:,1),G.B1.dim(:,2));
G.D11=zop(G.C1.dim(:,1),G.B1.dim(:,2));
empty=[0;0];
G.B2=zop(G.T.dim(:,1),empty); G.Tu=G.B2;
G.C2=zop(empty,G.T.dim(:,2));
G.D12=zop(G.C1.dim(:,1),empty);
G.D21=zop(empty,G.B1.dim(:,2)); G.D22=zop(empty,empty);
G.misc=struct();
end

function fig = new_figure(pageSize)
fig = figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1 1 pageSize],'Renderer','painters');
set(fig,'PaperUnits','inches','PaperSize',pageSize, ...
    'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual');
end

function style_axes(ax,fontSize)
set(ax,'FontName','Times New Roman','FontSize',fontSize, ...
    'TickLabelInterpreter','latex','Box','off','TickDir','out', ...
    'LineWidth',0.6,'XGrid','off','YGrid','on','GridColor',[0.7 0.74 0.78], ...
    'GridAlpha',0.25,'Layer','top','XColor',[0.15 0.17 0.20], ...
    'YColor',[0.15 0.17 0.20]);
end

function export_pdf(fig,file)
print(fig,file,'-dpdf','-painters');
[folder,name] = fileparts(file);
print(fig,fullfile(folder,[name '.png']),'-dpng','-r180');
savefig(fig,fullfile(folder,[name '.fig']));
close(fig);
end
