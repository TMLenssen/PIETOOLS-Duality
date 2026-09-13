function validate_cleanup
here=fileparts(mfilename('fullpath'));
addpath(here);
baseline=matlab_ids();
launched=[];
calls=0;
lastwarn('');
try
    Example_6_run_jobs(struct,struct,fullfile(here,'mock'),2,@next_job,@accept_result);
    error('Example6:TestFailed','Expected the coordinator failure.');
catch err
    assert(strcmp(err.identifier,'Example6:ExpectedCancellation'),'%s',err.message);
end
deadline=tic;
while ~isempty(intersect(launched,matlab_ids())) && toc(deadline)<10
    pause(.1);
end
assert(isempty(intersect(launched,matlab_ids())),'Worker process survived cleanup.');
[msg,~]=lastwarn;
assert(~contains(msg,'onCleanup') && ~contains(msg,'Could not stop'),'Cleanup emitted a warning.');
fprintf('WORKER_CLEANUP_TEST_PASSED\n');

    function job=next_job
        calls=calls+1;
        if calls==2
            pause(5);
            launched=setdiff(matlab_ids(),baseline);
            assert(~isempty(launched),'No worker process was launched.');
            error('Example6:ExpectedCancellation','Intentional coordinator interruption.');
        end
        job=struct('alpha',.03,'rho',-1,'nu',0,'side','primal', ...
            'certificateFile',fullfile(here,'cancelled_certificate.mat'));
    end

    function accept_result(varargin)
        error('Example6:TestFailed','The interrupted worker should not finish.');
    end
end

function ids=matlab_ids
processes=System.Diagnostics.Process.GetProcessesByName('MATLAB');
ids=zeros(1,processes.Length);
for n=1:processes.Length
    ids(n)=double(processes(n).Id);
    processes(n).Dispose();
end
end
