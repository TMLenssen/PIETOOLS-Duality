function Example_6_worker(inputFile,outputFile)
% One analysis per MATLAB process; exit returns all solver memory to the OS.
% Load the path before deserializing PIETOOLS objects from the job file.
setup=load(inputFile,'matlabPath');
path(setup.matlabPath);
job=load(inputFile,'P','alpha','nu','rho','settings','exampleDir','side','certificateFile');
result=analyze_point(job.P,job.alpha,job.nu,job.rho,job.settings,job.exampleDir,job.side);
result.certificateFile='';
if result.feasible
    % Preserve the certificate without retaining it in the parent's sweep.
    save(job.certificateFile,'result','-v7.3');
    result.certificateFile=job.certificateFile;
    result=rmfield(result,{'storage','multiplier'});
end
save(outputFile,'result','-v7.3');
end

function result=analyze_point(P,alpha,nu,rho,settings,exampleDir,side)
fprintf('\n%s analysis: alpha=%g, nu=%d, rho=%g\n',side,alpha,nu,rho);
started=tic;
DPsi=lifted_basis(nu,rho,P.vars,P.dom);
if strcmp(side,'dual')
    GD=PIETOOLS_IQC_dual_graph(P,DPsi);
else
    GD=PIETOOLS_IQC_primal_graph(P,DPsi);
end
prog=lpiprogram(P.vars(:,1),P.vars(:,2),P.dom);
[prog,gammaSquared]=lpidecvar(prog,'gammaSquared');
prog=lpi_ineq(prog,gammaSquared);
m=2*(nu+1);
[prog,Vd]=PIETOOLS_IQC_repeated_real(prog,[1;m],[1;m],alpha,settings,P.vars,P.dom);
Vd.P=blkdiag(1,-gammaSquared);
prog=lpisetobj(prog,gammaSquared);
oldPath=path;
addpath(fullfile(exampleDir,'compat'),'-begin');
cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
[storage,prog]=PIETOOLS_IQC_analysis(prog,settings,GD,Vd);
info=prog.solinfo.info;
result=struct('alpha',alpha,'nu',nu,'rho',rho,'side',side,...
    'gamma',NaN,'info',info,'residual',prog.solinfo.residual,'seconds',toc(started));
b=vertcat(prog.expr.b{:});
result.relativeResidual=result.residual/(1+norm(b));
result.feasible=info.pinf==0 && info.dinf==0;% && info.numerr<=1 ...
    % && isfinite(info.feasratio) && abs(info.feasratio-1)<=.6;
result.rawSolverGainSquared=double(lpigetsol(prog,gammaSquared));
result.candidateGamma=sqrt(max(0,result.rawSolverGainSquared));
result.feasible=result.feasible && isfinite(result.rawSolverGainSquared) && result.rawSolverGainSquared>=0;
if result.feasible
    result.gamma=sqrt(result.rawSolverGainSquared);
    result.storage=storage;
    result.multiplier=lpigetsol(prog,Vd);
end
fprintf('gamma=%g, accepted=%d, residual=%.3g, FR=%.5g, numerr=%g, elapsed=%.1fs\n',...
    result.gamma,result.feasible,result.residual,info.feasratio,info.numerr,result.seconds);
fprintf('Candidate gamma=%g',   result.candidateGamma);
end

function F=lifted_basis(nu,rho,vars,dom)
% R0 lift of [1,(-rho)/(s-rho),...,((-rho)/(s-rho))^nu].
% Output scaling is an invertible congruence of Veenman's basis (12a).
assert(nu>=0 && nu==floor(nu) && rho<0);
n=2*nu; m=2*(nu+1);
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
F.B1=zerosPI([0;2*n],[1;2],vars,dom); F.B1.R.R0=[B;zeros(n,2)];
F.B2=zerosPI([0;2*n],[1;2],vars,dom); F.B2.R.R0=[zeros(n,2);B];
F.C1=zerosPI([1;m],[0;2*n],vars,dom); F.C1.R.R0=[C,zeros(m,n)];
F.C2=zerosPI([1;m],[0;2*n],vars,dom); F.C2.R.R0=[zeros(m,n),C];
F.D11=zerosPI([1;m],[1;2],vars,dom); F.D11.P=1; F.D11.R.R0=D;
F.D22=zerosPI([1;m],[1;2],vars,dom); F.D22.P=1; F.D22.R.R0=D;
F.D12=zerosPI([1;m],[1;2],vars,dom);
F.D21=F.D12;
end
