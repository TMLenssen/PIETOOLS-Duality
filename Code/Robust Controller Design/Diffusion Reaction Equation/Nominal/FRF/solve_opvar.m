function [xfit, gam_sol, prob] = solve_opvar(A, b, settings)

%% 1. Input validation
if ~isa(A,'opvar') || ~isa(b,'opvar')
    error('A and b must be of type ''opvar''.');
end

if any(A.dim(:,1) ~= A.dim(:,2))
    error('A must be square.');
end

if nargin < 3 || isempty(settings)
    settings = struct();
end

if ~isfield(settings,'ddZ') || isempty(settings.ddZ)
    settings.ddZ = 6;   % pick your preferred default
end

%% 2. Initialize LPI program
% PIETOOLS uses lpiprogram(vars,dum_vars,dom,...) for operator programs.
prob = lpiprogram(A.var1, A.var2, A.I);

%% 3. Scalar decision variable
[prob, gam] = lpidecvar(prob, 'gam');

%% 4. Builder / decision variable for x
LPI = LPIBuilder(prob, settings);

% x should have same map dimensions as b
x = LPI.constructLPIVar(b.dim(:,1), b.dim(:,2), settings.ddZ);

%% 5. Residual
Eop = A*x - b;

%% 6. Identity operators for Schur complement
% Top-left identity acts on output space of Eop
Iz = eyePI(Eop.dim(:,1), A.vars, A.I);

% Bottom-right identity acts on input space of Eop
Iw = eyePI(Eop.dim(:,2), A.vars, A.I);

%% 7. Schur-complement constraint:
% [ gam*Iz   Eop
%   Eop'     Iw ] >= 0
%
% If your LPIBuilder.setDop(D) enforces D <= 0, pass -Big.
dimC = ioDimensions(["zr","zc"], [Eop.dim(:,1),Eop.dim(:,2)]');

Big   = gridBuilder(dimC,  dimC,  A.vars, A.I);
Big(1,1) = gam*Iz;
Big(1,2) = Eop;
Big(2,1) = Eop';
Big(2,2) = Iw;

LPI.setDop(-Big());

%% 8. Objective
prob = lpisetobj(LPI.prog, gam);

%% 9. Solve
prob = lpisolve(prob);

%% 10. Recover solution
xfit    = lpigetsol(prob, x);
gam_sol = double(lpigetsol(prob, gam));
end