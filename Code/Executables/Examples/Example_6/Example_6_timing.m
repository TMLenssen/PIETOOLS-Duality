clear; clc; close all; clear stateNameGenerator
% One matched primal/dual timing run for every temporal filter order.
% This script does not run the alpha/pole sweep used for Figure 7.

nuGrid=0:3;
repetitions=1;
alpha=0.5;
rho=-1;
assert(all(nuGrid>=0 & nuGrid==floor(nuGrid)) && repetitions==1);

here=fileparts(mfilename('fullpath'));
codeRoot=fileparts(fileparts(fileparts(here)));
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
addpath(genpath(codeRoot));
rmpath(fullfile(here,'compat'));

settings=lpisettings('heavy');              %Modify heavy settings such that n1=3, n2=n3=2
settings.sos_opts.solver='mosek';
settings.sos_opts.simplify=true;
settings.ddM=3;
settings.pointwise=false;
settings.kypSlackMode='normal';
settings.options1.sep=0;
settings.options12.sep=0;
settings.residualTolerance=1e-1;

%% Unshifted unit-diffusion coupled heat equations
pvar t s
a=0; b=1;
v=pde_var(2,s,[a,b]);
w_Delta=pde_var('input',2,s,[a,b]);
z_Delta=pde_var('output',2,s,[a,b]);
w_p=pde_var('input',1);
z_p=pde_var('output',1);
A=[-2,-3;1,1]+(pi^2/4)*eye(2);
B_Delta=[1,0;0,0]; B_p=[1;0]; C_Delta=[1,0;0,0];
D_DeltaDelta=[1,-2;1,-1]; D_Deltap=[0;1];
C_p=[1,0]; D_pDelta=[0,1];

PDE=[diff(v,t)==diff(v,s,2)+A*v+B_Delta*w_Delta+s*B_p*w_p;
     z_Delta==C_Delta*diff(v,s)+D_DeltaDelta*w_Delta+D_Deltap*w_p;
     z_p==int(C_p*v,s,[a,b]) +int((1-s^2)*D_pDelta*w_Delta,s,[a,b]);
     subs(v,s,a)==0;
     subs(diff(v,s),s,b)==0];
P=convert(PDE);

% Replace the pointwise uncertainty input by J*w_Delta.
inputDirection=P.B1.R.R0;
P.B1.R.R0=0*inputDirection;
P.B1.R.R1=inputDirection;
P.B1.R.R2=0*inputDirection;

%% One timing run per side and filter order
sides={'primal','dual'};
Timing=table;
Details=cell(numel(nuGrid),numel(sides));
outputBase=fullfile(here,'Example_6_timing');
metadata=struct('task','analysis','model','unit-diffusion-unshifted', ...
    'alpha',alpha,'rho',rho,'nuGrid',nuGrid,'repetitions',repetitions, ...
    'settings',settings,'matlabVersion',version,'started',datetime('now'));

for k=1:numel(nuGrid)
    for sideIndex=1:numel(sides)
        nu=nuGrid(k);
        side=sides{sideIndex};
        errorText="";
        try
            result=time_analysis(P,alpha,nu,rho,settings,here,side);
            solverSeconds=result.solverSeconds;
            graphAssemblySeconds=result.graphAssemblySeconds;
            totalSeconds=result.totalSeconds;
            gain=result.gamma;
            accepted=result.feasible;
            numerr=result.info.numerr;
            relativeResidual=result.relativeResidual;
            Details{k,sideIndex}=result;
        catch err
            solverSeconds=NaN;
            graphAssemblySeconds=NaN;
            totalSeconds=NaN;
            gain=NaN;
            accepted=false;
            numerr=NaN;
            relativeResidual=NaN;
            errorText=string(getReport(err,'extended','hyperlinks','off'));
            Details{k,sideIndex}=struct('error',errorText);
        end
        row=table(nu,1,string(side),solverSeconds,graphAssemblySeconds, ...
            totalSeconds,gain,accepted,numerr,relativeResidual,errorText, ...
            'VariableNames',{'Nu','Repeat','Side','SolverSeconds', ...
            'GraphAssemblySeconds','TotalSeconds','Gain','Accepted', ...
            'Numerr','RelativeResidual','Error'});
        Timing=[Timing;row]; %#ok<AGROW>
        disp(row(:,1:8));
        save([outputBase '.mat'],'Timing','Details','metadata','-v7.3');
        writetable(Timing,[outputBase '.csv']);
    end
end

paperFigureDir=fullfile(fileparts(codeRoot),'Documentation', ...
    'Robust_Control_of_PIE_Systems_using_IQC_based_on_Duality','Figures');
if isfolder(paperFigureDir)
    write_latex_table(Timing, ...
        fullfile(paperFigureDir,'example1_timing_table.tex'),alpha,rho);
end

function result=time_analysis(P,alpha,nu,rho,settings,here,side)
totalTimer=tic;
assemblyTimer=tic;
Psi=lifted_basis(nu,rho,P.vars,P.dom);
if strcmp(side,'dual')
    G=PIETOOLS_IQC_dual_graph(P,Psi);
