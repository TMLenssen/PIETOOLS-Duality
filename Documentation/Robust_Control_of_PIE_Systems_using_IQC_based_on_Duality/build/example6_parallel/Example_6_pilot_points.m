function Pilot=Example_6_pilot_points(P,settings,exampleDir,certificateDir,sides,alpha,nu,rho,numWorkers)
cursor=0;
Pilot=struct;
Example_6_run_jobs(P,settings,exampleDir,numWorkers,@next_job,@accept_result);

    function job=next_job
        cursor=cursor+1;
        job=[];
        if cursor>numel(sides), return; end
        side=sides{cursor};
        job=struct('side',side,'alpha',alpha,'nu',nu,'rho',rho, ...
            'certificateFile',fullfile(certificateDir,['pilot_' side '.mat']));
    end

    function accept_result(job,Results)
        side=job.side;
        Pilot.(side)=struct('alpha',alpha,'rho',rho,'nu',nu,'side',side, ...
            'gamma',Results.gamma);
        Example_6_save_checkpoint(fullfile(exampleDir,['Example_6_pilot_' side '.mat']), ...
            'Results',Results);
        Example_6_save_checkpoint(fullfile(exampleDir,'Example_6_pilot_comparison.mat'), ...
            'Pilot',Pilot);
        if isfield(Results,'error'), fprintf('%s\n',Results.error); end
        fprintf('\n%s gain bound: %.9g; accepted=%d\n',side,Results.gamma,Results.feasible);
    end
end
