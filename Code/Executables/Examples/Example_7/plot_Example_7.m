function plot_Example_7(result)
% Show only accepted PI certificates; leave solver failures as gaps.
here=fileparts(mfilename('fullpath'));
if nargin==0
    data=load(fullfile(here,'Example_7_Fig7_dual.mat')); result=data.Results;
end
if ~isfield(result,'side'), result.side='dual'; end
if ~any(isfinite(result.gamma(:)))
    warning('No accepted certificates: no gain-bound figure can be produced.');
    return
end
f=figure('Visible','off','Color','w','Position',[50,50,1400,520]);
tiledlayout(1,numel(result.nu),'TileSpacing','compact','Padding','compact');
colors=turbo(numel(result.alpha));
for k=1:numel(result.nu)
    ax=nexttile; hold(ax,'on'); colororder(ax,colors);
    for i=1:numel(result.alpha)
        semilogx(ax,abs(result.rho),result.gamma(i,:,k),'-o',...
            'LineWidth',1.2,'MarkerSize',3);
    end
    set(ax,'XScale','log','XDir','reverse'); grid(ax,'on');
    xlabel(ax,'$|\rho|$ ($\rho<0$)','Interpreter','latex');
    if strcmp(result.side,'dual'), gainLabel='$\underline{\gamma}$';
    else, gainLabel='$\gamma$'; end
    ylabel(ax,gainLabel,'Interpreter','latex');
    title(ax,sprintf('$\\nu=%d$',result.nu(k)),'Interpreter','latex');
end
lg=legend(compose('$\\alpha=%.2f$',result.alpha),'Interpreter','latex');
lg.Layout.Tile='south'; lg.NumColumns=4;
sgtitle(['Boundary-controlled heat equations: ' result.side ' IQC synthesis gain bounds']);
exportgraphics(f,fullfile(here,['fig7_boundary_heat_' result.side '.png']),'Resolution',180);
exportgraphics(f,fullfile(here,['fig7_boundary_heat_' result.side '.pdf']),'ContentType','vector');
close(f);
end


