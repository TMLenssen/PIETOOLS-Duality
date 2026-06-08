%% reproduce_example_8_1_circular_copy.m
% IQC/LMI version of Example 8.1 using a copied plant
%
%   Ghat = I_{nu+1} \otimes G
%
% and a square circular-shift dynamic scaling
%
%   Psi = [ I      psi_nu  psi_{nu-1} ... psi_1
%           psi_1  I       psi_nu     ... psi_2
%           ...
%           psi_nu psi_{nu-1} ...     I      ].
%
% Here psi_k(s) = 1/(s-rho)^k and psi_0(s) = I.
%
% Dependencies:
%   - MATLAB Control System Toolbox
%   - YALMIP
%   - An SDP solver supported by YALMIP, e.g. MOSEK, SeDuMi, SDPT3

clear; clc; close all;
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"));
yalmip('clear');

% Choose your SDP solver. Leave empty to let YALMIP choose.
solverName = 'mosek';        % examples: 'mosek', 'sedumi', 'sdpt3'

% LMI strictness surrogate. If your solver reports numerical infeasibility,
% try reducing this to 1e-9 or 0.
lmiTol = 0;

% Sweep.
nuList    = 0:3;
rho       = -1;
alphaGrid = linspace(0,1,51);

gammaBound = nan(numel(alphaGrid),numel(nuList));
statusText = strings(numel(alphaGrid),numel(nuList));

fprintf('Running copied-plant circular-shift sweep: rho = %.4g\n', rho);
for j = 1:numel(nuList)
    nu = nuList(j);
    fprintf('  nu = %d, copies = %d\n',nu,nu+1);
    for i = 1:numel(alphaGrid)
        alpha = alphaGrid(i);
        out = solve_ex81_iqc_circular_copy(alpha,nu,rho,solverName,lmiTol);
        gammaBound(i,j) = out.gamma;
        statusText(i,j) = out.status;
        fprintf('    alpha = %.3f: gamma = %.6g (%s)\n',alpha,out.gamma,out.status);
    end
end

figure('Name','Example 8.1 - circular-shift copied plant');
plot(alphaGrid,gammaBound,'LineWidth',1.5);
grid on;
xlabel('\alpha');
ylabel('\gamma');
legend(compose('\nu = %d',nuList),'Location','NorthWest');
title('IQC upper bounds using Ghat = I_{u+1} \otimes G and circular \Psi');
ylim([1 10]);

%% Local functions
function out = solve_ex81_iqc_circular_copy(alpha,nu,rho,solverName,lmiTol)
% solve_ex81_iqc_circular_copy
%
% Uses the copied LFR
%
%   qhat = Ghat_Delta phat + Ghat_Deltaw what,
%   zhat = Ghat_zDelta phat + Ghat_zw what,
%
% where Ghat = I_{nu+1} \otimes G. The uncertainty-side filter is the
% circular-shift square scaling Psi_cs acting on qhat and phat directly.

nDelta  = 2;          % dimension of q and p for one copy
nCopies = nu + 1;     % number of copied channels

% Original LFR realization from Eq. (94), outputs [q;z], inputs [p;w].
A    = [-2 -3; 1 1];

Bp   = [1 0; 0 0];
Bw   = [1; 0];

Cq   = [1 0; 0 0];
Dqp  = [1 -2; 1 -1];
Dqw  = [0; 1];

Cz   = [1 0];
Dzp  = [0 1];
Dzw  = 0;

nxG = size(A,1);
np  = size(Bp,2);
nq  = size(Cq,1);
nw  = size(Dzw,2);
nz  = size(Dzw,1);

if nDelta ~= nq || nDelta ~= np
    error('This script assumes nq = np = nDelta.');
end

% -------------------------------------------------------------------------
% Copied plant: Ghat = I_{nu+1} \otimes G.
% State ordering: [x_0; x_1; ...; x_nu].
% Signal ordering: [p_0; p_1; ...; p_nu], similarly for q,z,w.
% -------------------------------------------------------------------------
Ic = eye(nCopies);

