clear; clc; close all; clear stateNameGenerator
% Nominal or known-parameter L2-gain analysis for both primal and dual PIEs.
% With delta=0, the uncertainty channels are removed before constructing
% either graph. A nonzero delta gives the corresponding fixed-parameter plant.

delta=0;
sides={'primal','dual'};
assert(isscalar(delta) && isfinite(delta) && isreal(delta));
assert(isequal(sort(sides),{'dual','primal'}), ...
    'sides must contain exactly ''primal'' and ''dual''.');

addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
exampleDir=fileparts(mfilename('fullpath'));
codeRoot=fileparts(fileparts(fileparts(exampleDir)));
addpath(genpath(codeRoot));
rmpath(fullfile(exampleDir,'compat'));

%% Fixed-parameter coupled heat equations
pvar t s
A=[-2,-3;1,1];
B_Delta=[1,0;0,0]; B_p=[1;0];
C_Delta=[1,0;0,0]; C_p=[1,0];
D_DeltaDelta=[1,-2;1,-1]; D_Deltap=[0;1]; D_pDelta=[0,1];

% Eliminate w_Delta=delta*z_Delta from the J-filtered interconnection.
L=(eye(2)-delta*D_DeltaDelta)\(delta*eye(2));
A_delta=A+B_Delta*L*C_Delta;
B_delta=B_p+B_Delta*L*D_Deltap;
C_delta=C_p+D_pDelta*L*C_Delta;
D_delta=D_pDelta*L*D_Deltap;
assert(max(real(eig(A_delta)))<pi^2/4, ...
    'The fixed-parameter PDE is unstable at this delta.');

v=pde_var(2,s,[0,1]);
w_p=pde_var('input',1);
z_p=pde_var('output',1);
PDE=[diff(v,t)==diff(v,s,2)+A_delta*v+s*B_delta*w_p;
     z_p==3*int(s*C_delta*v,s,[0,1])+D_delta*w_p;
     subs(v,s,0)==0;
     subs(diff(v,s),s,1)==0];
display_PDE(PDE);
P=convert(PDE);

settings=lpisettings('veryheavy');
settings.sos_opts.solver='mosek';
settings.sos_opts.simplify=true;
settings.residualTolerance=1e-5;

%% Matched primal and dual nominal analyses
Results=struct;
for sideIndex=1:numel(sides)
    side=sides{sideIndex};
    Results.(side)=analyze_nominal(P,settings,side,delta);
    result=Results.(side); %#ok<NASGU>
    save(fullfile(exampleDir,['Example_6_nominal_' side '.mat']), ...
        'result','-v7.3');
end
save(fullfile(exampleDir,'Example_6_nominal_comparison.mat'), ...
    'Results','delta','-v7.3');

fprintf('\nNominal comparison at delta=%g\n',delta);
fprintf('Primal gain: %.9g; accepted=%d; elapsed=%.1fs\n', ...
    Results.primal.gamma,Results.primal.feasible,Results.primal.seconds);
fprintf('Dual gain:   %.9g; accepted=%d; elapsed=%.1fs\n', ...
    Results.dual.gamma,Results.dual.feasible,Results.dual.seconds);
if Results.primal.feasible && Results.dual.feasible
    fprintf('Primal-dual difference: %.3e\n', ...
        Results.primal.gamma-Results.dual.gamma);
end

function result=analyze_nominal(P,settings,side,delta)
vars=P.vars; dom=P.dom;
F=id_filter(P.B1.dim(:,2),P.C1.dim(:,1),vars,dom);
if strcmp(side,'dual')
    G=PIETOOLS_IQC_dual_graph(P,F);
else
    G=PIETOOLS_IQC_primal_graph(P,F);
end

prog=lpiprogram(vars(:,1),vars(:,2),dom);
[prog,gammaSquared]=lpidecvar(prog,['gammaSquaredNominal_' side]);
prog=lpi_ineq(prog,gammaSquared);
prog=lpisetobj(prog,gammaSquared);
V_p=mat2opvar([1,0;0,-gammaSquared],[2;0],vars,dom);
fprintf('\nNominal %s analysis: delta=%g, settings=veryheavy\n',side,delta);
started=tic;
[storage,prog]=PIETOOLS_IQC_analysis(prog,settings,G,V_p);

info=prog.solinfo.info;
b=vertcat(prog.expr.b{:});
relativeResidual=prog.solinfo.residual/(1+norm(b));
rawGainSquared=double(lpigetsol(prog,gammaSquared));
feasible=info.pinf==0 && info.dinf==0 && info.numerr<=1 ...
    && isfinite(info.feasratio) && abs(info.feasratio-1)<=.3 ...
    && isfinite(relativeResidual) ...
    && relativeResidual<=settings.residualTolerance ...
    && isfinite(rawGainSquared) && rawGainSquared>=0;

result=struct('delta',delta,'side',side,'settings','veryheavy', ...
    'gamma',NaN,'feasible',feasible,'info',info, ...
    'residual',prog.solinfo.residual, ...
    'relativeResidual',relativeResidual,'seconds',toc(started), ...
    'rawSolverGainSquared',rawGainSquared);
if feasible
    result.gamma=sqrt(rawGainSquared);
    result.storage=storage;
end
end

function F=id_filter(d1,d2,vars,dom)
d0=zeros(size(d1));
F.T=zerosPI(d0,d0,vars,dom);
F.A=F.T;
F.B1=zerosPI(d0,d1,vars,dom);
F.B2=zerosPI(d0,d2,vars,dom);
F.C1=zerosPI(d1,d0,vars,dom);
F.C2=zerosPI(d2,d0,vars,dom);
F.D11=eyePI(d1,vars,dom);
F.D22=eyePI(d2,vars,dom);
F.D12=zerosPI(d1,d2,vars,dom);
F.D21=zerosPI(d2,d1,vars,dom);
end
