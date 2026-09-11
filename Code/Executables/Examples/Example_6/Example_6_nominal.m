clear; clc; close all; clear stateNameGenerator
% Nominal dual L2-gain analysis, using the manuscript's notation.
% Default delta=0 REMOVES the uncertainty channels before constructing P^T.
% Optional fixed delta gives the corresponding known-parameter plant.
% Storage and slack degrees always come from lpisettings('veryheavy').
delta=0; % Nominal parameter; change this only for a known-parameter check.
side='dual'; % 'dual' or 'primal'
side=validatestring(side,{'dual','primal'});
assert(isscalar(delta) && isfinite(delta) && isreal(delta));
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
exampleDir=fileparts(mfilename('fullpath'));
codeRoot=fileparts(fileparts(fileparts(exampleDir)));
addpath(genpath(codeRoot));
rmpath(fullfile(exampleDir,'compat'));
here=fileparts(mfilename('fullpath'));
pvar t s
kappa=.2;
A=[-2,-3;1,1]; B_Delta=[1,0;0,0]; B_p=[1;0];
C_Delta=[1,0;0,0]; C_p=[1,0];
D_DeltaDelta=[1,-2;1,-1]; D_Deltap=[0;1]; D_pDelta=[0,1];
L=(eye(2)-delta*D_DeltaDelta)\(delta*eye(2));
A_delta=A+B_Delta*L*C_Delta;
B_delta=B_p+B_Delta*L*D_Deltap;
C_delta=C_p+D_pDelta*L*C_Delta;
D_delta=D_pDelta*L*D_Deltap;
assert(max(real(eig(A_delta)))<0,'The fixed-parameter plant is unstable.');

% Command-line PDE interface: known parameter, no uncertainty channels.
v=pde_var(2,s,[0,1]);
w_p=pde_var('input',1); z_p=pde_var('output',1);
PDE=[diff(v,t)==kappa*diff(v,s,2)+(A_delta+kappa*pi^2/4*eye(2))*v+s*B_delta*w_p;
     z_p==3*int(s*C_delta*v,s,[0,1])+D_delta*w_p;
     subs(v,s,0)==0;
     subs(diff(v,s),s,1)==0];
display_PDE(PDE);
P=convert(PDE); vars=P.vars; dom=P.dom;

% [P^T;I], with no uncertainty filter or uncertainty multiplier.
F=id_filter(P.B1.dim(:,2),P.C1.dim(:,1),vars,dom);
if strcmp(side,'dual'), G=PIETOOLS_IQC_dual_graph(P,F);
else, G=PIETOOLS_IQC_primal_graph(P,F); end
prog=lpiprogram(vars(:,1),vars(:,2),dom);
[prog,gammaSquared]=lpidecvar(prog,'gammaSquaredNominal');
prog=lpi_ineq(prog,gammaSquared);
prog=lpisetobj(prog,gammaSquared);
V_p=mat2opvar([1,0;0,-gammaSquared],[2;0],vars,dom);
settings=lpisettings('veryheavy'); settings.sos_opts.solver='mosek';
settings.sos_opts.simplify=true;
fprintf('Nominal %s analysis: delta=%g, settings=veryheavy\n',side,delta);
started=tic;

[storage,prog]=PIETOOLS_IQC_analysis(prog,settings,G,V_p);
i=prog.solinfo.info;
b=vertcat(prog.expr.b{:});
rr=prog.solinfo.residual/(1+norm(b));
accepted=i.pinf==0 && i.dinf==0 && i.numerr<=1 && abs(i.feasratio-1)<=.3 ...
    && isfinite(rr) && rr<=1e-5;
result=struct('delta',delta,'side',side,'settings','veryheavy',...
    'gamma',NaN,'feasible',accepted,'info',i,...
    'relativeResidual',rr,'seconds',toc(started));
result.rawSolverGainSquared=double(lpigetsol(prog,gammaSquared));
if accepted
    result.gamma=sqrt(result.rawSolverGainSquared);
    result.storage=storage;
end

% Independent reference: exact sine-mode expansion plus an analytic tail.
% Mixed-boundary eigenvalues are k_n^2, k_n=(n+1/2)*pi.
% G_delta(s)=D_delta+sum_n [6/k_n^4] C_delta(sI-A_n)^(-1)B_delta.
N=24; kn=((0:N-1)+.5)*pi; weights=6./kn.^4;
Am=cell(1,N); Bm=cell(N,1); Cm=cell(1,N);
for n=1:N
    Am{n}=A_delta-kappa*(kn(n)^2-pi^2/4)*eye(2);
    Bm{n}=sqrt(weights(n))*B_delta;
    Cm{n}=sqrt(weights(n))*C_delta;
end
modalTolerance=1e-9;
modalGain=hinfnorm(ss(blkdiag(Am{:}),vertcat(Bm{:}),horzcat(Cm{:}),D_delta),modalTolerance);
tailWeight=max(0,1-sum(weights))+1e-12;
lambdaTail=kappa*(((N+.5)*pi)^2-pi^2/4);
assert(lambdaTail>norm(A_delta,2));
tailBound=norm(C_delta,2)*norm(B_delta,2)*tailWeight/(lambdaTail-norm(A_delta,2));
result.modalReference=struct('modes',N,'gamma',modalGain,...
    'analyticTailBound',tailBound,'numericalRelativeTolerance',modalTolerance);
save(fullfile(here,['Example_6_nominal_' side '.mat']),'result');
disp(result);
fprintf('Modal reference: %.9g; omitted-mode bound %.3g\n',modalGain,tailBound);

function F=id_filter(d1,d2,vars,dom)
d0=[0;0];
F.T=zerosPI(d0,d0,vars,dom); F.A=F.T;
F.B1=zerosPI(d0,d1,vars,dom); F.B2=zerosPI(d0,d2,vars,dom);
F.C1=zerosPI(d1,d0,vars,dom); F.C2=zerosPI(d2,d0,vars,dom);
F.D11=eyePI(d1,vars,dom); F.D22=eyePI(d2,vars,dom);
F.D12=zerosPI(d1,d2,vars,dom); F.D21=zerosPI(d2,d1,vars,dom);
end


