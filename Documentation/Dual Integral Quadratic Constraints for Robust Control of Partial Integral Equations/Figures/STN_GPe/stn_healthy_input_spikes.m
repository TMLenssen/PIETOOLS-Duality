function stn_healthy_input_spikes
% Second view of the healthy simulation: Eq. (21) input u in spikes/s.
% Run after stn_healthy_stimulation.m. Uses the same saved trajectory.
outDir = fileparts(mfilename('fullpath'));
data = load(fullfile(outDir,'stn_healthy_stimulation.mat'),'p','current_mA');
fig = openfig(fullfile(outDir,'stn_healthy_stimulation.fig'),'new','visible');
inputAxes = [];
for ax = findall(fig,'Type','axes')'
    if strcmp(ax.YLabel.String,'Current (mA)')
        inputAxes = ax;
        break
    end
end
assert(~isempty(inputAxes),'Could not find the current input panel.');
inputLine = findobj(inputAxes,'Type','stair');
assert(isscalar(inputLine),'Expected one current pulse train.');
% 0.2 mA * 4600 (spikes/s)/mA = 920 spikes/s model input amplitude.
inputLine.YData = data.p.Stim*data.current_mA;
inputAxes.YLim = data.p.Stim*inputAxes.YLim;
ylabel(inputAxes,'spikes/s');
pdfPath = fullfile(outDir,'stn_healthy_input_spikes.pdf');
exportgraphics(fig,pdfPath,'ContentType','vector','BackgroundColor','none');
[status,message] = system(sprintf('python "%s" "%s"', ...
    fullfile(outDir,'render_stn_plot.py'),pdfPath));
assert(status == 0,'Transparent PNG export failed: %s',message);
savefig(fig,fullfile(outDir,'stn_healthy_input_spikes.fig'));
fprintf('Saved second plot with input amplitude %g spikes/s.\n', ...
    max(inputLine.YData));
end
