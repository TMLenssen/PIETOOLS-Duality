function validate_resume
% Exercise checkpoint/restart branches with a stub solve and real PIE model.
stagedDir=fileparts(mfilename('fullpath'));
testDir=fullfile(stagedDir,'resume_test');
if ~isfolder(testDir), mkdir(testDir); end
addpath(stagedDir);
source=fileread(fullfile(stagedDir,'Example_6.m'));
source=strrep(source,'clear; clc; close all; clear stateNameGenerator','clear stateNameGenerator');
source=strrep(source,"exampleDir=fileparts(mfilename('fullpath'));", ...
    "exampleDir='"+strrep(testDir,"'","''")+"';");
source=strrep(source,'codeRoot=fileparts(fileparts(fileparts(exampleDir)));', ...
    "codeRoot='C:/Users/thijs/Desktop/PIETOOLS-Duality/Code';");
source=strrep(source,'Example_6_run_point(','fake_run_point(');
source=strrep(source,'plot_Example_6(','fake_plot(');
global example6TestCalls
example6TestCalls=0;
eval(source);
assert(example6TestCalls==16,'Initial run did not compute every point.');
eval(source);
assert(example6TestCalls==16,'Restart repeated completed points.');
changed=strrep(source,'settings.ddM=3;','settings.ddM=4;');
eval(changed);
assert(example6TestCalls==32,'Changed settings incorrectly reused checkpoints.');
clear global example6TestCalls
fprintf('CHECKPOINT_RESUME_TESTS_PASSED\n');
end

function result=fake_run_point(~,alpha,nu,rho,~,~,side,~)
global example6TestCalls
example6TestCalls=example6TestCalls+1;
result=struct('feasible',true,'gamma',1+alpha,'alpha',alpha, ...
    'nu',nu,'rho',rho,'side',side,'seconds',0,'certificateFile','');
end

function fake_plot(varargin)
end
