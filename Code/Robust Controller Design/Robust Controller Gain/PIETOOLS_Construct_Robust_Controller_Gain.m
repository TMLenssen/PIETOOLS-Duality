%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS_Construct_Robust_Controller_Gain.m     uPIETOOLS 2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [prog, Z, P] = PIETOOLS_Construct_Robust_Controller_Gain(prog, uPIE, V, gam, settings, coercive, alpha, rho, r)

%% 1. Input Validation
if ~isa(uPIE,'upie'), error('uPIE must be of type ''upie''.'); end

if isempty(V) || isempty(gam)
    error('V and gam must be provided.');
end

if nargin < 8 || isempty(rho)
    rho = -1;
end
if nargin < 9 || isempty(r)
    r = 0;
end
if ~isscalar(r) || r < 0 || r ~= floor(r)
    error('r must be a nonnegative integer basis degree.');
end

vars = uPIE.vars;
dom  = uPIE.dom;

Eye  = @(n) eyePI(n, vars, dom);
Zero = @(r,c) zerosPI(r, c, vars, dom);
epsilon = 1e-9;

LPI = LPIBuilder(prog, settings);
if coercive
    if ~isfield(settings, 'eppos2')
        error('settings.eppos2 must be provided when coercive=true.');
    end
    eppos2 = settings.eppos2;
else
    eppos2 = 0;
end

if r == 0
    [prog, Z, P] = constructStaticLPI(LPI, uPIE, V, gam, eppos2, coercive, alpha, Eye, Zero, epsilon);
else
    [prog, Z, P] = constructDynamicBasisLPI(LPI, uPIE, V, gam, eppos2, coercive, alpha, rho, r, Eye, Zero, epsilon);
end
end

function [prog, Z, P] = constructStaticLPI(LPI, uPIE, V, gam, eppos2, coercive, alpha, Eye, Zero, epsilon)
nx = uPIE.nx; nwd = uPIE.nwd; nw = uPIE.nw; nzd = uPIE.nzd; nz = uPIE.nz;
nu = uPIE.nu;