else
    G=PIETOOLS_IQC_primal_graph(P,Psi);
end
prog=lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,gammaSquared]=lpidecvar(prog,['gammaSquared_' side]);
prog=lpi_ineq(prog,gammaSquared);
m=2*(nu+1);
[prog,V]=PIETOOLS_IQC_repeated_real( ...
    prog,[1;m],[1;m],alpha,settings,P.vars,P.dom);
V.P=blkdiag(1,-gammaSquared);
prog=lpisetobj(prog,gammaSquared);
graphAssemblySeconds=toc(assemblyTimer);

oldPath=path;
addpath(fullfile(here,'compat'),'-begin');
pathCleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
[~,prog]=PIETOOLS_IQC_analysis(prog,settings,G,V);
info=prog.solinfo.info;
b=vertcat(prog.expr.b{:});
relativeResidual=prog.solinfo.residual/(1+norm(b));
rawGainSquared=double(lpigetsol(prog,gammaSquared));
feasible=info.pinf==0 && info.dinf==0 && info.numerr<=1 ...
    && isfinite(info.feasratio) && abs(info.feasratio-1)<=.3 ...
    && isfinite(rawGainSquared) && rawGainSquared>=0 ...
    && isfinite(relativeResidual) ...
    && relativeResidual<=settings.residualTolerance;
result=struct('alpha',alpha,'nu',nu,'rho',rho,'side',side, ...
    'gamma',NaN,'feasible',feasible,'info',info, ...
    'solverSeconds',double(info.cpusec), ...
    'graphAssemblySeconds',graphAssemblySeconds, ...
    'totalSeconds',toc(totalTimer),'residual',prog.solinfo.residual, ...
    'relativeResidual',relativeResidual,'rawGainSquared',rawGainSquared);
if feasible, result.gamma=sqrt(rawGainSquared); end
end

function F=lifted_basis(nu,rho,vars,dom)
n=2*nu;
m=2*(nu+1);
if nu==0
    Af=zeros(0); Bf=zeros(0,2); Cf=zeros(2,0); Df=eye(2);
else
    Af=kron(rho*eye(nu)-rho*diag(ones(nu-1,1),-1),eye(2));
    Bf=kron(-rho*[1;zeros(nu-1,1)],eye(2));
    Cf=kron([zeros(1,nu);eye(nu)],eye(2));
    Df=kron([1;zeros(nu,1)],eye(2));
end
F.vars=vars; F.dom=dom;
F.T=eyePI([0;2*n],vars,dom);
F.A=mat2opvar(blkdiag(Af,Af),[0;2*n],vars,dom);
F.B1=zerosPI([0;2*n],[1;2],vars,dom); F.B1.R.R0=[Bf;zeros(n,2)];
F.B2=zerosPI([0;2*n],[1;2],vars,dom); F.B2.R.R0=[zeros(n,2);Bf];
F.C1=zerosPI([1;m],[0;2*n],vars,dom); F.C1.R.R0=[Cf,zeros(m,n)];
F.C2=zerosPI([1;m],[0;2*n],vars,dom); F.C2.R.R0=[zeros(m,n),Cf];
F.D11=zerosPI([1;m],[1;2],vars,dom); F.D11.P=1; F.D11.R.R0=Df;
F.D22=zerosPI([1;m],[1;2],vars,dom); F.D22.P=1; F.D22.R.R0=Df;
F.D12=zerosPI([1;m],[1;2],vars,dom);
F.D21=F.D12;
end

function write_latex_table(Timing,fileName,alpha,rho)
fid=fopen(fileName,'w');
assert(fid>=0,'Could not open %s for writing.',fileName);
fileCleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'\\begin{table}[t]\n');
fprintf(fid,' \\centering\n');
fprintf(fid,[' \\caption{One-shot computation times at $\\alpha=%.2g$ ' ...
    'and $\\rho=%.2g$.}\\label{tab:coupled-heat-timing}\n'],alpha,rho);
fprintf(fid,' \\begin{tabular}{c@{\\qquad}cc}\n');
fprintf(fid,'  \\hline\n');
fprintf(fid,'  Filter order $\\nu$ & Primal (s) & Dual (s)\\\\\n');
fprintf(fid,'  \\hline\n');
for nu=unique(Timing.Nu).'
    p=Timing(Timing.Nu==nu & Timing.Side=="primal",:);
    d=Timing(Timing.Nu==nu & Timing.Side=="dual",:);
    if isempty(p) || ~isfinite(p.TotalSeconds), pText='---';
    else, pText=sprintf('%.1f',p.TotalSeconds); end
    if isempty(d) || ~isfinite(d.TotalSeconds), dText='---';
    else, dText=sprintf('%.1f',d.TotalSeconds); end
    fprintf(fid,'  %d & %s & %s\\\\\n',nu,pText,dText);
end
fprintf(fid,'  \\hline\n');
fprintf(fid,' \\end{tabular}\n');
fprintf(fid,'\\end{table}\n');
end
