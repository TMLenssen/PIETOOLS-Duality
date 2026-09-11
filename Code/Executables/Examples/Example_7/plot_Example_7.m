function plot_Example_7(result,yLimits)
% Match Veenman et al. Figure 7 using saved Example 7 bounds.
% Optional yLimits=[lower upper]; no examples or solvers are run.
here=fileparts(mfilename('fullpath'));
if nargin<1 || isempty(result)
    dataFile=fullfile(here,'Example_7_Fig7_dual.mat');
    if ~isfile(dataFile), dataFile=fullfile(here,'Example_7_Fig7.mat'); end
    data=load(dataFile,'Results'); result=data.Results;
end
if nargin<2, yLimits=[]; end
if ~isfield(result,'side'), result.side='dual'; end
previousPath=path; addpath(fileparts(here));
pathCleanup=onCleanup(@()path(previousPath));
f=plot_veenman_fig7(result,yLimits);
if isempty(f), return; end
figureCleanup=onCleanup(@()close(f));
exportgraphics(f,fullfile(here,['fig7_boundary_heat_' result.side '.png']),'Resolution',300);
exportgraphics(f,fullfile(here,['fig7_boundary_heat_' result.side '.pdf']),'ContentType','vector');
end

