function R = pendulum_multiplier_analysis(K,A0,BDelta,Bdist,Bu,Cv,beta,opts)
% PENDULUM_MULTIPLIER_ANALYSIS
% Fixed-K IQC analysis for the upright pendulum
%
%   xdot = (A0+Bu*K)x + BDelta*w + Bdist*d
%   v    = Cv*x = theta
%   w    = Delta(v) = v - sin(v)
%   e    = K*x       (control torque)
%
% Delta(v)=v-sin(v) is globally:
%   sector bounded in [0,beta], beta ~= 1.217233628...
%   static
%   monotone (Delta'(v)=1-cos(v)>=0)
%   odd
%
% This function compares:
%   1) sector
%   2) sector + modified Popov
%   3) sector + modified Popov + Zames-Falb
%
% The dynamic IQCs are handled using the same loop transformation as
% Pfifer-Seiler:
%       q = (s+1)v
% so that v = (1/(s+1))q.
%
% REQUIREMENTS
%   YALMIP, MOSEK
%   Control System Toolbox
%   Robust Control Toolbox (stabsep)
%
% Example:
%   opts = sdpsettings('solver','mosek','verbose',0);
%   R = pendulum_multiplier_analysis(K,A0,Bd,Bw,Bu,Cd,beta,opts)

if nargin < 8 || isempty(opts)
    opts = sdpsettings('solver','mosek','verbose',0);
end

cfg.popovEps = 1e-2;
cfg.zfEps    = 1e-2;
cfg.zfPole   = 0.1;
cfg.zfL1     = 0.90;  % strictly < 1
cfg.lmiTol   = 1e-8;
cfg.pTol     = 1e-8;

Acl = A0 + Bu*K;
Ce  = K;                      % performance output e=u
nx  = size(Acl,1);

% q=(s+1)v = vdot+v.
% For the pendulum Cv=[1 0], this is simply q=theta+theta_dot.
Cq  = Cv*(Acl + eye(nx));
Dqw = Cv*BDelta;
Dqd = Cv*Bdist;

fprintf('\nTransformed uncertainty input q=(s+1)v:\n');
fprintf('Cq = [%s]\n', num2str(Cq,' %.8g'));
fprintf('Dqw = %.4g, Dqd = %.4g\n',Dqw,Dqd);

names = ["sector"; "sector + Popov"; "sector + Popov + Zames-Falb"];
gamma = nan(3,1);
rho   = nan(3,1);
lambda = cell(3,1);

for mode = 1:3
    iqcs = make_iqcs(beta,mode,cfg);
    [rho(mode),lambda{mode},diagnostics] = solve_fixedK( ...
        Acl,BDelta,Bdist,Ce,Cq,Dqw,Dqd,iqcs,cfg,opts);

    if diagnostics.problem == 0 && rho(mode) >= 0
        gamma(mode) = sqrt(rho(mode));
    else
        warning('%s analysis failed: %s',names(mode),diagnostics.info);
    end
end

R = table(names,gamma,rho,'VariableNames',{'MultiplierSet','gamma','rho'});
disp(R);

