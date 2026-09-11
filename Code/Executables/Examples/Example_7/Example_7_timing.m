clear; clc;
% SYNTHESIS timing for temporal multiplier degree nu=i:j.
i=0; j=3;
nuGrid=i:j;
repetitions=1;
recoverController=false;           % true also measures numerical K recovery
assert(i>=0 && j>=i && all([i,j,repetitions]==floor([i,j,repetitions])) && repetitions>=1);
here=fileparts(mfilename('fullpath'));
codeRoot=fileparts(fileparts(fileparts(here)));
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
addpath(genpath(codeRoot)); addpath(here,'-begin');
rmpath(fullfile(here,'compat'));
saved=load(fullfile(here,'Example_7_synthesis.mat'),'P','Synthesis','settings');
P=saved.P; alpha=saved.Synthesis.alpha; rho=-1;
settings=saved.settings;
settings.recoverController=recoverController;
outputBase=fullfile(here,'Example_7_synthesis_timing');
Timing=table;
Details=cell(numel(nuGrid),repetitions);
metadata=struct('task','synthesis','alpha',alpha,'rho',rho,'nuGrid',nuGrid,...
    'repetitions',repetitions,'recoverController',recoverController,...
    'settings',settings,'matlabVersion',version,'started',datetime('now'));
for k=1:numel(nuGrid)
    for repeat=1:repetitions
        nu=nuGrid(k);
        totalTimer=tic; solverSeconds=NaN; assemblySeconds=NaN;
        gain=NaN; accepted=false; numerr=NaN; relativeResidual=NaN; errorText="";
        try
            out=synthesize_boundary_gain(P,alpha,nu,rho,settings);
            solverSeconds=out.solverSeconds; assemblySeconds=out.assemblySeconds;
            gain=out.gamma; accepted=out.feasible; numerr=out.info.numerr;
            relativeResidual=out.relativeResidual;
            % Retain solver diagnostics without duplicating large operators.
            Details{k,repeat}=rmfield(out,{'K','Z','storage','dualFilter'});
        catch err
            errorText=string(getReport(err,'extended','hyperlinks','off'));
            Details{k,repeat}=struct('error',errorText);
        end
        totalSeconds=toc(totalTimer);
        row=table(nu,repeat,solverSeconds,assemblySeconds,totalSeconds,gain,...
            accepted,numerr,relativeResidual,errorText,...
            'VariableNames',{'Nu','Repeat','SolverSeconds','AssemblySeconds',...
            'TotalSeconds','Gain','Accepted','Numerr','RelativeResidual','Error'});
        Timing=[Timing;row]; %#ok<AGROW>
        disp(row(:,1:7));
        save([outputBase '.mat'],'Timing','Details','metadata');
        writetable(Timing,[outputBase '.csv']);
    end
end
f=figure('Color','w');
tiledlayout(1,2);
nexttile; hold on;
for repeat=1:repetitions
    rows=Timing.Repeat==repeat;
    plot(Timing.Nu(rows),Timing.SolverSeconds(rows),'-o');
end
xlabel('Temporal filter order \nu'); ylabel('Solver-reported seconds'); grid on;
nexttile; hold on;
for repeat=1:repetitions
    rows=Timing.Repeat==repeat;
    plot(Timing.Nu(rows),Timing.TotalSeconds(rows),'-o');
end
xlabel('Temporal filter order \nu'); ylabel('Total synthesis seconds'); grid on;
sgtitle(sprintf('Boundary synthesis: alpha=%g, rho=%g, veryheavy',alpha,rho));
exportgraphics(f,[outputBase '.pdf'],'ContentType','vector');
exportgraphics(f,[outputBase '.png'],'Resolution',160);
% SolverSeconds: solver-reported solinfo.info.cpusec.
% TotalSeconds: filter/multiplier construction, LPI assembly, simplification,
% conversion, solve, and extraction; optional K recovery. Excludes startup
% and file/plot export. AssemblySeconds is before the synthesis executive.
% No analysis or simulation is performed. Failed runs remain in the table.

