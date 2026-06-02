%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This code computes the P^{1/2}, where 
%               P > 0 -- PD PI operator 
% 
% Find X, X* \neq  X, such that 
%  X* X = p
% eps is the desired tolerance 
%
%
%
% We want to use the structure of PI operator
% P = Z' Q Z, where Q is a PD matrix
% Then, P = Z' Q^{1/2} Q^{1/2} Z = X' X
%           X = Q^{1/2} Z
%
% but we do not know the exact decomposition
% Thus, we try to find Q 
% In this approach, X is not a square PI operator
% The second approach finds X > 0, X* = X
% But it allows to more accurately reconstruct P than v2

clc;clear;
rng(1); 
% load PIETOOLS2024
% path_to_PIE = 'C:\Users\cscl\Desktop\Talitckii\matlab\libs\PIETOOLS_2024\PIETOOLS';
% addpath(genpath(path_to_PIE))
% addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))

 
I = [0 1];
n1 = 2; n2 = 2;
deg=1;
pvar s1 s1_dum

eps_var = 1.e-1;
eps_X = 1.e-8;


L = rand_opvar([n1 n1;n2 n2], deg, s1, s1_dum, I);
P = L*L';
P.R.R0 = P.R.R0 + eps_var*eye(n2);
P.P = P.P + eps_var*eye(n1);



% constructing Q matrix
settings = settings_PIETOOLS_veryheavy;
settings.sos_opts.solver = 'mosek';
prog = lpiprogram(P.var1,P.var2,P.I);      % Initialize the program structure
[prog, Xop1, Qmat1, Zop1, gs1] = poslpivar(prog, P.dim, settings.dd2,  settings.options2); 
% Xop1 = Zop1'*Qmat*Zop1;
% Zop1 is the basis of operators
% find Q >= 0 such that 
% Zop1'*Qmat1*Zop1 == P
prog = lpi_eq(prog, Xop1 - P, 'symmetric');

%solving the lpi program
disp('- Solving the LPI using the specified SDP solver...');
prog = lpisolve(prog,settings.sos_opts); 

% Get solution for Qmat1
X = lpigetsol(prog,Xop1);
Q1 = double(sosgetsol(prog, Qmat1));

% compute the sqrt of Q matix
L = chol(Q1);

% Define sqrt of PI operator
sqrt_P = L*Zop1;
% sqrt_P is the size of P.dim x Zop.dim
% the size of Zop can be huge. 
% verify that the sqrt is close
tol = 1.e-6; 
if eq(sqrt_P'*sqrt_P, P, 1.e-6) 
    fprintf('||X* X - P|| < %.e\n', tol)
end