stateDim   = ioDimensions("x", nx');
inputDim   = ioDimensions(["wd", "w"], [nwd'; nw']);
outputDim  = ioDimensions(["vd", "z"], [nzd'; nz']);
controlDim = ioDimensions("u", nu');
fullDim    = ioDimensions(["xbar", "wbar", "vbar"], [nx'; (nzd+nz)'; (nwd+nw)']);

V11Bar = gridBuilder(inputDim,  inputDim,  uPIE.vars, uPIE.dom);
perf   = gridBuilder(inputDim,  inputDim,  uPIE.vars, uPIE.dom);
V12Bar = gridBuilder(inputDim,  outputDim, uPIE.vars, uPIE.dom);
V21Bar = gridBuilder(outputDim, inputDim,  uPIE.vars, uPIE.dom);
V22Bar = gridBuilder(outputDim, outputDim, uPIE.vars, uPIE.dom);

T      = gridBuilder(stateDim,   stateDim,   uPIE.vars, uPIE.dom);
A      = gridBuilder(stateDim,   stateDim,   uPIE.vars, uPIE.dom);
Atilde = gridBuilder(stateDim,   controlDim, uPIE.vars, uPIE.dom);
B      = gridBuilder(stateDim,   inputDim,   uPIE.vars, uPIE.dom);
C      = gridBuilder(outputDim,  stateDim,   uPIE.vars, uPIE.dom);
Ctilde = gridBuilder(outputDim,  controlDim, uPIE.vars, uPIE.dom);
D      = gridBuilder(outputDim,  inputDim,   uPIE.vars, uPIE.dom);
Dop    = gridBuilder(fullDim, fullDim, uPIE.vars, uPIE.dom);

if coercive
    T(1,1) = uPIE.T;
else
    T(1,1) = Eye(nx);
end

A(1,1)      = uPIE.A;
Atilde(1,1) = uPIE.Bu;

B(1,1) = uPIE.Bd;
B(1,2) = uPIE.Bw;

C(1,1)      = uPIE.Cd;
C(2,1)      = uPIE.Cz;
Ctilde(1,1) = uPIE.Ddu;
Ctilde(2,1) = uPIE.Dzu;

D(1,1) = uPIE.Dd;
D(1,2) = uPIE.Ddw;
D(2,1) = uPIE.Dzd;
D(2,2) = uPIE.Dzw;

V11Bar(1,1) = V.V11;
V11Bar(2,2) = Eye(nw);

V12Bar(1,1) = V.V12;
V12Bar(2,2) = Zero(nw,nz);

V21Bar(1,1) = V.V21;
V21Bar(2,2) = Zero(nz,nw);

V22Bar(1,1) = V.V22;
V22Bar(2,2) = -gam*Eye(nz);

perf(1,1) = V.V11;
perf(2,2) = gam*Eye(nw);

[P, R] = LPI.constructLyapOp(T(), coercive);
if coercive
    P = P + eppos2*Eye(nx);
    R = T()'*R*T();
end
Q = P*T()';

Z = LPI.constructLPIVar(nu, nx);
Z = Z*T()';

T11 = A()*Q + Atilde()*Z;
T12 = C()*Q + Ctilde()*Z;

Dop(1,1) = T11 + T11' + alpha*R;
Dop(1,2) = T12' + B()*V12Bar();
Dop(1,3) = B()*V11Bar()';
Dop(2,1) = T12 + V21Bar()*B()';
Dop(2,2) = V21Bar()*D()' + D()*V12Bar() + V22Bar() + epsilon*Eye(nzd+nz);
Dop(2,3) = D()*V11Bar()';
Dop(3,1) = V11Bar()*B()';
Dop(3,2) = V11Bar()*D()';
Dop(3,3) = -perf();

LPI.setDop(Dop());
prog = LPI.prog;
end

function [prog, Z, P] = constructDynamicBasisLPI(LPI, uPIE, V, gam, eppos2, coercive, alpha, rho, r, Eye, Zero, epsilon)
nx = uPIE.nx; nwd = uPIE.nwd; nw = uPIE.nw; nzd = uPIE.nzd; nz = uPIE.nz;
nu = uPIE.nu;

[Tpsiz, Apsiz, Bpsiz, Cpsiz, Dpsiz, ~] = Basis_12A(rho, r, nzd, uPIE.vars, uPIE.dom);
[Tpsiw, Apsiw, Bpsiw, ~, Dpsiw, Nw] = Basis_12A(rho, r, nwd, uPIE.vars, uPIE.dom);

nxpsiz = Tpsiz.dim(:,1);
nxpsiw = Tpsiw.dim(:,1);
nv1    = Dpsiz.dim(:,1);
nv2    = Dpsiw.dim(:,1);
nxhat  = nx + nxpsiz + nxpsiw;

stateDim   = ioDimensions(["x", "psiz", "psiw"], [nx'; nxpsiz'; nxpsiw']);
inputDim   = ioDimensions(["v2", "w"], [nv2'; nw']);
outputDim  = ioDimensions(["v1", "z"], [nv1'; nz']);
controlDim = ioDimensions("u", nu');
fullDim    = ioDimensions(["xbar", "wbar", "vbar"], [nxhat'; (nv1+nz)'; (nv2+nw)']);

V11Bar = gridBuilder(inputDim,  inputDim,  uPIE.vars, uPIE.dom);
perf   = gridBuilder(inputDim,  inputDim,  uPIE.vars, uPIE.dom);
V12Bar = gridBuilder(inputDim,  outputDim, uPIE.vars, uPIE.dom);
V21Bar = gridBuilder(outputDim, inputDim,  uPIE.vars, uPIE.dom);
V22Bar = gridBuilder(outputDim, outputDim, uPIE.vars, uPIE.dom);

T      = gridBuilder(stateDim,   stateDim,   uPIE.vars, uPIE.dom);
A      = gridBuilder(stateDim,   stateDim,   uPIE.vars, uPIE.dom);
Atilde = gridBuilder(stateDim,   controlDim, uPIE.vars, uPIE.dom);
B      = gridBuilder(stateDim,   inputDim,   uPIE.vars, uPIE.dom);
C      = gridBuilder(outputDim,  stateDim,   uPIE.vars, uPIE.dom);
Ctilde = gridBuilder(outputDim,  controlDim, uPIE.vars, uPIE.dom);
D      = gridBuilder(outputDim,  inputDim,   uPIE.vars, uPIE.dom);
Dop    = gridBuilder(fullDim, fullDim, uPIE.vars, uPIE.dom);

if coercive
    T(1,1) = uPIE.T;
    T(2,2) = Tpsiz;
    T(3,3) = Tpsiw;
else
    T(1,1) = Eye(nx);
    T(2,2) = Eye(nxpsiz);
    T(3,3) = Eye(nxpsiw);
end


A(1,1) = uPIE.A;
A(2,1) = Bpsiz*uPIE.Cd;
A(2,2) = Apsiz;
A(3,3) = Apsiw;

Atilde(1,1) = uPIE.Bu;
Atilde(2,1) = Bpsiz*uPIE.Ddu;

B(1,1) = uPIE.Bd*Nw;
B(1,2) = uPIE.Bw;
B(2,1) = Bpsiz*uPIE.Dd*Nw;
B(2,2) = Bpsiz*uPIE.Ddw;
B(3,1) = Bpsiw*Nw;

C(1,1) = Dpsiz*uPIE.Cd;
C(1,2) = Cpsiz;
C(2,1) = uPIE.Cz;

Ctilde(1,1) = Dpsiz*uPIE.Ddu;
Ctilde(2,1) = uPIE.Dzu;

D(1,1) = Dpsiz*uPIE.Dd*Nw;
D(1,2) = Dpsiz*uPIE.Ddw;
D(2,1) = uPIE.Dzd*Nw;
D(2,2) = uPIE.Dzw;

V11Bar(1,1) = V.V11;
V11Bar(2,2) = Eye(nw);

V12Bar(1,1) = V.V12;
V12Bar(2,2) = Zero(nw,nz);

V21Bar(1,1) = V.V21;
V21Bar(2,2) = Zero(nz,nw);

V22Bar(1,1) = V.V22;
V22Bar(2,2) = -gam*Eye(nz);

perf(1,1) = V.V11;
perf(2,2) = gam*Eye(nw);

[P, R] = LPI.constructLyapOp(T(), coercive);
if coercive
    P = P + eppos2*Eye(nxhat);
    R = T()'*R*T();
end
Q = P*T()';

Z = LPI.constructLPIVar(nu, nxhat);
Z = Z*T()';

T11 = A()*Q + Atilde()*Z;
T12 = C()*Q + Ctilde()*Z;

Dop(1,1) = T11 + T11' + alpha*R;
Dop(1,2) = T12' + B()*V12Bar();
Dop(1,3) = B()*V11Bar()';
Dop(2,1) = T12 + V21Bar()*B()';
Dop(2,2) = V21Bar()*D()' + D()*V12Bar() + V22Bar() + epsilon*Eye(nv1+nz);
Dop(2,3) = D()*V11Bar()';
Dop(3,1) = V11Bar()*B()';
Dop(3,2) = V11Bar()*D()';
Dop(3,3) = -perf();

LPI.setDop(Dop());
prog = LPI.prog;
end