fprintf('\nIQC multipliers (lambda):\n');
for k=1:3
    fprintf('%s:\n',names(k));
    disp(lambda{k}.');
end

end

% ========================================================================
function [rhoOpt,lamOpt,diagnostics] = solve_fixedK( ...
    Acl,Bw,Bd,Ce,Cq,Dqw,Dqd,iqcs,cfg,opts)

% Build the extended system consisting of the pendulum plus all IQC filters.
S = build_extended(Acl,Bw,Bd,Ce,Cq,Dqw,Dqd,iqcs);
nx = size(S.A,1);
ni = numel(iqcs);

P   = sdpvar(nx,nx,'symmetric');
rho = sdpvar(1,1);
lam = sdpvar(ni,1);

% Differential dissipation inequality:
%
%   Vdot + e'e - rho*d'd + sum_k lam_k z_k' M_k z_k < 0
%
% Inputs are ordered [w; d], where w=Delta(v).
L = [S.A'*P + P*S.A,  P*S.Bw, P*S.Bd; ...
    S.Bw'*P,          0,       0; ...
    S.Bd'*P,          0,      -rho];

E = [S.Ce, 0, 0];
L = L + E'*E;

for k = 1:ni
    Zk = [S.Cz{k}, S.Dzw{k}, S.Dzd{k}];
    L = L + lam(k)*(Zk'*iqcs{k}.M*Zk);
end

F = [P >= cfg.pTol*eye(nx), ...
    rho >= 0, ...
    lam >= 0, ...
    L <= -cfg.lmiTol*eye(nx+2)];

diagnostics = optimize(F,rho,opts);

if diagnostics.problem == 0
    rhoOpt = value(rho);
    lamOpt = value(lam);
else
    rhoOpt = NaN;
    lamOpt = NaN(ni,1);
end
end

% ========================================================================
function S = build_extended(A,Bw,Bd,Ce,Cq,Dqw,Dqd,iqcs)
% Each IQC filter has input [q; w], where q=(s+1)v.

nG = size(A,1);
ni = numel(iqcs);
nk = zeros(ni,1);
for k=1:ni
    nk(k) = size(iqcs{k}.A,1);
end
nx = nG + sum(nk);

Ae  = zeros(nx,nx);
Bwe = zeros(nx,1);
Bde = zeros(nx,1);

Ae(1:nG,1:nG) = A;
Bwe(1:nG) = Bw;
Bde(1:nG) = Bd;

ofs = nG;
for k=1:ni
    Q = iqcs{k};
    I = ofs + (1:nk(k));

    if nk(k)>0
        Ae(I,1:nG) = Q.Bq*Cq;
        Ae(I,I)    = Q.A;
        Bwe(I)     = Q.Bq*Dqw + Q.Bw;
        Bde(I)     = Q.Bq*Dqd;
    end
    ofs = ofs + nk(k);
end

Cee = [Ce zeros(size(Ce,1),nx-nG)];

Cz  = cell(ni,1);
Dzw = cell(ni,1);
Dzd = cell(ni,1);

ofs = nG;
for k=1:ni
    Q = iqcs{k};
    I = ofs + (1:nk(k));

    Czk = zeros(size(Q.C,1),nx);
    Czk(:,1:nG) = Q.Dq*Cq;
    if nk(k)>0
        Czk(:,I) = Q.C;
    end

    Cz{k}  = Czk;
    Dzw{k} = Q.Dq*Dqw + Q.Dw;
    Dzd{k} = Q.Dq*Dqd;

    ofs = ofs + nk(k);
end

S.A=Ae; S.Bw=Bwe; S.Bd=Bde; S.Ce=Cee;
S.Cz=Cz; S.Dzw=Dzw; S.Dzd=Dzd;
end

% ========================================================================
function iqcs = make_iqcs(beta,mode,cfg)

s  = tf('s');
F  = 1/(s+1);
Ft = 1/(1-s);               % para-Hermitian conjugate F~(s)=F(-s)

iqcs = {};

% ------------------------------------------------------------------------
% 1) Sector [0,beta]
%
% Delta(v)(beta*v-Delta(v)) >= 0
%
% After q=(s+1)v, use Psi=diag(F,1):
%   z=[v;w], M=[0 beta; beta -2].
PsiS = minreal(ss([F 0; 0 1]),1e-9);
MS   = [0 beta; beta -2];
iqcs{end+1} = iqc_from_ss(PsiS,MS,'sector');

if mode >= 2
    % --------------------------------------------------------------------
    % 2) Modified Popov IQC.
    %
    % For a static memoryless Delta the Popov term is valid.  We add a
    % small norm-bound IQC to make the multiplier suitable for a stable
    % J-spectral factorization:
    %
    %   [ eps*beta^2   -s
    %       s          -eps ]
    %
    % and then apply diag(F,1)~ (.) diag(F,1).
    %
    % Both Popov signs are valid for a static nonlinearity, so include
    % both as separate IQCs.  This avoids choosing a sign a priori.
    ep = cfg.popovEps;

    for sig = [1 -1]
        PiP = [ep*beta^2*Ft*F,  sig*(-Ft*s); ...
            sig*(s*F),      -ep];

        [PsiP,JP] = jspectral_factor(PiP);
        iqcs{end+1} = iqc_from_ss(PsiP,JP, ...
            sprintf('Popov sign %+d',sig));
    end
end

if mode >= 3
    % --------------------------------------------------------------------
    % 3) Zames-Falb IQC.
    %
    % Delta(v)=v-sin(v) is monotone and odd.
    %
    % Use H(s)=k*a/(s+a), for which ||h||_1=k<1.  The paper's displayed
    % H=1/(s+0.1) would have ||h||_1=10, so here the numerator is chosen
    % to satisfy the actual Zames-Falb condition.
    %
    % The paper's normalized sector is [0,1].  For [0,beta], scale the
    % off-diagonal terms by beta:
    %
    % [ 0,                  beta(1+H)
    %   beta(1+H~),  -2-(H+H~)           ].
    %
    % A small norm-bound term eps*[beta^2 0;0 -1] is added before the
    % loop transformation for J-spectral factorization.
    a = cfg.zfPole;
    k = cfg.zfL1;

    H  = k*a/(s+a);
    Ht = k*a/(a-s);
    ez = cfg.zfEps;

    % Loop-transformed Zames-Falb multiplier
    PiZ0 = [0,                      beta*Ft*(1+H); ...
        beta*(1+Ht)*F,          -2-(H+Ht)];

    % IMPORTANT:
    % Add norm-bound perturbation AFTER loop transformation
    PiZ = PiZ0 + ez*[beta^2 0; ...
        0     -1];

    [PsiZ,JZ] = jspectral_factor(PiZ);
    iqcs{end+1} = iqc_from_ss(PsiZ,JZ,'Zames-Falb');
