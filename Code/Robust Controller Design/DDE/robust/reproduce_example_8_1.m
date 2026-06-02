%% reproduce_example_8_1.m
% IQC/LMI reproduction of Example 8.1 in Veenman, Scherer, Koroglu (2016).
%
% Dependencies:
%   - MATLAB Control System Toolbox
%   - YALMIP: https://yalmip.github.io/
%   - An SDP solver supported by YALMIP, e.g. MOSEK, SeDuMi, SDPT3
%
% The default run reproduces the Fig. 6 computation: rho = -1, basis (12a),
% nu = 0,1,2,3, and alpha in [0,1].

clear; clc; close all;
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b"));
yalmip('clear');

% Choose your SDP solver. Leave empty to let YALMIP choose.
solverName = 'mosek';        % examples: 'mosek', 'sedumi', 'sdpt3'

% LMI strictness surrogate. If your solver reports numerical infeasibility,
% try reducing this to 1e-9 or 0.
lmiTol = 0;

% Main Fig. 6 sweep.
nuList    = 0:3;
rho       = -1;
basisType = '12a';
alphaGrid = linspace(0,1,51);

gammaBound = nan(numel(alphaGrid),numel(nuList));
statusText = strings(numel(alphaGrid),numel(nuList));

fprintf('Running Fig. 6 sweep: basis %s, rho = %.4g\n', basisType, rho);
for j = 1:numel(nuList)
    nu = nuList(j);
    fprintf('  nu = %d\n',nu);
    for i = 1:numel(alphaGrid)
        alpha = alphaGrid(i);
        out = solve_ex81_iqc(alpha,nu,rho,basisType,solverName,lmiTol);
        gammaBound(i,j) = out.gamma;
        statusText(i,j) = out.status;
        fprintf('    alpha = %.3f: gamma = %.6g (%s)\n',alpha,out.gamma,out.status);
    end
end

figure('Name','Example 8.1 - Fig. 6 reproduction');
plot(alphaGrid,gammaBound,'LineWidth',1.5);
grid on;
xlabel('\alpha');
ylabel('\gamma');
legend(compose('\\nu = %d',nuList),'Location','NorthWest');
title('IQC upper bounds on ||\Delta \star G||_\infty');
ylim([1 10]);