Ahat   = kron(Ic,A);
Bphat  = kron(Ic,Bp);
Bwhat  = kron(Ic,Bw);

Cqhat  = kron(Ic,Cq);
Dqphat = kron(Ic,Dqp);
Dqwhat = kron(Ic,Dqw);

Czhat  = kron(Ic,Cz);
Dzphat = kron(Ic,Dzp);
Dzwhat = kron(Ic,Dzw);

nxGhat = nCopies*nxG;
npHat  = nCopies*np;
nqHat  = nCopies*nq;
nwHat  = nCopies*nw;
nzHat  = nCopies*nz;

% -------------------------------------------------------------------------
% Circular-shift square scaling Psi_cs.
%
% Block (i,j), using zero-based indices, is psi_{mod(i-j,nCopies)}.
% Thus the first block row is [I psi_nu psi_{nu-1} ... psi_1].
% Each block is nDelta x nDelta.
% -------------------------------------------------------------------------
[Apsi,Bpsi,Cpsi,Dpsi] = circular_shift_realization(nu,rho,nDelta);

nPsiState = size(Apsi,1);
mFilt     = size(Dpsi,1);

if size(Dpsi,2) ~= nqHat || size(Dpsi,1) ~= nqHat
    error('Circular Psi dimensions must match copied q/p dimensions.');
end

% Total augmented state:
%   x_Ghat
%   x_psi_q : filter driven by qhat
%   x_psi_p : filter driven by phat
nx = nxGhat + 2*nPsiState;

Abar = [ Ahat,                    zeros(nxGhat,nPsiState),       zeros(nxGhat,nPsiState);
         Bpsi*Cqhat,              Apsi,                          zeros(nPsiState,nPsiState);
         zeros(nPsiState,nxGhat), zeros(nPsiState,nPsiState),     Apsi ];

% Columns are [phat; what].
Bbar = [ Bphat,                   Bwhat;
         Bpsi*Dqphat,             Bpsi*Dqwhat;
         Bpsi,                    zeros(nPsiState,nwHat) ];

% IQC filter outputs:
%
%   v_q = alpha * Psi_cs * qhat
%   v_p =         Psi_cs * phat
%
% where qhat = Cqhat*xhat + Dqphat*phat + Dqwhat*what.
Cv_q = alpha*[Dpsi*Cqhat,              Cpsi,                    zeros(mFilt,nPsiState)];
Dv_q = alpha*[Dpsi*Dqphat,             Dpsi*Dqwhat];

Cv_p =       [zeros(mFilt,nxGhat),     zeros(mFilt,nPsiState),  Cpsi];
Dv_p =       [Dpsi,                    zeros(mFilt,nwHat)];

C1 = [Cv_q; Cv_p];
D1 = [Dv_q; Dv_p];
r  = size(C1,1);

% Performance outputs zhat and what for the copied plant.
Czbar = [Czhat, zeros(nzHat,2*nPsiState)];
Dzbar = [Dzphat, Dzwhat];

Cwbar = zeros(nwHat,nx);
Dwbar = [zeros(nwHat,npHat), eye(nwHat)];

% Decision variables.
X     = sdpvar(nx,nx,'symmetric');
P11   = sdpvar(mFilt,mFilt,'symmetric');
P12   = sdpvar(mFilt,mFilt,'full');
gamma = sdpvar(1,1);

