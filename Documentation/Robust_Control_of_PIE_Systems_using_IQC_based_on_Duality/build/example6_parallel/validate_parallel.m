function validate_parallel
here=fileparts(mfilename('fullpath'));
addpath(here);
testDir=fullfile(here,'test_results');
if ~isfolder(testDir), mkdir(testDir); end
mockDir=fullfile(here,'mock');
P=struct('model','mock'); settings=struct('ddM',3);
Results=struct('alpha',[.03,.04,.9],'rho',[-1,-2],'nu',0,'side','primal', ...
    'gamma',nan(3,2),'completed',false(3,2),'configuration',settings);
Results=Example_6_disk_results(Results,fullfile(testDir,'diagnostics'));
checkpoint=fullfile(testDir,'checkpoint.mat');
Results=Example_6_sweep_points(P,settings,mockDir,testDir,Results,2,checkpoint);
assert(isequal(Results.completed,[true,true;true,true;false,false]));
assert(all(abs(Results.gamma(1,:)-1.03)<1e-12));
assert(~isfield(Results,'diagnostics'));
first=load(fullfile(Results.diagnosticsDirectory,'a1_r1_n1.mat'),'trial');
second=load(fullfile(Results.diagnosticsDirectory,'a2_r1_n1.mat'),'trial');
failed=load(fullfile(Results.diagnosticsDirectory,'a3_r1_n1.mat'),'trial');
assert(max(first.trial.started,second.trial.started)<min(first.trial.finished,second.trial.finished), ...
    'Workers did not overlap.');
assert(second.trial.finished<first.trial.finished,'Out-of-order completion was not exercised.');
assert(isfield(failed.trial,'error') && isfile(failed.trial.logFile));
assert(contains(fileread(failed.trial.logFile),'Intentional worker failure'));
saved=load(checkpoint,'Results');
assert(isequaln(saved.Results,Results));
% Completed checkpoints with all static aliases already solved launch no jobs.
Results.completed(:)=true;
Example_6_sweep_points(P,settings,mockDir,testDir,Results,2,checkpoint);
fprintf('PARALLEL_SCHEDULER_TESTS_PASSED: overlap, out-of-order save, static reuse, failed worker, resume.\n');
for name={'Example_6.m','Example_6_run_jobs.m','Example_6_sweep_points.m','Example_6_pilot_points.m'}
    issues=checkcode(fullfile(here,name{1}),'-id');
    assert(~any(strcmp({issues.id},'PARSE')));
end
end