end
end

% ========================================================================
function iqc = iqc_from_ss(Psi,M,name)
Psi = minreal(ss(Psi),1e-9);
[A,B,C,D] = ssdata(Psi);

iqc.A  = A;
iqc.Bq = B(:,1);
iqc.Bw = B(:,2);
iqc.C  = C;
iqc.Dq = D(:,1);
iqc.Dw = D(:,2);
iqc.M  = (M+M')/2;
iqc.name = name;
end

% ========================================================================
function [Psi,J] = jspectral_factor(Pi)
% J-spectral factorization following the numerical procedure in the
% Pfifer-Seiler appendix:
%
%   Pi = Psi~ J Psi
%   Psi, Psi^{-1} stable.
%
% Requires stabsep and care.

Pi = minreal(ss(Pi),1e-8);
[~,~,~,Dpi0] = ssdata(Pi);

% Stable part of the para-Hermitian multiplier.
[Pis,~] = stabsep(Pi);
Pis = minreal(Pis,1e-8);
[A,B,C,Dpi] = ssdata(Pis);

% Preserve the original direct term if numerical decomposition perturbs it.
if norm(Dpi-Dpi0,'fro') > 1e-6*(1+norm(Dpi0,'fro'))
    Dpi = Dpi0;
end
Dpi = (Dpi+Dpi')/2;

if rcond(Dpi) < 1e-12
    error('J-spectral factorization failed: D_pi is singular/ill-conditioned.');
end

n = size(A,1);

% ARE:
% A'X + XA - (XB+C') Dpi^{-1} (B'X+C) = 0.
if n==0
    X = zeros(0);
else
    [X,~,~] = care(A,B,zeros(n),Dpi,C');
    X = (X+X')/2;
end

% Dpi = W' J W.
[U,d] = eig(Dpi,'vector');
ip = find(d > 1e-9);
in = find(d < -1e-9);

if numel(ip)+numel(in) ~= numel(d)
    error('J-spectral factorization failed: D_pi has a near-zero eigenvalue.');
end

idx = [ip(:); in(:)];
d   = d(idx);
U   = U(:,idx);

J = diag([ones(numel(ip),1); -ones(numel(in),1)]);
W = diag(sqrt(abs(d)))*U';

if n==0
    Cpsi = zeros(size(W,1),0);
else
    Cpsi = J*(W'\(B'*X+C));
end

Psi = minreal(ss(A,B,Cpsi,W),1e-8);

% Sanity checks.
if n>0
    AclFac = A - B*(Dpi\(B'*X+C));
    if max(real(eig(AclFac))) >= -1e-7
        warning('J-factor ARE solution is only weakly stabilizing.');
    end
end

if ~isempty(pole(Psi)) && max(real(pole(Psi))) >= -1e-7
    warning('Computed Psi is not strongly stable.');
end
end