% Static multiplier in the filtered coordinates.
Miqc = [P11,  P12;
        P12', -P11];

Constraints = [];
Constraints = [Constraints, gamma >= 1e-7, gamma <= 1e3];
Constraints = [Constraints, P12 + P12' == 0];

% KYP LMI for Psi_cs' P11 Psi_cs >= 0.
if nPsiState == 0
    Constraints = [Constraints, P11 >= lmiTol*eye(mFilt)];
else
    Xnu = sdpvar(nPsiState,nPsiState,'symmetric');

    nPsiInput = size(Dpsi,2);

    Lpsi = [ eye(nPsiState),      zeros(nPsiState,nPsiInput);
             Apsi,                Bpsi;
             Cpsi,                Dpsi ];

    Mpsi = [ zeros(nPsiState),    Xnu,                    zeros(nPsiState,mFilt);
             Xnu,                 zeros(nPsiState),       zeros(nPsiState,mFilt);
             zeros(mFilt,nPsiState), zeros(mFilt,nPsiState), P11 ];

    PosLMI = Lpsi'*Mpsi*Lpsi;
    Constraints = [Constraints, PosLMI >= lmiTol*eye(size(PosLMI,1))];
end

% Main robust-performance LMI. Columns are [x; phat; what].
K0 = [ eye(nx),        zeros(nx,npHat+nwHat);
       Abar,           Bbar;
       C1,             D1;
       Cwbar,          Dwbar ];

M0 = [ zeros(nx),      X,              zeros(nx,r),          zeros(nx,nwHat);
       X,              zeros(nx),      zeros(nx,r),          zeros(nx,nwHat);
       zeros(r,nx),    zeros(r,nx),    Miqc,                 zeros(r,nwHat);
       zeros(nwHat,nx), zeros(nwHat,nx), zeros(nwHat,r),     -gamma*eye(nwHat) ];

Phi11 = K0'*M0*K0;

Fz = [Czbar, Dzbar];

MainLMI = [Phi11, Fz';
           Fz,    -gamma*eye(nzHat)];

Constraints = [Constraints, MainLMI <= -lmiTol*eye(size(MainLMI,1))];

if isempty(solverName)
    opts = sdpsettings('verbose',0);
else
    opts = sdpsettings('solver',solverName,'verbose',0);
end

diagnostics = optimize(Constraints,gamma,opts);

out.problem = diagnostics.problem;
out.info = diagnostics.info;

if diagnostics.problem == 0 || diagnostics.problem == 3 || diagnostics.problem == 4
    out.gamma = value(gamma);
else
    out.gamma = NaN;
end

out.status = yalmiperror(diagnostics.problem);
out.nCopies = nCopies;
out.nx = nx;
out.nPsiState = nPsiState;
end

function [A,B,C,D] = circular_shift_realization(N,rho,p)
% circular_shift_realization  State-space realization of Psi_cs.
%
% Psi_cs has (N+1)-by-(N+1) blocks of size p-by-p. With zero-based
% indexing, block (i,j) is
%
%   Psi_ij(s) = I_p,                      if i = j,
%             = I_p/(s-rho)^k,            if k = mod(i-j,N+1) ~= 0.
%
% Hence the first block row is
%
%   [I, 1/(s-rho)^N I, ..., 1/(s-rho) I].

    if nargin < 3
        p = 1;
    end

    nBlocks = N + 1;
    ny = nBlocks*p;
    nu = nBlocks*p;

    if N == 0
        A = zeros(0,0);
        B = zeros(0,p);
        C = zeros(p,0);
        D = eye(p);
        return;
    end

    nx = nBlocks*N*p;  % one N-state chain per input block
    Ip = eye(p);

    % Chain realization producing powers 1/(s-rho), ..., 1/(s-rho)^N.
    Achain = rho*eye(N);
    if N > 1
        Achain = Achain + diag(ones(N-1,1),1);
    end

    eN = zeros(N,1);
    eN(N) = 1;

    A = kron(eye(nBlocks), kron(Achain, Ip));
    B = zeros(nx,nu);
    C = zeros(ny,nx);
    D = eye(ny);       % direct diagonal I blocks

    for j = 1:nBlocks
        xj = (j-1)*N*p + (1:N*p);
        uj = (j-1)*p   + (1:p);

        B(xj,uj) = kron(eN,Ip);

        for i = 1:nBlocks
            k = mod(i-j,nBlocks);

            if k ~= 0
                yi = (i-1)*p + (1:p);

                er = zeros(1,N);
                er(N-k+1) = 1;

                C(yi,xj) = kron(er,Ip);
            end
        end
    end
end
