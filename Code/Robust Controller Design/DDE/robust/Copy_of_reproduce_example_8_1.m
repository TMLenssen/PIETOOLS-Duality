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

yalmip('clear');

% Choose your SDP solver. Leave empty to let YALMIP choose.
solverName = '';        % examples: 'mosek', 'sedumi', 'sdpt3'

% LMI strictness surrogate. If your solver reports numerical infeasibility,
% try reducing this to 1e-9 or 0.
lmiTol = 1e-8;

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
% Solves the IQC LMI for Example 8.1 at one alpha, nu, and rho.
%
% Uncertainty: Delta = delta*I_2, delta real, |delta| <= alpha.
% Multiplier: Class 5, with the simplifying skew constraint P12 = -P12'.

    if nargin < 6 || isempty(lmiTol)
        lmiTol = 1e-8;
    end

    % Dimensions.
    % LFR realization from Eq. (94), outputs [q;z], inputs [p;w].
    A   = [-2 -3; 1 1];
    Bp  = [1; 0];
    Bw  = [1; 0];
    Cq  = [1 0];
    Dqp = 0;%[1 -2; 1 -1];
    Dqw = 0;%[0; 1];
    Cz  = [1 0];
    Dzp = 0;%[0 1];
    Dzw = 0;

    nq = size(Dqp,1);
    np = size(Dqp,2);
    nw = size(Dzw,2);
    nz = size(Dzw,1);
    % Basis psi_nu and psi_nu kron I_2.
    [Apsi,Bpsi,Cpsi,Dpsi] = basis_realization(nu,rho,basisType)
    [Apsi2,Bpsi2,Cpsi2,Dpsi2] = kron_i_realization(Apsi,Bpsi,Cpsi,Dpsi,nq);
    N = Dpsi2';
    nPsiState = size(Apsi2,1);       % equals 2*nu for the minimal 12a basis
    m = nq*(nu+1);                   % output dimension of psi_nu kron I_2

    % Build a realization of
    %   T = diag(Psi,I_{z+w}) * [G_qp G_qw; I 0; G_zp G_zw; 0 I]
    % mapping [p;w] to [v;z;w], with v = Psi*[q;p].
    nxG = size(A,1);
    nx  = nxG + 2*nPsiState;

    Abar = [ A,                         zeros(nxG,nPsiState);
             Bpsi2*Cq,                  Apsi2];             

    Bbar = [ Bp*N,             Bw;
             Bpsi2*Dqp*N,      Bpsi2*Dqw];

    % IQC filter outputs: v = [alpha*(psi kron I2)*q; (psi kron I2)*p].
    Cv_q = alpha*[Dpsi2*Cq,             Cpsi2];
    Dv_q = alpha*[Dpsi2*Dqp*N,            Dpsi2*Dqw];
    Cv_p =       [zeros(m,nxG),         zeros(m,nPsiState)];
    Dv_p =       [Dpsi2,                zeros(m,nw)];

    C1 = [Cv_q; Cv_p];
    D1 = [Dv_q; Dv_p];
    r  = size(C1,1);                   % equals 2*m

    % Performance outputs split as z and w.
    Czbar = [Cz, zeros(nz,2*nPsiState)];
    Dzbar = [Dzp, Dzw];
    Cwbar = zeros(nw,nx);
    Dwbar = [zeros(nw,np), eye(nw)];

    % Decision variables.
    X     = sdpvar(nx,nx,'symmetric');
    P11   = sdpvar(m,m,'symmetric');
    P12   = sdpvar(m,m,'full');
    gamma = sdpvar(1,1);

    P = [P11, P12;
         P12', -P11];

    Constraints = [];
    Constraints = [Constraints, gamma >= 1e-7, gamma <= 1e3];
    Constraints = [Constraints, P12 + P12' == 0];       % sufficient form of Eq. (40)

    % KYP LMI for (psi kron I2)' P11 (psi kron I2) >= 0.
    if nPsiState == 0
        Constraints = [Constraints, P11 >= lmiTol*eye(m)];
    else
        Xnu = sdpvar(nPsiState,nPsiState,'symmetric');
        Lpsi = [ eye(nPsiState),      zeros(nPsiState,nq);
                 Apsi2,              Bpsi2;
                 Cpsi2,              Dpsi2 ];
        Mpsi = [ zeros(nPsiState),    Xnu,                 zeros(nPsiState,m);
                 Xnu,                 zeros(nPsiState),    zeros(nPsiState,m);
                 zeros(m,nPsiState),  zeros(m,nPsiState),  P11 ];
        PosLMI = Lpsi'*Mpsi*Lpsi;
        Constraints = [Constraints, PosLMI >= lmiTol*eye(size(PosLMI,1))];
    end

    % Main robust-performance LMI, Eq. (18). Columns are [x; p; w].
    K0 = [ eye(nx),        zeros(nx,np+nw);
           Abar,           Bbar;
           C1,             D1;
           Cwbar,          Dwbar ];

    M0 = [ zeros(nx),      X,              zeros(nx,r),      zeros(nx,nw);
           X,              zeros(nx),      zeros(nx,r),      zeros(nx,nw);
           zeros(r,nx),    zeros(r,nx),    P,                zeros(r,nw);
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
        % 3/4 can occur with some solvers as near-feasible/numerical states;
        % value(gamma) is still useful for debugging but should be checked.
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
            A = rho*eye(nu) + diag(ones(nu-1,1),-1);
            B = [1; zeros(nu-1,1)];
            C = [zeros(1,nu); eye(nu)];
            D = [1; zeros(nu,1)];

        case '12b'
            s = tf('s');
            psi = tf(zeros(nu+1,1));
            for k = 0:nu
                psi(k+1,1) = ((s + rho)/(s - rho))^k;
            end
            psiSS = minreal(ss(psi),1e-8,false);
            [A,B,C,D] = ssdata(psiSS);

        otherwise
            error('basisType must be ''12a'' or ''12b''.');
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
