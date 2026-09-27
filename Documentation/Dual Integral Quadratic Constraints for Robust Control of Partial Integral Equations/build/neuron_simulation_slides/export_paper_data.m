out=fileparts(mfilename('fullpath'));
codeRoot='C:/Users/thijs/Desktop/PIETOOLS-Duality/Code';
addpath(genpath('C:/Program Files/MATLAB/PIETOOLS/PIETOOLS'));
addpath(genpath(codeRoot));
source=fullfile(codeRoot,'Executables','Examples','stn_gpe_sector_simulation.mat');
data=load(source,'Results','provenance');R=data.Results;p=data.provenance;
assert(p.lambdaSector==1 && p.lambdaZF==0);
assert(R.synthesis.feasible);
for entry={'simOpen','simClosed'}
 name=entry{1};s=R.(name);t=s.t(:);
 pulse=sin(pi*(t-.10)/.04).^2.*(t>=.10 & t<=.14);
 control=zeros(size(t));
 if strcmp(name,'simClosed'),control=s.u(:,1)*p.controlScaleToPaper;end
 values=table(t,s.xS(:),s.xG(:),control,10*pulse,-10*pulse,s.zDelta(:,1),s.zDelta(:,2), ...
 'VariableNames',{'t','xS','xG','u','dS','dG','zS','zG'});
 writetable(values,fullfile(out,[name '.csv']));
end
meta=struct('source',source,'controllerFile',fullfile(codeRoot,'Executables','Examples','stn_gpe_sector_controller.mat'), ...
 'alpha',R.synthesis.betaBar,'equilibrium',[R.parameters.xS0 R.parameters.xG0],'validation',R.validation, ...
 'pulseInterval',p.disturbanceInterval,'pulseAmplitude',p.disturbanceAmplitude, ...
 'initialHistory',p.initialHistory,'controlScaleToPaper',p.controlScaleToPaper, ...
 'coordinates',p.coordinates);
meta=dense(meta);
fid=fopen(fullfile(out,'paper_data.json'),'w');fwrite(fid,jsonencode(meta,PrettyPrint=true));fclose(fid);
disp('Exported the actual paper controller response and matching uncontrolled response.');
function v=dense(v)
if isnumeric(v),v=full(v);
elseif isstruct(v)
 for i=1:numel(v),for f=fieldnames(v).',v(i).(f{1})=dense(v(i).(f{1}));end,end
elseif iscell(v)
 for i=1:numel(v),v{i}=dense(v{i});end
end
end
