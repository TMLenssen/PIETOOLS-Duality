function [PsiPrimal,PsiDual] = j_spectral_factorization(Pi,nPositive,nNegative)
%J_SPECTRAL_FACTORIZATION Stable primal and dual factors of a strict-PN IQC.
%   [PSIPRIMAL,PSIDUAL] = J_SPECTRAL_FACTORIZATION(PI,NZ,NW) returns
%   factors with signatures J(NZ,NW) and J(NW,NZ), respectively. The
%   numerical strict-PN, stability, inverse-stability, and factorization
%   checks are implemented by jfactor.

narginchk(3,3);
[PsiPrimal,PsiDual] = jfactor(Pi,nPositive,nNegative);
end
