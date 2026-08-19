function sys = augment_controller(plant, filter, Bu, Dzu, K)
%AUGMENT_CONTROLLER Construct Psi*[K star P; I].
%
% Plant:
%   xp_dot = Ap*xp + Bp*w + Bu*u
%   z      = Cp*xp + Dp*w + Dzu*u
%
% Controller:
%   u = Kp*xp + Kpsi*xpsi
%
% Filter:
%   xpsi_dot     = A*xpsi + B1*z + B2*w
%   [ztilde;
%    wtilde]     = filter.C*xpsi + filter.D*[z; w]
%
% K must be ordered as
%   K = [Kp, Kpsi].
%
% The returned system maps
%   w -> [ztilde; wtilde]
% with state
%   [xp; xpsi].

Ap = plant.A;
Bp = plant.B;
Cp = plant.C;
Dp = plant.D;

A = filter.A;
B = filter.B;
C = filter.C;
D = filter.D;

nx   = size(Ap,1);
npsi = size(A,1);
nw   = size(Bp,2);
nz   = size(Cp,1);

assert(size(K,2) == nx+npsi, ...
    'K must act on the augmented state [xp; xpsi].');
assert(size(Bu,2) == size(K,1), ...
    'Bu and K have incompatible control dimensions.');
assert(size(Dzu,1) == nz && size(Dzu,2) == size(K,1), ...
    'Dzu has incompatible dimensions.');
assert(size(B,2) == nz+nw, ...
    'filter.B must have inputs ordered as [z; w].');
assert(size(C,1) == nz+nw, ...
    'filter.C must have outputs ordered as [ztilde; wtilde].');
assert(isequal(size(D),[nz+nw,nz+nw]), ...
    'filter.D must map [z; w] to [ztilde; wtilde].');

% Controller partition
Kp   = K(:,1:nx);
Kpsi = K(:,nx+1:end);

% Filter partitions
B1 = B(:,1:nz);
B2 = B(:,nz+1:end);

C1 = C(1:nz,:);
C2 = C(nz+1:end,:);

D11 = D(1:nz,1:nz);
D12 = D(1:nz,nz+1:end);
D21 = D(nz+1:end,1:nz);
D22 = D(nz+1:end,nz+1:end);

% Controller-closed plant operators
Ak = Ap + Bu*Kp;
Bk = Bu*Kpsi;
Ck = Cp + Dzu*Kp;
Dk = Dzu*Kpsi;

% Augmented realization of Psi*[K star P; I]
Aaug = [Ak,       Bk;
        B1*Ck,    A + B1*Dk];

Baug = [Bp;
        B1*Dp + B2];

Caug = [D11*Ck,   C1 + D11*Dk;
        D21*Ck,   C2 + D21*Dk];

Daug = [D11*Dp + D12;
        D21*Dp + D22];

sys = ss(Aaug,Baug,Caug,Daug);
end