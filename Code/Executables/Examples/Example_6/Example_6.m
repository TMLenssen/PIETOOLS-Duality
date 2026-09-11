clear; clc; close all; clear stateNameGenerator
echo off
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
exampleDir=fileparts(mfilename('fullpath'));
codeRoot=fileparts(fileparts(fileparts(exampleDir)));
addpath(genpath(codeRoot));
rmpath(fullfile(exampleDir,'compat')); % Enable the sparse fix only during a solve.

%% Settings
settings=lpisettings('veryheavy');
settings.sos_opts.solver='mosek';
settings.sos_opts.simplify=true;
settings.ddM=3;
settings.pointwise=false;          % Full spatial Q_Delta and S_Delta
settings.kypSlackMode='normal';
settings.options1.sep=0;
settings.options12.sep=0;
settings.residualTolerance=1e-1;    % Relative equality residual; retain raw values
runPoleSweep=false;               % Start with one directly optimized pilot
side='dual';                     % 'dual' or 'primal': same plant and IQC family
side=validatestring(side,{'dual','primal'});
alpha=0.5;                        % Uncertainty radius: |delta|<=alpha
nu=1;                             % Temporal basis order
rho=-1;                           % Negative temporal pole

%% Coupled heat equations
pvar t s
a=0; b=1; kappa=.2;
v=pde_var(2,s,[a,b]);
w_Delta=pde_var('input',2,s,[a,b]);
z_Delta=pde_var('output',2,s,[a,b]);
w_p=pde_var('input',1);
z_p=pde_var('output',1);
A0=[-2,-3;1,1]+kappa*pi^2/4*eye(2);
B_Delta=[1,0;0,0]; B_p=[1;0]; C_Delta=[1,0;0,0];
D_DeltaDelta=[1,-2;1,-1]; D_Deltap=[0;1];
C_p=[1,0]; D_pDelta=[0,1];

% The state equation initially uses a pointwise w_Delta input.
% The performance integral already incorporates J:
% 3 int_0^1 s D_pDelta Jw_Delta ds = 1.5 int_0^1 (1-s^2)D_pDelta w_Delta ds.
PDE=[diff(v,t)==kappa*diff(v,s,2)+A0*v+B_Delta*w_Delta+s*B_p*w_p;
     z_Delta==C_Delta*diff(v,s)+D_DeltaDelta*w_Delta+D_Deltap*w_p;
     z_p==3*int(s*C_p*v,s,[a,b])+1.5*int((1-s^2)*D_pDelta*w_Delta,s,[a,b]);
     subs(v,s,a)==0;
     subs(diff(v,s),s,b)==0];
display_PDE(PDE);
P=convert(PDE);

% Replace B_Delta*w_Delta by B_Delta*J*w_Delta, as in Example 2.
inputDirection=P.B1.R.R0;
P.B1.R.R0=0*inputDirection;
P.B1.R.R1=inputDirection;
P.B1.R.R2=0*inputDirection;
assert(isequal(P.B1.dim(:,2),[1;2]) && isequal(P.C1.dim(:,1),[1;2]));

%% Robustness analysis
% Delta=delta*I is self-adjoint. The same hard IQC family applies to P^T.
% Alpha is in V_Delta; the temporal filter is independent of alpha.
if ~runPoleSweep
    Results=analyze_point(P,alpha,nu,rho,settings,exampleDir,side);
    save(fullfile(exampleDir,['Example_6_pilot_' side '.mat']),'Results','-v7.3');
    fprintf('\n%s gain bound: %.9g; accepted=%d\n',side,Results.gamma,Results.feasible);
else
    alphaGrid=[.03,.27,.46,.60,.71,.80,.89,.96];
    rhoGrid=-logspace(3,-3,25);
    nuGrid=0:3;
    Results=struct('alpha',alphaGrid,'rho',rhoGrid,'nu',nuGrid,'side',side,...
        'gamma',nan(numel(alphaGrid),numel(rhoGrid),numel(nuGrid)),...
        'diagnostics',{cell(numel(alphaGrid),numel(rhoGrid),numel(nuGrid))});
    for k=1:numel(nuGrid)
        for j=1:numel(rhoGrid)
            for i=1:numel(alphaGrid)
                if nuGrid(k)==0 && j>1
                    Results.gamma(i,j,k)=Results.gamma(i,1,k);
                    Results.diagnostics{i,j,k}=Results.diagnostics{i,1,k};
                    continue % The static multiplier is independent of rho.
                end
                try
                    trial=analyze_point(P,alphaGrid(i),nuGrid(k),rhoGrid(j),settings,exampleDir,side);
                catch err
                    trial=struct('feasible',false,'gamma',NaN,'error',getReport(err));
                    fprintf('%s\n',trial.error);
                end
                if trial.feasible, Results.gamma(i,j,k)=trial.gamma; end
                Results.diagnostics{i,j,k}=trial;
                save(fullfile(exampleDir,['Example_6_Fig7_' side '.mat']),'Results','-v7.3');
            end
        end
    end
    plot_Example_6(Results);