% Optional: pole-location sweep for Figs. 7 and 8. This can take a long time.
doPoleSweep = false;
if doPoleSweep
    rhoGrid = -logspace(3,-3,41);    % [-1000,...,-0.001]
    alphaSweep = [0.03 0.27 0.38 0.46 0.53 0.60 0.65 0.71 0.76 0.80 0.84 0.89 0.93 0.96];
    for basisCell = {'12a','12b'}
        basisTypeSweep = basisCell{1};
        gammaRho = nan(numel(alphaSweep),numel(rhoGrid),numel(nuList));
        fprintf('\nRunning pole sweep for basis %s\n',basisTypeSweep);
        for j = 1:numel(nuList)
            nu = nuList(j);
            for a = 1:numel(alphaSweep)
                alpha = alphaSweep(a);
                for r = 1:numel(rhoGrid)
                    out = solve_ex81_iqc(alpha,nu,rhoGrid(r),basisTypeSweep,solverName,lmiTol);
                    gammaRho(a,r,j) = out.gamma;
                end
            end
        end
        figure('Name',['Example 8.1 pole sweep - basis ' basisTypeSweep]);
        tiledlayout(1,numel(nuList),'Padding','compact','TileSpacing','compact');
        for j = 1:numel(nuList)
            nexttile;
            semilogx(abs(rhoGrid),squeeze(gammaRho(:,:,j)).','LineWidth',1.0);
            set(gca,'XDir','reverse');
            grid on;
            title(sprintf('\\nu = %d',nuList(j)));
            xlabel('|\rho|');
            ylabel('\gamma');
            ylim([1 10]);
        end
        sgtitle(['Best bounds versus pole location, basis ' basisTypeSweep]);
    end
end

%% Local functions
function out = solve_ex81_iqc(alpha,nu,rho,basisType,solverName,lmiTol)
nDelta = 2;

% Basis psi_nu.
[Apsi,Bpsi,Cpsi,Dpsi] = basis_realization(nu,rho,basisType);

% Number of basis input copies.
nBasisIn = size(Dpsi,2);

% Selector: embeds the true 2-channel uncertainty signal into the first
% basis-input copy.
%
% S has size 2 x (2*nBasisIn)
% S' maps original 2-channel signal into lifted basis-input signal.
eFirst = zeros(1,nBasisIn);
eFirst(1) = 1;
S = kron(eFirst,eye(nDelta));

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
np  = size(Bp,2);      % stays 2
nq  = size(Cq,1);      % stays 2
nw  = size(Dzw,2);
nz  = size(Dzw,1);

% Realization of kron(psi,I_2).
[Apsi2,Bpsi2,Cpsi2,Dpsi2] = kron_i_realization(Apsi,Bpsi,Cpsi,Dpsi,nDelta);

nPsiState = size(Apsi2,1);
m         = size(Dpsi2,1);

% Sanity checks.
if size(Dpsi2,2) ~= size(S,2)
    error('Selector dimension mismatch: size(Dpsi2,2) must equal size(S,2).');
end

if size(S,1) ~= nq || size(S,1) ~= np
    error('Selector must map between lifted basis channels and the original 2 uncertainty channels.');
end

% Total augmented state:
%   x_G
%   x_psi_q : filter driven by S'*q
%   x_psi_p : filter driven by S'*p
nx = nxG + 2*nPsiState;

Abar = [ A,                              zeros(nxG,nPsiState),        zeros(nxG,nPsiState);
         Bpsi2*S'*Cq,                   Apsi2,                       zeros(nPsiState,nPsiState);
         zeros(nPsiState,nxG),          zeros(nPsiState,nPsiState),  Apsi2 ];

Bbar = [ Bp,                            Bw;
         Bpsi2*S'*Dqp,                  Bpsi2*S'*Dqw;
         Bpsi2*S',                      zeros(nPsiState,nw) ];

% IQC filter outputs:
%
%   v_q = alpha * Psi * S' * q
%   v_p =         Psi * S' * p
%
% where q = Cq*x + Dqp*p + Dqw*w.
Cv_q = alpha*[Dpsi2*S'*Cq,              Cpsi2,                 zeros(m,nPsiState)];
Dv_q = alpha*[Dpsi2*S'*Dqp,             Dpsi2*S'*Dqw];

Cv_p =       [zeros(m,nxG),             zeros(m,nPsiState),    Cpsi2];
Dv_p =       [Dpsi2*S',                 zeros(m,nw)];

C1 = [Cv_q; Cv_p];
D1 = [Dv_q; Dv_p];
r  = size(C1,1);

% Performance outputs z and w.
Czbar = [Cz, zeros(nz,2*nPsiState)];
Dzbar = [Dzp, Dzw];

Cwbar = zeros(nw,nx);
Dwbar = [zeros(nw,np), eye(nw)];

% Decision variables.
X     = sdpvar(nx,nx,'symmetric');
P11   = sdpvar(m,m,'symmetric');
P12   = sdpvar(m,m,'full');
gamma = sdpvar(1,1);

Miqc = [P11,  P12;
        P12', -P11];

Constraints = [];
Constraints = [Constraints, gamma >= 1e-7, gamma <= 1e3];
Constraints = [Constraints, P12 + P12' == 0];

% KYP LMI for Psi' P11 Psi >= 0.
if nPsiState == 0
    Constraints = [Constraints, P11 >= lmiTol*eye(m)];
else
    Xnu = sdpvar(nPsiState,nPsiState,'symmetric');

    nPsiInput = size(Dpsi2,2);

    Lpsi = [ eye(nPsiState),      zeros(nPsiState,nPsiInput);
             Apsi2,              Bpsi2;
             Cpsi2,              Dpsi2 ];

    Mpsi = [ zeros(nPsiState),    Xnu,                 zeros(nPsiState,m);
             Xnu,                 zeros(nPsiState),    zeros(nPsiState,m);
             zeros(m,nPsiState),  zeros(m,nPsiState),  P11 ];

    PosLMI = Lpsi'*Mpsi*Lpsi;
    Constraints = [Constraints, PosLMI >= lmiTol*eye(size(PosLMI,1))];
end

% Main robust-performance LMI. Columns are [x; p_lifted; w].
K0 = [ eye(nx),        zeros(nx,np+nw);
       Abar,           Bbar;
       C1,             D1;
       Cwbar,          Dwbar ];

M0 = [ zeros(nx),      X,              zeros(nx,r),      zeros(nx,nw);
       X,              zeros(nx),      zeros(nx,r),      zeros(nx,nw);
       zeros(r,nx),    zeros(r,nx),    Miqc,             zeros(r,nw);
       zeros(nw,nx),   zeros(nw,nx),   zeros(nw,r),      -gamma*eye(nw) ];

Phi11 = K0'*M0*K0;

Fz = [Czbar, Dzbar];

MainLMI = [Phi11, Fz';
           Fz,    -gamma*eye(nz)];

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
end

function [A,B,C,D] = basis_realization(nu,rho,basisType)
% Realization of basis functions in Eq. (12):
%   12a: psi = [1; 1/(s-rho); ...; 1/(s-rho)^nu]
%   12b: psi = [1; ((s+rho)/(s-rho)); ...; ((s+rho)/(s-rho))^nu]
% rho should be negative.

if nu == 0
    A = zeros(0,0); B = zeros(0,1); C = zeros(1,0); D = 1;
    return;
end

switch lower(basisType)
    case '12a'
        sys = F_state_space(nu,rho,1);
        A = sys.A;%rho*eye(nu) + diag(ones(nu-1,1),-1);
        B = sys.B;%[1; zeros(nu-1,1)];
        C = sys.C;%[zeros(1,nu); eye(nu)];
        D = sys.D;%[1; zeros(nu,1)];

    case '12b'
        s = tf('s');
        psi = tf(zeros(nu+1,1));
        for k = 0:nu
            psi(k+1,1) = ((s + rho)/(s - rho))^k;
        end
        psiSS = minreal(ss(psi),1e-8,false);
        [A,B,C,D] = ssdata(psiSS);
        C = ones(1, size(C,2));
        D = 1;
    case 'squaremp'
    if rho >= 0
        error('For squareMP, require rho < 0.');
    end

    % F(s) = ((s - zeroLoc)/(s - rho))^nu
    %
    % One section:
    %   F1(s) = (s - zeroLoc)/(s - rho)
    %         = 1 + (rho - zeroLoc)/(s - rho)
    %
    % Realization:
    %   xdot = rho*x + u
    %   y    = u + delta*x
    %
    % Cascading nu copies gives:
    %   A(i,i) = rho
    %   A(i,j) = delta for j < i
    %   B(i)   = 1
    %   C(j)   = delta
    %   D      = 1
    zeroLoc = -rho;
    delta = rho - zeroLoc;
    if abs(delta) < 1e-12
        % zeroLoc == rho, so F(s) = 1 exactly.
        A = zeros(0,0);
        B = zeros(0,1);
        C = zeros(1,0);
        D = 1;
    else
        A = rho*eye(nu) + diag(ones(nu-1,1),-1); %rho*eye(nu) + delta*tril(ones(nu),-1);
        B = ones(nu,1);
        B(1) = 1;
        C = delta*ones(1,nu);
        D = 1;
    end

    otherwise
        error('basisType must be ''squaremp'', ''12a'' or ''12b''.');
end
end

function [Ak,Bk,Ck,Dk] = kron_i_realization(A,B,C,D,n)
% Realization of kron(psi,I_n), preserving the output ordering
% [psi_0*u; psi_1*u; ...; psi_nu*u].

if isempty(A)
    Ak = zeros(0,0);
    Bk = zeros(0,n);
    Ck = zeros(n*size(C,1),0);
    Dk = kron(D,eye(n));
else
    Ak = kron(A,eye(n));
    Bk = kron(B,eye(n));
    Ck = kron(C,eye(n));
    Dk = kron(D,eye(n));
end
end
function sys = F_state_space(N,rho,p)
% F_state_space  State-space realization of
%
% F_ij(s) = I,                         if i = j
%        = I/(s-rho)^k,                if k = mod(i-j,N+1) ~= 0
%
% where the full transfer matrix has (N+1)-by-(N+1) blocks.
%
% Inputs:
%   N   : highest pole power
%   rho : pole location
%   p   : size of each identity block I, default p = 1
%
% Output:
%   sys : ss object with nonsingular D = eye((N+1)*p)

    if nargin < 3
        p = 1;
    end

    m  = N + 1;        % number of block rows / columns
    ny = m*p;
    nu = m*p;
    nx = m*N*p;        % one N-state chain per input block

    Ip = eye(p);

    % Chain realization producing powers 1/(s-rho), ..., 1/(s-rho)^N
    %
    % Achain = rho*I + superdiagonal ones
    % Bchain = e_N
    %
    % Then output C = e_{N-k+1}' gives 1/(s-rho)^k.
    Achain = rho*eye(N);
    if N > 1
        Achain = Achain + diag(ones(N-1,1),1);
    end

    eN = zeros(N,1);
    eN(N) = 1;

    A = kron(eye(m), kron(Achain, Ip));
    B = zeros(nx,nu);
    C = zeros(ny,nx);

    % Direct term: block identity on the diagonal.
    % Hence D is nonsingular.
    D = eye(ny);

    for j = 1:m
        % State and input indices for input block j
        xj = (j-1)*N*p + (1:N*p);
        uj = (j-1)*p   + (1:p);

        % Same chain driven by input block j
        B(xj,uj) = kron(eN,Ip);

        for i = 1:m
            k = mod(i-j,m);

            if k ~= 0
                % Output block i sees 1/(s-rho)^k from input block j
                yi = (i-1)*p + (1:p);

                er = zeros(1,N);
                er(N-k+1) = 1;

                C(yi,xj) = kron(er,Ip);
            end
        end
    end

    sys = ss(A,B,C,D);
end