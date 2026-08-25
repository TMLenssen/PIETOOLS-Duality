clear; clc; close all; clear stateNameGenerator
echo on

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b")) 
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
% =============================================
% === Declare the system of interest

% % Declare system as PDE
% Declare independent variables (time and space)
pvar t s
a=0;
b=1;
% Declare state, input, and output variables
x1 = pde_var(1,s,[a,b]);
x2 = pde_var('state');
zd1 = pde_var('output',1,s,[a,b]); wd1 = pde_var('input',1,s,[a,b]);
zd2 = pde_var('output',1,s,[a,b]); wd2 = pde_var('input',1,s,[a,b]);
z1 = pde_var('out');                w = pde_var('in');
z2 = pde_var('out');
y = pde_var('sense');              u = pde_var('control');
lam = 5;
dev = 0.8;
% Declare the sytem equations
PDE = [ diff(x1,t) == diff(x1,s,2) + lam*x1 + 0.1*w + dev*wd1 + dev*wd2;    % PDE
        diff(x2,t) == u;
        zd1 == diff(x1,s,2);
        zd2 == x1;
        z1 == x2;
        z2 == int(x1,s,[a,b]);                 % regulated output
        subs(x1,s,a) == 0;                        % first boundary condition
        subs(diff(x1,s,1),s,b) == x2];               % second boundary condition

display_PDE(PDE);

% % Convert PDE to PIE
P = convert(PDE);

Eye = @(n) eyePI(n, P.vars, P.dom);
Zeros = @(r,c) zerosPI(r,c, P.vars, P.dom);

% Feedthrough-only dual filter. It has no dynamic states, but the empty
% realization blocks must still have compatible PI dimensions.
wDim = P.B1.dim(:,2);
zDim = P.C1.dim(:,1);
filterStateDim = zeros(size(wDim));

DPsi.T = Zeros(filterStateDim,filterStateDim);
DPsi.A = Zeros(filterStateDim,filterStateDim);
DPsi.B1 = Zeros(filterStateDim,wDim);
DPsi.B2 = Zeros(filterStateDim,zDim);
DPsi.C1 = Zeros(wDim,filterStateDim);
DPsi.C2 = Zeros(zDim,filterStateDim);
DPsi.D11 = Eye(wDim);
DPsi.D12 = Zeros(wDim,zDim);
DPsi.D21 = Zeros(zDim,wDim);
DPsi.D22 = Eye(zDim);

settings = lpisettings('veryheavy');
settings.ddM = 5;
settings.epneg = 1e-8;

%% Start the synthesis program and define Vbar before the executive
progSynth = lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[progSynth,muD] = lpidecvar(progSynth,'muD');
[progSynth,rhoD] = lpidecvar(progSynth,'rhoD');
progSynth = lpi_ineq(progSynth,muD-1e-4);
progSynth = lpi_ineq(progSynth,rhoD);
progSynth = lpisetobj(progSynth,rhoD);

for k = 1:2
    [progSynth, Q_blocks{k}] = poslpivar(progSynth, [0, 0; 1, 1], settings.ddM, settings.options1);
end
Q = blkdiag(Q_blocks{:});
for k = 1:2
    [progSynth, S_blocks{k}] = lpivar(progSynth, [0, 0; 1, 1], settings.ddM, settings.options1);
end
S = blkdiag(S_blocks{:});

% Assemble the finite and distributed parameters directly. dopvar does
% not overload matrix-style subsasgn, so expressions such as Vbar(1,1)=...
% would create an object array rather than index the PI operator.
vbarDim = P.C1.dim(:,1)+P.B1.dim(:,2);
Vbar = opvar2dopvar(Zeros(vbarDim,vbarDim));
Vbar.P = blkdiag(1,-rhoD*eye(2));
VbarDistributed = [Q, S-S';
                   S'-S, -Q];
Vbar.R = VbarDistributed.R;


[K,Zsynth,Psynth,progSynth] = PIETOOLS_IQC_controller_synthesis(progSynth,settings,P,DPsi,Vbar);

muDValue = double(lpigetsol(progSynth,muD));
rhoDValue = double(lpigetsol(progSynth,rhoD));
