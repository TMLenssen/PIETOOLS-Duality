function Example_6_run_jobs(P,settings,exampleDir,numWorkers,nextJob,acceptResult)
% Bounded, disposable MATLAB processes; callbacks keep results on disk.
% nextJob returns one job struct or [] when the queue is exhausted.
% Run synchronized batches: refill no slot until every worker in the current
% batch has exited and its result has been checkpointed.
validateattributes(numWorkers,{'numeric'},{'scalar','integer','positive','finite'});
assert(ispc,'Example6:Platform','The concurrent process runner requires Windows.');
active=containers.Map('KeyType','double','ValueType','any');
for slot=1:numWorkers, active(slot)=[]; end
exhausted=false;
cleanup=onCleanup(@()stop_workers(active)); %#ok<NASGU>
batch=0;
while ~exhausted
    batch=batch+1;
    batchSlots=zeros(1,0);
    for slot=1:numWorkers
        job=nextJob();
        if isempty(job)
            exhausted=true;
            break
        end
        worker=struct('job',job,'directory',tempname,'process',[], 'started',false);
        mkdir(worker.directory);
        active(slot)=worker;
        try
            inputFile=fullfile(worker.directory,'input.mat');
            outputFile=fullfile(worker.directory,'output.mat');
            alpha=job.alpha; nu=job.nu; rho=job.rho; side=job.side;
            certificateFile=job.certificateFile;
            matlabPath=path;
            save(inputFile,'P','settings','exampleDir','alpha','nu','rho', ...
                'side','certificateFile','matlabPath','-v7.3');
            quote=@(s)strrep(s,'''','''''');
            expression=sprintf('addpath(''%s'');Example_6_worker(''%s'',''%s'');', ...
                quote(exampleDir),quote(inputFile),quote(outputFile));
            process=System.Diagnostics.Process;
            process.StartInfo.FileName=fullfile(matlabroot,'bin','matlab.exe');
            process.StartInfo.Arguments=sprintf('-wait -batch "%s" -logfile "%s"', ...
                expression,fullfile(worker.directory,'worker.log'));
            process.StartInfo.UseShellExecute=false;
            process.StartInfo.CreateNoWindow=true;
            worker.process=process;
            active(slot)=worker;
            assert(process.Start(),'Example6:LaunchFailed','Could not start MATLAB.');
            worker.started=true;
            active(slot)=worker;
            batchSlots(end+1)=slot; %#ok<AGROW>
            fprintf('Worker %d started: %s alpha=%g, nu=%d, rho=%g\n', ...
                slot,side,alpha,nu,rho);
        catch err
            release_worker(active,slot);
            acceptResult(job,failure(getReport(err,'extended','hyperlinks','off')));
        end
    end

    if isempty(batchSlots), continue; end
    fprintf('Batch %d launched with %d worker(s); waiting for all to finish.\n', ...
        batch,numel(batchSlots));
    batchFinished=false;
    while ~batchFinished
        batchFinished=true;
        for slot=batchSlots
            if ~active(slot).process.HasExited
                batchFinished=false;
                break
            end
        end
        if ~batchFinished, pause(.25); end
    end

    fprintf('Batch %d finished; collecting results.\n',batch);
    for slot=batchSlots
        worker=active(slot);
        outputFile=fullfile(worker.directory,'output.mat');
        try
            if worker.process.ExitCode~=0 || ~isfile(outputFile)
                error('Example6:WorkerFailed','MATLAB worker exited with status %d.', ...
                    worker.process.ExitCode);
            end
            data=load(outputFile,'result');
            trial=data.result;
            clear data
        catch err
            trial=failure(getReport(err,'extended','hyperlinks','off'));
            logFile=fullfile(worker.directory,'worker.log');
            if isfile(logFile)
                trial.logFile=[worker.job.certificateFile '.log'];
                copyfile(logFile,trial.logFile);
            end
        end
        job=worker.job;
        release_worker(active,slot);
        clear worker
        % Only the coordinator writes diagnostics and shared checkpoints.
        fprintf('Worker %d finished: %s alpha=%g, nu=%d, rho=%g, gamma=%g\n', ...
            slot,job.side,job.alpha,job.nu,job.rho,trial.gamma);
        acceptResult(job,trial);
        clear trial job
    end
    fprintf('Batch %d checkpointed; starting the next batch.\n',batch);
end

end

function release_worker(active,slot)
        worker=active(slot);
        if isempty(worker), return; end
        if ~isempty(worker.process)
            if worker.started && ~worker.process.HasExited
                % Kill only the process tree launched for this worker.
                fprintf('Stopping worker process tree PID %d.\n',worker.process.Id);
                killer=System.Diagnostics.Process;
                killer.StartInfo.FileName=fullfile(getenv('SystemRoot'),'System32','taskkill.exe');
                killer.StartInfo.Arguments=sprintf('/PID %d /T /F',worker.process.Id);
                killer.StartInfo.UseShellExecute=false;
                killer.StartInfo.CreateNoWindow=true;
                killer.Start();
                stopped=killer.WaitForExit(10000);
                if ~stopped || killer.ExitCode~=0
                    killer.Dispose();
                    error('Example6:StopFailed','Could not stop worker PID %d.',worker.process.Id);
                end
                killer.Dispose();
                assert(worker.process.WaitForExit(10000),'Example6:StopFailed', ...
                    'Worker did not exit after termination.');
            end
            worker.process.Dispose();
        end
        if isfolder(worker.directory), rmdir(worker.directory,'s'); end
        active(slot)=[];
    end

function stop_workers(active)
        slots=cell2mat(keys(active));
        for n=slots
            try
                release_worker(active,n);
            catch err
                warning('Example6:CleanupFailed','%s',err.message);
            end
        end
    end

function trial=failure(message)
trial=struct('feasible',false,'gamma',NaN,'error',message);
end
