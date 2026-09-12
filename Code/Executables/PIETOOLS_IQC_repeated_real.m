function [prog,V,Q,S]=PIETOOLS_IQC_repeated_real(prog,dp,dn,alpha,set,vars,dom)
if ~isscalar(alpha) || ~isfinite(alpha) || alpha<0
    error('alpha must be a finite nonnegative scalar.');
end
if dp(2)~=dn(2) || dp(2)<1
    error('The two distributed blocks must have the same positive size.');
end
m=dp(2);
[prog,Q]=poslpivar(prog,[0;m],set.ddM,set.options1);
[prog,H]=lpivar(prog,[0,0;m,m],set.ddM);
S=H-H';
R=[alpha^2*Q,alpha*S;-alpha*S,-Q];
V=opvar2dopvar(zerosPI(dp+dn,dp+dn,vars,dom));
V.P=blkdiag(eye(dp(1)),-eye(dn(1)));
V.R=R.R;
end
