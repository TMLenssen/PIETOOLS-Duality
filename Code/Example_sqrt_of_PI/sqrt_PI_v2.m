%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This code computes the P^{1/2}, where 
%                                 P > 0 -- PD PI operator 
% 
% Find X > 0, X* = X, such that 
% P - eps I < X* X < P + eps I
% eps is the desired tolerance 
% less accurate than v1, but X is square, symmetric and PD



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

eps = 1.e-2; % the desired tolerance in the optimization problem
eps_X = 1.e-8; % the PD of X:   X > eps_X I

% construct random PD PI operator
L = rand_opvar([n1 n1;n2 n2], deg, s1, s1_dum, I);
P = L*L';
P.R.R0 = P.R.R0 + eps*eye(n2);
P.P = P.P + eps*eye(n1);

%% LMI for sqrt(P), P > 0
% Find X > 0 such that 
% P -eps I < XX <  P + eps I 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1st part. Using Schur Complement we have
% [I X
%  X (P+eps I)] > 0  <==> P+eps I  - XX >0 <==> XX < P + epsI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2nd part. We assume P > eps I. Then, we have
% [(P-eps I)X    (P-eps I)
%  (P-eps I)             X]  > 0  <==> (P-eps I) X - (P-eps I) X^{-1} (P-eps I) > 0 
% <==> X - X^{-1} (P-epsI) >0 <==> XX > P - eps I 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

settings = settings_PIETOOLS_veryheavy;
settings.sos_opts.solver = 'mosek';
prog = lpiprogram(P.var1,P.var2,P.I);      % Initialize the program structure

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[prog, Xop1] = poslpivar(prog, P.dim, settings.dd2,  settings.options2); 
[prog, Xop2] = poslpivar(prog, P.dim, settings.dd3,  settings.options3); 
Xop = Xop1 + Xop2 ; % Xop is an approximated P^{1/2}


Iop = Identity_oper(P.dim, P.I);

% -Dop1 > 0 <=> XX < P + eps I
Q1 = P + eps;
Dop1 = -[Iop, Xop; 
        Xop', Q1 ];

% -Dop2 > 0 <==> XX > P - eps I
Q2 = P - eps;
Dop2 = -[Q2*Xop, Q2; 
        Q2', Xop];


% Define equality constraints
[prog, De1op1] = poslpivar(prog, Dop1.dim, settings.dd2, settings.options2);
[prog, De1op2] = poslpivar(prog, Dop2.dim, settings.dd2, settings.options2);
[prog, De2op1] = poslpivar(prog, Dop1.dim, settings.dd3, settings.options3);
[prog, De2op2] = poslpivar(prog, Dop2.dim, settings.dd3, settings.options3);
Deop1 = De1op1 + De2op1;
Deop2 = De1op2 + De2op2;

% Dop1 <= 0, Dop2 <= 0
prog = lpi_eq(prog, Deop1 + Dop1, 'symmetric'); %Dop1= Deop1
prog = lpi_eq(prog, Deop2 + Dop2, 'symmetric'); %Dop2= Deop2



%solving the lpi program
disp('- Solving the LPI using the specified SDP solver...');
prog = lpisolve(prog,settings.sos_opts); 


X = lpigetsol(prog,Xop);


% verifying that X*X = P
diff = X*X-P;
% Q1, Q2, R0, R1 are non-zero functions, but 
% they values are small for s, theta \in [0, 1]
% the following code verifies the largest values of Q1, R0, R1, R2
t_points = 0:0.01:1;
Q1 = diff.Q1;R0 = diff.R.R0;
err_Q = 0;err_R0 = 0;
for i = 1:n2    
    eval_Q = double(subs(Q1(i, :), diff.var1, t_points));
    eval_R0 = double(subs(R0(i, :), diff.var1, t_points));
    err_Q = max(err_Q, max(abs(eval_Q), [], 'all'));
    err_R0 = max(err_R0, max(abs(eval_R0), [], 'all'));

end

R1 = diff.R.R1;
R2 = diff.R.R2;
err_R1 = 0;
err_R2 = 0;
for i = 1:2
    for j = 1:2
        eval_R1 = (subs(R1(i, j), diff.var1, t_points));
        eval_R1 = double(subs(eval_R1, diff.var2, t_points));
        eval_R2 = (subs(R2(i, j), diff.var1, t_points));
        eval_R2 = double(subs(eval_R2, diff.var2, t_points));
        err_R1 = max(err_R1, max(abs(eval_R1), [], 'all'));
        err_R2 = max(err_R2, max(abs(eval_R2), [], 'all'));
    end
end

err_P = max(abs(double(diff.P)), [], 'all');
fprintf('Error in P, Q1, R0, R1, R2= %.2e %.2e %.2e %.2e %.2e \n', err_P, err_Q, err_R0, err_R1, err_R2)

function [op] = Identity_oper(dim, X)
if nargin == 1
    X = [0, 1];
end
% dim should be [nx1, nx1; nx2, nx2]
opvar op;
op.I = X;
op.dim = dim;
if dim(1, 1) ~= 0
    op.P = eye(dim(1,1));
end
if dim(2, 2) ~= 0
    op.R.R0 = eye(dim(2,2));
end
end