end

function result=analyze_point(P,alpha,nu,rho,settings,exampleDir,side)
fprintf('\n%s analysis: alpha=%g, nu=%d, rho=%g, veryheavy\n',side,alpha,nu,rho);
started=tic;
DPsi=lifted_basis(nu,rho,P.vars,P.dom);
if strcmp(side,'dual')
    GD=PIETOOLS_IQC_dual_graph(P,DPsi);
else
    GD=PIETOOLS_IQC_primal_graph(P,DPsi);
end
prog=lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,gammaSquared]=lpidecvar(prog,'gammaSquared');
prog=lpi_ineq(prog,gammaSquared);
m=2*(nu+1);
[prog,Vd]=PIETOOLS_IQC_repeated_real(prog,[1;m],[1;m],alpha,settings,P.vars,P.dom);
Vd.P=blkdiag(1,-gammaSquared);
prog=lpisetobj(prog,gammaSquared);
oldPath=path;
addpath(fullfile(exampleDir,'compat'),'-begin');
cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
[storage,prog]=PIETOOLS_IQC_analysis(prog,settings,GD,Vd);
info=prog.solinfo.info;
result=struct('alpha',alpha,'nu',nu,'rho',rho,'side',side,...
    'gamma',NaN,'info',info,'residual',prog.solinfo.residual,'seconds',toc(started));
b=vertcat(prog.expr.b{:});
result.relativeResidual=result.residual/(1+norm(b));
result.feasible=info.pinf==0 && info.dinf==0 && info.numerr<=1 ...
    && isfinite(info.feasratio) && abs(info.feasratio-1)<=.3;
result.rawSolverGainSquared=double(lpigetsol(prog,gammaSquared));
result.candidateGamma=sqrt(max(0,result.rawSolverGainSquared));
result.residualTolerance=settings.residualTolerance;
result.feasible=result.feasible && isfinite(result.rawSolverGainSquared) && result.rawSolverGainSquared>=0;
if result.feasible
    result.gamma=sqrt(result.rawSolverGainSquared);
    result.storage=storage;
    result.multiplier=lpigetsol(prog,Vd);
end
fprintf('gamma=%g, accepted=%d, residual=%.3g, FR=%.5g, numerr=%g, elapsed=%.1fs\n',...
    result.gamma,result.feasible,result.residual,info.feasratio,info.numerr,result.seconds);
fprintf('Candidate gamma=%g; relative residual=%.3g; cutoff=%.3g\n',...
    result.candidateGamma,result.relativeResidual,result.residualTolerance);
if result.relativeResidual>result.residualTolerance
    fprintf('Rejected by the additional relative-residual cutoff.\n');
end
end

function F=lifted_basis(nu,rho,vars,dom)
% R0 lift of [1,(-rho)/(s-rho),...,((-rho)/(s-rho))^nu].
% Output scaling is an invertible congruence of Veenman's basis (12a).
assert(nu>=0 && nu==floor(nu) && rho<0);
n=2*nu; m=2*(nu+1);
if nu==0
    A=zeros(0); B=zeros(0,2); C=zeros(2,0); D=eye(2);
else
    A=kron(rho*eye(nu)-rho*diag(ones(nu-1,1),-1),eye(2));
    B=kron(-rho*[1;zeros(nu-1,1)],eye(2));
    C=kron([zeros(1,nu);eye(nu)],eye(2));
    D=kron([1;zeros(nu,1)],eye(2));
end
F.vars=vars; F.dom=dom;
F.T=eyePI([0;2*n],vars,dom);
F.A=mat2opvar(blkdiag(A,A),[0;2*n],vars,dom);
F.B1=zerosPI([0;2*n],[1;2],vars,dom); F.B1.R.R0=[B;zeros(n,2)];
F.B2=zerosPI([0;2*n],[1;2],vars,dom); F.B2.R.R0=[zeros(n,2);B];
F.C1=zerosPI([1;m],[0;2*n],vars,dom); F.C1.R.R0=[C,zeros(m,n)];
F.C2=zerosPI([1;m],[0;2*n],vars,dom); F.C2.R.R0=[zeros(m,n),C];
F.D11=zerosPI([1;m],[1;2],vars,dom); F.D11.P=1; F.D11.R.R0=D;
F.D22=zerosPI([1;m],[1;2],vars,dom); F.D22.P=1; F.D22.R.R0=D;
F.D12=zerosPI([1;m],[1;2],vars,dom);
F.D21=F.D12;
end
