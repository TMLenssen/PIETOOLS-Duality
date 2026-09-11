function [prog,V,Q,S]=PIETOOLS_IQC_repeated_real(prog,dp,dn,alpha,set,vars,dom)
% Full repeated-real hard IQC, following the sector/slope function interface.
% Apply to [Psi*z_Delta; Psi*w_Delta], w_Delta=delta*z_Delta,
% where the SAME CONSTANT REAL scalar satisfies |delta|<=alpha everywhere.
% Psi must commute with delta*I and have zero initial state.
% Vdist=[alpha^2*Q,alpha*S;-alpha*S,-Q], Q>=0, S'=-S.
% This is alpha^2 times (6) of the supplied mu-framework manuscript,
% with gamma_V=1/alpha. It also holds on the dual side.
% Finite channels get diag(I,-I); replace the latter block by -gamma^2*I
% when minimizing a gain. No cross terms with finite performance channels.
% set.pointwise=true restricts Q,S to constant R0 matrices (default).
% set.pointwise=false permits full spatial PI operators of degree set.ddM.
% This does NOT assume independent parameters in the individual channels.
if ~isscalar(alpha) || ~isfinite(alpha) || alpha<0
    error('alpha must be a finite nonnegative scalar.');
end
if dp(2)~=dn(2) || dp(2)<1
    error('The two distributed blocks must have the same positive size.');
end
m=dp(2); pointwise=true;
if isfield(set,'pointwise'), pointwise=set.pointwise; end
if pointwise
    opt=struct('exclude',[1,0,1,1],'sep',0,'psatz',0);
    [prog,Q]=poslpivar(prog,[0;m],0,opt);
    [prog,H]=lpidecvar(prog,[m,m]);
    S=opvar2dopvar(zerosPI([0;m],[0;m],vars,dom));
    S.R.R0=H-H';
else
    [prog,Q]=poslpivar(prog,[0;m],set.ddM,set.options1);
    [prog,H]=lpivar(prog,[0,0;m,m],set.ddM);
    S=H-H';
end
R=[alpha^2*Q,alpha*S;-alpha*S,-Q];
V=opvar2dopvar(zerosPI(dp+dn,dp+dn,vars,dom));
V.P=blkdiag(eye(dp(1)),-eye(dn(1)));
V.R=R.R;
end
