function Results=Example_6_disk_results(Results,directory)
% Store legacy diagnostics individually; keep only numeric sweep summaries.
if ~isfield(Results,'diagnosticsDirectory')
    Results.diagnosticsDirectory=directory;
end
directory=Results.diagnosticsDirectory;
if ~isfolder(directory), mkdir(directory); end
if isfield(Results,'diagnostics')
    % Compatibility with existing checkpoints. No solve is repeated.
    gridSize=size(Results.gamma);
    for index=1:numel(Results.diagnostics)
        if isempty(Results.diagnostics{index}), continue; end
        [i,j,k]=ind2sub(gridSize,index);
        fileName=fullfile(directory,sprintf('a%d_r%d_n%d.mat',i,j,k));
        Example_6_save_checkpoint(fileName,'trial',Results.diagnostics{index});
        Results.diagnostics{index}=[];
    end
    Results=rmfield(Results,'diagnostics');
end
end
