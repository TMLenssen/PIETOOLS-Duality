function [Tpsi, Apsi, Bpsi, Cpsi, Dpsi] = Basis_12A(rho, r, dim, vars, dom)
if numel(dim) == 1
    dim = [dim; 0];
end
if dim(2) ~= 0
    error('Dynamic multiplier basis currently supports finite-dimensional uncertainty channels only.');
end

m = dim(1);
if m == 0
    error('Dynamic multiplier basis requires a nonzero channel dimension.');
end

stateDim = [r*m; 0];
inputDim = [m; 0];
outDim   = [(r+1)*m; 0];

A = rho*eye(r);
A(2:end,1:end-1) = A(2:end,1:end-1) + eye(r-1);
B = zeros(r,1);
B(1) = 1;
C = [zeros(1,r); eye(r)];
D = zeros(r+1,1);
D(1) = 1;

Tpsi = eyePI(stateDim, vars, dom);
Apsi = mat2opvar(kron(eye(m),A), [stateDim, stateDim], vars, dom);
Bpsi = mat2opvar(kron(eye(m),B), [stateDim, inputDim], vars, dom);
Cpsi = mat2opvar(kron(eye(m),C), [outDim, stateDim], vars, dom);
Dpsi = mat2opvar(kron(eye(m),D), [outDim, inputDim], vars, dom);
end