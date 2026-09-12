clear; clc; close all; clear stateNameGenerator
echo off
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
exampleDir=fileparts(mfilename('fullpath'));
codeRoot=fileparts(fileparts(fileparts(exampleDir)));
addpath(genpath(codeRoot));
rmpath(fullfile(exampleDir,'compat')); % Enable the sparse fix only during a solve.

%% Settings
settings=lpisettings('heavy');
settings.sos_opts.solver='mosek';
settings.sos_opts.simplify=true;
settings.ddM=3;
settings.kypSlackMode='normal';
settings.options1.sep=0;
settings.options12.sep=0;
resumeSweep=true;                % Resume compatible checkpoints after interruption.
runPoleSweep=true;               % Set true to reproduce all three Fig. 7 panels
sides={'primal','dual'};          % Both sides are needed for their subtraction
assert(isequal(sort(sides),{'dual','primal'}), ...
    'sides must contain exactly ''primal'' and ''dual''.');
alpha=0.5;                        % Uncertainty radius: |delta|<=alpha
nu=1;                             % Temporal basis order
rho=-1;                           % Negative temporal pole

% Each solve runs in a fresh MATLAB process so solver/allocator memory cannot
% accumulate across the sweep. Store full certificates on disk, not in RAM.
certificateRoot=fullfile(exampleDir,'Example_6_certificates');
if ~isfolder(certificateRoot), mkdir(certificateRoot); end
certificateDir=tempname(certificateRoot);
mkdir(certificateDir);

%% Coupled heat equations
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

% The state equation initially uses a pointwise w_Delta input.
% The performance integral already incorporates J:
% 3 int_0^1 s D_pDelta Jw_Delta ds = 1.5 int_0^1 (1-s^2)D_pDelta w_Delta ds.
PDE=[diff(v,t)==diff(v,s,2)+A*v+B_Delta*w_Delta+s*B_p*w_p;
     z_Delta==C_Delta*diff(v,s)+D_DeltaDelta*w_Delta+D_Deltap*w_p;
     z_p==int(C_p*v,s,[a,b])+int((1-s^2)*D_pDelta*w_Delta,s,[a,b]);
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
    Pilot=struct;
    for sideIndex=1:numel(sides)
        side=sides{sideIndex};
        certificateFile=fullfile(certificateDir,['pilot_' side '.mat']);
        Results=Example_6_run_point(P,alpha,nu,rho,settings,exampleDir,side,certificateFile);
        Pilot.(side)=struct('alpha',alpha,'rho',rho,'nu',nu,'side',side, ...
            'gamma',Results.gamma);
        Example_6_save_checkpoint(fullfile(exampleDir,['Example_6_pilot_' side '.mat']), ...
            'Results',Results);
        Example_6_save_checkpoint(fullfile(exampleDir,'Example_6_pilot_comparison.mat'), ...
            'Pilot',Pilot);
        fprintf('\n%s gain bound: %.9g; accepted=%d\n', ...
            side,Results.gamma,Results.feasible);
        clear Results
    end
    Example_6_save_checkpoint(fullfile(exampleDir,'Example_6_pilot_comparison.mat'),'Pilot',Pilot);
    plot_Example_6(Pilot.primal,Pilot.dual);
else
    alphaGrid=[.03,.27,.46,.60,.71,.80,.89,.96];
    rhoGrid=-logspace(3,-3,1);
    nuGrid=0;
    configuration=struct('plant',P,'settings',settings,'alpha',alphaGrid, ...
        'rho',rhoGrid,'nu',nuGrid);
    Comparison=struct;
    for sideIndex=1:numel(sides)
        side=sides{sideIndex};
        Results=struct('alpha',alphaGrid,'rho',rhoGrid,'nu',nuGrid,'side',side,...
            'gamma',nan(numel(alphaGrid),numel(rhoGrid),numel(nuGrid)),...
            'completed',false(numel(alphaGrid),numel(rhoGrid),numel(nuGrid)), ...
            'configuration',configuration);
        checkpointFile=fullfile(exampleDir,['Example_6_Fig7_' side '.mat']);
        if resumeSweep && isfile(checkpointFile)
            previous=load(checkpointFile,'Results');
            if isfield(previous,'Results') && isfield(previous.Results,'configuration') ...
                    && isfield(previous.Results,'completed') ...
                    && strcmp(previous.Results.side,side) ...
                    && isequaln(previous.Results.configuration,configuration)
                Results=previous.Results;
                fprintf('Resuming %s: %d/%d points complete.\n', ...
                    side,nnz(Results.completed),numel(Results.completed));
            end
            clear previous
        end
        % Migrate older in-memory diagnostics once, then retain only arrays
        % and a directory name. Detailed results are loaded only on request.
        Results=Example_6_disk_results(Results,fullfile(certificateDir,side));
        Example_6_save_checkpoint(checkpointFile,'Results',Results);
        for k=1:numel(nuGrid)
            for j=1:numel(rhoGrid)
                for i=1:numel(alphaGrid)
                    if Results.completed(i,j,k), continue; end
                    if nuGrid(k)==0 && j>1
                        Results.gamma(i,j,k)=Results.gamma(i,1,k);
                        Results.completed(i,j,k)=Results.completed(i,1,k);
                        Example_6_save_checkpoint(checkpointFile,'Results',Results);
                        continue % The static multiplier is independent of rho.
                    end
                    try
                        certificateFile=fullfile(certificateDir, ...
                            sprintf('%s_a%d_r%d_n%d.mat',side,i,j,k));
                        trial=Example_6_run_point(P,alphaGrid(i),nuGrid(k), ...
                            rhoGrid(j),settings,exampleDir,side,certificateFile);
                    catch err
                        trial=struct('feasible',false,'gamma',NaN,'error',getReport(err));
                        fprintf('%s\n',trial.error);
                    end
                    if trial.feasible, Results.gamma(i,j,k)=trial.gamma; end
                    diagnosticFile=fullfile(Results.diagnosticsDirectory, ...
                        sprintf('a%d_r%d_n%d.mat',i,j,k));
                    Example_6_save_checkpoint(diagnosticFile,'trial',trial);
                    Results.completed(i,j,k)=~isfield(trial,'error');
                    clear trial
                    Example_6_save_checkpoint(checkpointFile,'Results',Results);
                    fprintf('Checkpoint saved: %s (%d/%d complete)\n', ...
                        side,nnz(Results.completed),numel(Results.completed));
                end
            end
        end
        Comparison.(side)=rmfield(Results,{'configuration','completed'});
        clear Results
    end
    Example_6_save_checkpoint(fullfile(exampleDir,'Example_6_Fig7_comparison.mat'), ...
        'Comparison',Comparison);
    plot_Example_6(Comparison.primal,Comparison.dual);
end
