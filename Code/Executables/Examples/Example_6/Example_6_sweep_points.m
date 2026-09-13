function Results=Example_6_sweep_points(P,settings,exampleDir,certificateDir,Results,numWorkers,checkpointFile)
% Schedule unfinished points without retaining a grid of jobs or diagnostics.
cursor=0;
gridSize=size(Results.gamma);
for k=1:numel(Results.nu)
    if Results.nu(k)~=0, continue; end
    for i=1:numel(Results.alpha)
        if Results.completed(i,1,k)
            Results.gamma(i,:,k)=Results.gamma(i,1,k);
            Results.completed(i,:,k)=true;
        end
    end
end
Example_6_save_checkpoint(checkpointFile,'Results',Results);
Example_6_run_jobs(P,settings,exampleDir,numWorkers,@next_job,@accept_result);

    function job=next_job
        job=[];
        while cursor<numel(Results.gamma)
            cursor=cursor+1;
            [i,j,k]=ind2sub(gridSize,cursor);
            if Results.completed(i,j,k) || (Results.nu(k)==0 && j>1), continue; end
            job=struct('i',i,'j',j,'k',k,'alpha',Results.alpha(i), ...
                'rho',Results.rho(j),'nu',Results.nu(k),'side',Results.side, ...
                'certificateFile',fullfile(certificateDir, ...
                    sprintf('%s_a%d_r%d_n%d.mat',Results.side,i,j,k)));
            return
        end
    end

    function accept_result(job,trial)
        i=job.i; j=job.j; k=job.k;
        diagnosticFile=fullfile(Results.diagnosticsDirectory, ...
            sprintf('a%d_r%d_n%d.mat',i,j,k));
        Example_6_save_checkpoint(diagnosticFile,'trial',trial);
        Results.gamma(i,j,k)=trial.gamma;
        Results.completed(i,j,k)=~isfield(trial,'error');
        if job.nu==0
            Results.gamma(i,:,k)=Results.gamma(i,1,k);
            Results.completed(i,:,k)=Results.completed(i,1,k);
        end
        if isfield(trial,'error'), fprintf('%s\n',trial.error); end
        Example_6_save_checkpoint(checkpointFile,'Results',Results);
        fprintf('Checkpoint saved: %s (%d/%d complete), gamma=%g\n', ...
            Results.side,nnz(Results.completed),numel(Results.completed),trial.gamma);
    end
end
