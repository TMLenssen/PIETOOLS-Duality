%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS_Construct_Nominal_Controller_Gain.m     PIETOOLS 2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [prog, Z, P] = PIETOOLS_Construct_Nominal_Controller_Gain(prog, PIE, settings, coercive, gam, alpha)

%% 1. Input Validation
if ~isa(PIE,'pie_struct'), error('PIE must be of type ''pie_struct''.'); end

nx = PIE.A.dim(:,1); nw = PIE.B1.dim(:,2); nz = PIE.C1.dim(:,1); ny = PIE.C2.dim(:,1); nu = PIE.B2.dim(:,2);

fullDim = ioDimensions(["xbar","wbar","vbar"], [nx, nz, nw]');
stateDim    = ioDimensions(["x"], [nx']);
inputDim    = ioDimensions(["w"], [nz']);
outputDim   = ioDimensions(["v"], [nw']);
controlDim = ioDimensions(["u"], [nu']);

Eye  = @(n) eyePI(n, PIE.vars, PIE.dom);
Zero = @(r,c) zerosPI(r, c, PIE.vars, PIE.dom);

LPI = LPIBuilder(prog, settings);

% Grid builders, creates a matrix of opvar objects
T  = gridBuilder(stateDim,    stateDim,    PIE.vars, PIE.dom);
A  = gridBuilder(stateDim,    stateDim,    PIE.vars, PIE.dom);
Atilde = gridBuilder(controlDim, stateDim,    PIE.vars, PIE.dom);

B  = gridBuilder(stateDim,    inputDim,    PIE.vars, PIE.dom);
Btilde = gridBuilder(controlDim, inputDim,    PIE.vars, PIE.dom);

C  = gridBuilder(outputDim,   stateDim,    PIE.vars, PIE.dom);
D  = gridBuilder(outputDim,   inputDim,    PIE.vars, PIE.dom);

Dop = gridBuilder(fullDim, fullDim, PIE.vars, PIE.dom);

% -----------------------------
% Populate block operators
% -----------------------------
% mappingOp = [T, 0; 0 T];
if coercive
    T(1,1) = PIE.T';
else
    T(1,1) = Eye(nx);
end

% A = [A, 0; 0, A];
A(1,1) = PIE.A';

% Atilde = [0, 0; -Cy, Cy];
Atilde(1,1) = PIE.B2';

% B = [Bw; 0];
B(1,1) = PIE.C1';

% Btilde = [0; -Dyw];
Btilde(1,1) = PIE.D12';

% C = [Cz, -Cz];
C(1,1) =  PIE.B1';

% D = [Dzw];
D(1,1) = PIE.D11';

% -----------------------------
% Assemble opvars using new D()
% -----------------------------
[P, R] = LPI.constructLyapOp(T(), coercive);

if coercive
    P = P + settings.eppos2*Eye(nx);
    R = T()'*R*T();
end
Q = P * T();

Z = LPI.constructLPIVar(nu, nx);
Z = Z * T();

% T11 = A'Q + \tilde{A}'Z
% T12 = B'Q + \tilde{B}'Z

T11 = (A())' * Q + (Atilde())' * Z;  
T12 = (B())' * Q + (Btilde())' * Z;   

% -----------------------------
% Dop assembly using indexing + D()
% -----------------------------
Dop(1,1) = (T11 + T11' + alpha*R);
Dop(1,2) = (T12');
Dop(1,3) = ((C())'); 
Dop(2,1) = (T12);
Dop(2,2) = - gam*Eye(nz);
Dop(2,3) = D()';
Dop(3,1) = (C());
Dop(3,2) = D();
Dop(3,3) = - gam*Eye(nw);

LPI.setDop(Dop());
prog = LPI.prog;
end
