clear; clc; close all; clear stateNameGenerator
echo off
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
exampleDir=fileparts(mfilename('fullpath'));
codeRoot=fileparts(fileparts(fileparts(exampleDir)));
addpath(genpath(codeRoot)); addpath(exampleDir,'-begin');
rmpath(fullfile(exampleDir,'compat'));

%% Settings: boundary-feedback synthesis only
runPoleSweep=false;               % Same single-point / sweep switch as Example 6
alpha=.5;                         % Repeated real uncertainty: |delta|<=alpha
nu=1;                             % Temporal basis order, as in Example 6
rho=-1;                           % Negative temporal pole
settings=lpisettings('veryheavy');
settings.sos_opts.solver='mosek';
settings.sos_opts.simplify=true;
settings.ddM=3;
settings.pointwise=false;
settings.kypSlackMode='normal';
settings.options1.sep=1;           % Separable storage for controller recovery
settings.options12.sep=1;
settings.controllerCleanTol=1e-10;
settings.kmax=1e4;
settings.recoverController=true;

%% Same heat/uncertainty interconnection as Example 6, with boundary control
pvar t s
a=0; b=1; kappa=.2; controlWeight=.1;
v=pde_var(2,s,[a,b]);
x_b=pde_var('state',1);
u=pde_var('control',1);
w_Delta=pde_var('input',2,s,[a,b]);
z_Delta=pde_var('output',2,s,[a,b]);
w_p=pde_var('input',1);
z_p=pde_var('output',1);
z_u=pde_var('output',1);
A0=[-2,-3;1,1]+kappa*pi^2/4*eye(2);
B_Delta=[1,0;0,0]; B_p=[1;0]; B_b=[1;0];
C_Delta=[1,0;0,0]; D_DeltaDelta=[1,-2;1,-1]; D_Deltap=[0;1];
C_p=[1,0]; D_pDelta=[0,1];

% x_b is the boundary flux state; its rate u is the control command.
% Performance is [z_p; z_u], with z_u penalizing the command.
PDE=[diff(v,t)==kappa*diff(v,s,2)+A0*v+B_Delta*w_Delta+s*B_p*w_p;
     diff(x_b,t)==u;
     z_Delta==C_Delta*diff(v,s)+D_DeltaDelta*w_Delta+D_Deltap*w_p;
     z_p==3*int(s*C_p*v,s,[a,b])+1.5*int((1-s^2)*D_pDelta*w_Delta,s,[a,b]);
     z_u==controlWeight*u;
     subs(v,s,a)==0;
     subs(diff(v,s),s,b)==B_b*x_b];
display_PDE(PDE);
P=convert(PDE);
inputDirection=P.B1.R.R0;
P.B1.R.R0=0*inputDirection;
P.B1.R.R1=inputDirection;
P.B1.R.R2=0*inputDirection;
assert(isequal(P.T.dim(:,1),[1;2]));
assert(isequal(P.B1.dim(:,2),[1;2]) && isequal(P.C1.dim(:,1),[2;2]));
assert(isequal(P.B2.dim(:,2),[1;0]));

%% Synthesize the boundary-feedback controller
% The synthesis executive uses the dual formulation.
% Alpha is in the static multiplier; the temporal filter is independent of it.
if ~runPoleSweep
    Synthesis=synthesize_boundary_gain(P,alpha,nu,rho,settings);
    K=Synthesis.K;
    save(fullfile(exampleDir,'Example_7_synthesis.mat'),'Synthesis','P','settings','-v7.3');
    fprintf('\nDual synthesis gain bound: %.9g; accepted=%d\n',Synthesis.gamma,Synthesis.feasible);
else
    alphaGrid=[.03,.27,.46,.60,.71,.80,.89,.96];
    rhoGrid=-logspace(3,-3,25);
    nuGrid=0:3;
    Results=struct('alpha',alphaGrid,'rho',rhoGrid,'nu',nuGrid,'side','dual',...
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
                    trial=synthesize_boundary_gain(P,alphaGrid(i),nuGrid(k),rhoGrid(j),settings);
                catch err
                    trial=struct('feasible',false,'gamma',NaN,'error',getReport(err));
                    fprintf('%s\n',trial.error);
                end
                if trial.feasible, Results.gamma(i,j,k)=trial.gamma; end
                Results.diagnostics{i,j,k}=trial;
                save(fullfile(exampleDir,'Example_7_Fig7_dual.mat'),'Results','P','settings','-v7.3');
            end
        end
    end
    save(fullfile(exampleDir,'Example_7_Fig7_dual.mat'),'Results','P','settings','-v7.3');
    plot_Example_7(Results);
end
% nu=0: K acts on [x_b;v_ss]. For nu>0, K includes filter-state gains.
% No closed-loop analysis or simulation is run by this script.
