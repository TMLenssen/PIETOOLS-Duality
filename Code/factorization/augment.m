function sys = augment(plant, filter)
Ap = plant.A;
Bp = plant.B;
Cp = plant.C;
Dp = plant.D;

nw = size(Bp,2);
nz = size(Cp,1);

A = filter.A;
B1 = filter.B(:,1:nz);
B2 = filter.B(:,nz+1:end);
C1 = filter.C(1:nz, :);
D11 = filter.D(1:nz,1:nz);
D12 = filter.D(1:nz, nz+1:end);
C2 = filter.C(nz+1:end, :);
D21 = filter.D(nz+1:end,1:nz);
D22 = filter.D(nz+1:end,nz+1:end);

np = size(A,1);
nx = size(Ap,1);

Aaug = [Ap, zeros(nx,np); B1*Cp, A];
Baug = [Bp;B1*Dp+B2];
Caug = [D11*Cp, C1; D21*Cp, C2];
Daug = [D11*Dp + D12; D21*Dp+D22];

sys = ss(Aaug, Baug, Caug, Daug);
end