function result=synthesize_boundary_gain(P,alpha,nu,rho,settings)
% Dual-IQC boundary-feedback synthesis at fixed alpha and filter order.
totalTimer=tic;
here=fileparts(mfilename('fullpath')); previousPath=path;
addpath(fullfile(here,'compat'),'-begin');
pathCleanup=onCleanup(@()path(previousPath));
assemblyTimer=tic;
F=boundary_lifted_basis(nu,rho,P.B1.dim(:,2),P.C1.dim(:,1),P.vars,P.dom);
prog=lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,g2]=lpidecvar(prog,'gammaSquaredSynthesis');
prog=lpi_ineq(prog,g2); prog=lpisetobj(prog,g2);
[prog,V]=PIETOOLS_IQC_repeated_real(prog,F.C1.dim(:,1),F.C2.dim(:,1),...
    alpha,settings,P.vars,P.dom);
V.P=blkdiag(eye(P.B1.dim(1,2)),-g2*eye(P.C1.dim(1,1)));
assemblySeconds=toc(assemblyTimer);
fprintf('\nBoundary synthesis: alpha=%g, nu=%d, rho=%g, veryheavy\n',alpha,nu,rho);
synthesisTimer=tic;
[K,Z,storage,prog]=PIETOOLS_IQC_controller_synthesis(prog,settings,P,F,V);
synthesisSeconds=toc(synthesisTimer);
info=prog.solinfo.info; b=vertcat(prog.expr.b{:});
result=struct('feasible',false,'gamma',NaN,'info',info,...
    'residual',prog.solinfo.residual,'relativeResidual',prog.solinfo.residual/(1+norm(b)));
result.rawSolverGainSquared=double(lpigetsol(prog,g2));
result.feasible=info.pinf==0 && info.dinf==0 && info.numerr<=1 ...
    && isfinite(info.feasratio) && abs(info.feasratio-1)<=.3 ...
    && isfinite(result.residual) && isfinite(result.rawSolverGainSquared) ...
    && result.rawSolverGainSquared>=0;
if result.feasible, result.gamma=sqrt(result.rawSolverGainSquared); end
result.K=K; result.Z=Z; result.storage=storage; result.dualFilter=F;
result.alpha=alpha; result.nu=nu; result.rho=rho; result.side='dual';
result.assemblySeconds=assemblySeconds;
result.synthesisSeconds=synthesisSeconds;
result.solverSeconds=NaN;
if isfield(info,'cpusec'), result.solverSeconds=info.cpusec; end
result.totalSeconds=toc(totalTimer);
result.controllerRecovered=~isempty(K);
fprintf('gamma=%g, accepted=%d, residual=%.3g, FR=%.5g, numerr=%g, elapsed=%.1fs\n',...
    result.gamma,result.feasible,result.residual,info.feasratio,info.numerr,result.totalSeconds);
end

