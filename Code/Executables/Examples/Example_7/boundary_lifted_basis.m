function F=boundary_lifted_basis(nu,rho,d1,d2,vars,dom)
% Two repeated spatial channels; independent finite performance dimensions.
assert(nu>=0 && nu==floor(nu) && rho<0 && d1(2)==2 && d2(2)==2);
n=2*nu; m=2*(nu+1); o1=[d1(1);m]; o2=[d2(1);m];
if nu==0
    A=zeros(0); B=zeros(0,2); C=zeros(2,0); D=eye(2);
else
    A=kron(rho*eye(nu)-rho*diag(ones(nu-1,1),-1),eye(2));
    B=kron(-rho*[1;zeros(nu-1,1)],eye(2));
    C=kron([zeros(1,nu);eye(nu)],eye(2));
    D=kron([1;zeros(nu,1)],eye(2));
end
F.vars=vars; F.dom=dom;
F.T=eyePI([0;2*n],vars,dom);
F.A=mat2opvar(blkdiag(A,A),[0;2*n],vars,dom);
F.B1=zerosPI([0;2*n],d1,vars,dom); F.B1.R.R0=[B;zeros(n,2)];
F.B2=zerosPI([0;2*n],d2,vars,dom); F.B2.R.R0=[zeros(n,2);B];
F.C1=zerosPI(o1,[0;2*n],vars,dom); F.C1.R.R0=[C,zeros(m,n)];
F.C2=zerosPI(o2,[0;2*n],vars,dom); F.C2.R.R0=[zeros(m,n),C];
F.D11=zerosPI(o1,d1,vars,dom); F.D11.P=eye(d1(1)); F.D11.R.R0=D;
F.D22=zerosPI(o2,d2,vars,dom); F.D22.P=eye(d2(1)); F.D22.R.R0=D;
F.D12=zerosPI(o1,d2,vars,dom);
F.D21=zerosPI(o2,d1,vars,dom);
end

