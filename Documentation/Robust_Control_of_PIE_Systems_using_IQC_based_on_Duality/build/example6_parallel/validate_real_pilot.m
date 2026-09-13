clear stateNameGenerator
echo off
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath('C:/Program Files/Mosek/11.0/toolbox/r2019b'));
exampleDir=fileparts(mfilename('fullpath'));
codeRoot='C:/Users/thijs/Desktop/PIETOOLS-Duality/Code';
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


addpath(exampleDir,'-begin');
Pilot=Example_6_pilot_points(P,settings,exampleDir,certificateDir, ...
    {'primal','dual'},.03,0,-1000,2);
assert(isfinite(Pilot.primal.gamma) && isfinite(Pilot.dual.gamma));
assert(abs(Pilot.primal.gamma-.811696)<1e-4);
fprintf('REAL_PARALLEL_PILOT_PASSED: primal=%.9g dual=%.9g\n',Pilot.primal.gamma,Pilot.dual.gamma);
