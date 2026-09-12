function Example_6_save_checkpoint(fileName,variableName,value)
% Finish writing a new snapshot before replacing the previous checkpoint.
folder=fileparts(fileName);
temporaryFile=[tempname(folder) '.mat'];
cleanup=onCleanup(@()remove_temporary(temporaryFile)); %#ok<NASGU>
payload=struct;
payload.(variableName)=value;
save(temporaryFile,'-struct','payload','-v7.3');
[ok,message]=movefile(temporaryFile,fileName,'f');
if ~ok, error('Example6:CheckpointFailed','%s',message); end
end

function remove_temporary(fileName)
if isfile(fileName), delete(fileName); end
end
