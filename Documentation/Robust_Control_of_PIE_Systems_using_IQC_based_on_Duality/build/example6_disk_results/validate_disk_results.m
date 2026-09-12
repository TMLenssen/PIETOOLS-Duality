function validate_disk_results
here=fileparts(mfilename('fullpath'));
addpath(here);
source=fileread(fullfile(here,'Example_6.m'));
start=strfind(source,'if ~runPoleSweep');
source=source(start(1):end);
source=strrep(source,'Example_6_run_point(','fake_run_point(');
source=strrep(source,'plot_Example_6(','fake_plot(');
exampleDir=fullfile(here,'test_results');
if ~isfolder(exampleDir), mkdir(exampleDir); end
certificateDir=exampleDir;
P=struct('model','test');
settings=struct('ddM',3);
alpha=.5; nu=1; rho=-1;
sides={'primal','dual'};
runPoleSweep=true;
resumeSweep=true;
global diskTestCalls
diskTestCalls=0;
eval(source);
assert(diskTestCalls==16);
assert(~exist('trial','var') && ~exist('Results','var'));
assert(~isfield(Comparison.primal,'diagnostics'));
assert(~isfield(Comparison.dual,'diagnostics'));
saved=load(fullfile(exampleDir,'Example_6_Fig7_primal.mat'),'Results');
assert(~isfield(saved.Results,'diagnostics'));
assert(all(saved.Results.completed(:)));
point=load(fullfile(saved.Results.diagnosticsDirectory,'a1_r1_n1.mat'),'trial');
assert(point.trial.info.large(1)==42);
clear point
% Simulate a legacy checkpoint with in-memory diagnostics and migrate it.
saved.Results.diagnostics=cell(size(saved.Results.gamma));
saved.Results.diagnostics{1}=struct('feasible',true,'gamma',1.03,'info',42);
saved.Results=rmfield(saved.Results,'diagnosticsDirectory');
Example_6_save_checkpoint(fullfile(exampleDir,'Example_6_Fig7_primal.mat'),'Results',saved.Results);
clear saved
eval(source);
assert(diskTestCalls==16,'Resume repeated completed solves.');
saved=load(fullfile(exampleDir,'Example_6_Fig7_primal.mat'),'Results');
assert(~isfield(saved.Results,'diagnostics'),'Legacy diagnostics retained in RAM.');
point=load(fullfile(saved.Results.diagnosticsDirectory,'a1_r1_n1.mat'),'trial');
assert(point.trial.info==42,'Legacy diagnostic not preserved.');
clear saved point
settings.ddM=4;
eval(source);
assert(diskTestCalls==32,'Changed settings incorrectly reused old results.');
runPoleSweep=false;
eval(source);
assert(diskTestCalls==34);
assert(~exist('Results','var'));
assert(~isfield(Pilot.primal,'info') && ~isfield(Pilot.dual,'info'));
saved=load(fullfile(exampleDir,'Example_6_pilot_primal.mat'),'Results');
assert(saved.Results.info.large(1)==42,'Pilot diagnostics not saved.');
clear global diskTestCalls
for file={'Example_6.m','Example_6_disk_results.m'}
    issues=checkcode(fullfile(here,file{1}),'-id');
    assert(~any(strcmp({issues.id},'PARSE')));
end
fprintf('DISK_RESULTS_TESTS_PASSED: per-point save, cleared diagnostics, legacy migration, resume, settings mismatch, pilot.\n');
end

function result=fake_run_point(~,alpha,nu,rho,~,~,side,~)
global diskTestCalls
diskTestCalls=diskTestCalls+1;
result=struct('feasible',true,'gamma',1+alpha,'alpha',alpha, ...
    'nu',nu,'rho',rho,'side',side,'seconds',0,'certificateFile','', ...
    'info',struct('large',42*ones(128,1024)));
end

function fake_plot(varargin)
end
