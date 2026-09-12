function result=Example_6_run_point(P,alpha,nu,rho,settings,exampleDir,side,certificateFile)
% Run one unchanged Example 6 analysis in a disposable MATLAB process.
% Only compact diagnostics cross the process boundary. Full certificates
% are saved separately; no Parallel Computing Toolbox is required.
jobDir=tempname;
mkdir(jobDir);
cleanup=onCleanup(@()remove_job(jobDir)); %#ok<NASGU>
inputFile=fullfile(jobDir,'input.mat');
outputFile=fullfile(jobDir,'output.mat');
matlabPath=path;
save(inputFile,'P','alpha','nu','rho','settings','exampleDir','side', ...
    'certificateFile','matlabPath','-v7.3');
expression=sprintf('addpath(''%s'');Example_6_worker(''%s'',''%s'');', ...
    quote_matlab(exampleDir),quote_matlab(inputFile),quote_matlab(outputFile));
if ispc
    executable=fullfile(matlabroot,'bin','matlab.exe');
    command=sprintf('"%s" -wait -batch "%s"',executable,expression);
else
    executable=fullfile(matlabroot,'bin','matlab');
    command=sprintf('"%s" -batch "%s"',executable,expression);
end
fprintf('\nStarting isolated %s analysis: alpha=%g, nu=%d, rho=%g\n',side,alpha,nu,rho);
[status,output]=system(command);
if status~=0 || ~isfile(outputFile)
    % Keep the failure report bounded, even if MATLAB emitted a large log.
    output=output(max(1,numel(output)-7999):end);
    error('Example6:WorkerFailed','MATLAB worker failed (exit %d):\n%s',status,output);
end
data=load(outputFile,'result');
result=data.result;
fprintf('gamma=%g, accepted=%d, elapsed=%.1fs; worker exited\n', ...
    result.gamma,result.feasible,result.seconds);
end

function value=quote_matlab(value)
value=strrep(value,'''','''''');
end

function remove_job(jobDir)
% Only remove the uniquely created job directory, never certificate files.
if isfolder(jobDir), rmdir(jobDir,'s'); end
end
