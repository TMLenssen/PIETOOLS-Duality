clear stateNameGenerator
echo off
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
exampleDir='C:/Users/thijs/Desktop/PIETOOLS-Duality/Code/Executables/Examples/Example_6';
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
runPoleSweep=true;               % Set true to reproduce all three Fig. 7 panels
sides={'primal','dual'};          % Both sides are needed for their subtraction
assert(isequal(sort(sides),{'dual','primal'}), ...
    'sides must contain exactly ''primal'' and ''dual''.');
alpha=0.5;                        % Uncertainty radius: |delta|<=alpha
nu=1;                             % Temporal basis order
rho=-1;                           % Negative temporal pole

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


stagedDir='C:/Users/thijs/Desktop/PIETOOLS-Duality/Documentation/Robust_Control_of_PIE_Systems_using_IQC_based_on_Duality/build/example6_memory_fix';
addpath(stagedDir,'-begin');
for name={'Example_6.m','Example_6_run_point.m','Example_6_worker.m','Example_6_save_checkpoint.m'}
    issues=checkcode(fullfile(stagedDir,name{1}),'-id');
    disp(issues);
    assert(~any(strcmp({issues.id},'PARSE')),'MATLAB parse error.');
end
checkpoint=fullfile(stagedDir,'test_checkpoint.mat');
Example_6_save_checkpoint(checkpoint,'Results',struct('gamma',1));
Example_6_save_checkpoint(checkpoint,'Results',struct('gamma',2));
saved=load(checkpoint,'Results');
assert(saved.Results.gamma==2);
[before,~]=memory;
for repeat=1:2
    certificateFile=fullfile(stagedDir,sprintf('test_certificate_%d.mat',repeat));
    results{repeat}=Example_6_run_point(P,.03,0,-1000,settings,stagedDir,'primal',certificateFile);
    assert(~isfield(results{repeat},'storage') && ~isfield(results{repeat},'multiplier'));
    if results{repeat}.feasible
        cert=load(results{repeat}.certificateFile,'result');
        assert(isfield(cert.result,'storage') && isfield(cert.result,'multiplier'));
        clear cert
    end
    usage=memory;
    fprintf('PARENT_MEMORY_MB after run %d: %.1f\n',repeat,usage.MemUsedMATLAB/2^20);
end
assert(isequaln(results{1}.feasible,results{2}.feasible));
assert(abs(results{1}.candidateGamma-results{2}.candidateGamma)<1e-4*max(1,results{1}.candidateGamma));
fprintf('MEMORY_FIX_TESTS_PASSED baseline_parent_MB=%.1f\n',before.MemUsedMATLAB/2^20);
save(fullfile(stagedDir,'validation_results.mat'),'results','before','usage');
