function Example_6_worker(inputFile,outputFile)
job=load(inputFile);
started=posixtime(datetime('now'));
if job.alpha==.9
    error('Example6:TestFailure','Intentional worker failure.');
end
if job.alpha==.03, pause(20); else, pause(1); end
result=struct('feasible',true,'gamma',job.alpha+1,'seconds',1, ...
    'started',started,'finished',posixtime(datetime('now')), ...
    'info',ones(128,1024),'certificateFile',job.certificateFile);
save(job.certificateFile,'result','-v7.3');
save(outputFile,'result','-v7.3');
end
