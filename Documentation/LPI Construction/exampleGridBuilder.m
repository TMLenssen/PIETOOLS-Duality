clear; clc; close all; clear stateNameGenerator
echo on

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"))
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
pvar s t;
echo off;

a = 0;
b = 1;

x1 = pde_var('state',1); x2 = pde_var('state',1); x3 = pde_var(1,s,[a,b]); x4 = pde_var(1,s,[a,b]);
zd1 = pde_var('output', 1, s, [a,b]); wd1 = pde_var('input', 1, s, [a,b]);
w = pde_var('input',1);
z1 = pde_var('output',1); z2 = pde_var('output',1);
y1 = pde_var('sense',1); y2 = pde_var('sense',1);
tau = 0.5;%

PDE = [diff(x1,t) == x2;
    diff(x2,t) == -2*x1 + 0.1*x2 + subs(x3,s,b) + 0.1*w;
    diff(x3,t) == -tau^-1*diff(x3,s,1) + wd1;
    zd1 == diff(x3,s,1);
    z1 == int(x3,s,[a,b]);
    subs(x3,s,a) == x1];

PIE = convert(PDE, 'pie');
data = struct();

data.misc = PIE.misc;
data.dim  = PIE.dim;
data.dom  = PIE.dom;
data.vars = PIE.vars;
data.T    = PIE.T;
data.A    = PIE.A;
data.Bw   = PIE.B1(:,1);
data.Bd   = PIE.B1(:,2);
data.Cd   = PIE.C1(2,:);
data.Dd   = PIE.D11(2,2);
data.Ddw  = PIE.D11(2,1);
data.Cz   = PIE.C1(1,:);
data.Dzd  = PIE.D11(1,2);
data.Dzw  = PIE.D11(1,1);

% Convert to upie
uPIE = upie(data);

nx  = uPIE.nx;
nwd = uPIE.nwd;
nw  = uPIE.nw;

% Common constructor args for gridBuilder (new signature)
vars = uPIE.vars;
dom  = uPIE.dom;

% -------------------------------- %
% Test 2: Multiplication w/ permute
% -------------------------------- %
I     = ioDimensions(["x","wd","w"],  [nx'; nwd'; nw']);
O     = ioDimensions(["x","wd","w"],  [nx'; nwd'; nw']);
Operm = ioDimensions(["wd","x","w"],  [nwd'; nx'; nw']);

Eye = @(n) eyePI(n, vars, dom);
Zero = @(r,c) zerosPI(r, c, vars, dom);

Ix  = Eye(nx);
Iwd = Eye(nwd);
Iw  = Eye(nw);

% B: output order [x, wd, w]
B = gridBuilder(O, I, vars, dom);
B(1,1) = uPIE.A;
B(1,2) = uPIE.Bd;
B(1,3) = uPIE.Bw;
B(2,2) = Iwd;
B(3,3) = Iw;

Bman = [uPIE.A, uPIE.Bd, uPIE.Bw;
        Zero(nwd,nx), Iwd, Zero(nwd, nw);
        Zero(nw,nx+nwd), Iw];
% Bperm: output order [wd, x, w]
Bperm = gridBuilder(Operm, I, vars, dom);
Bperm(1,2) = Iwd;
Bperm(2,1) = uPIE.A;
Bperm(2,2) = uPIE.Bd;
Bperm(2,3) = uPIE.Bw;
Bperm(3,3) = Iw;

% Permute outputs back to [x, wd, w]
P = gridBuilder(O, Operm, vars, dom);
P(1,2) = Ix;      % x  <- x
P(2,1) = Iwd;     % wd <- wd
P(3,3) = Iw;      % w  <- w

prodB = P() * Bperm();

% prodB == B()

% Optional: range indexing now returns assembled sub-grid opvar
% subG = B(1:2, 1:2);

inputIndexRange = indexRange2D(nx+nwd+1, nx+nwd+nw);
outputIndexRange  = indexRange2D([1,1], nx);


Q = gridBuilder(prodB, O, I);
% 
% for i = 1:3
%     for j = 1:3
%         Q(i,j) == B(i,j)
%     end
% end

% Q() == B()
B() == Bman
% blkdiag(Iwd, Iw) == B(2:3, 2:3)


