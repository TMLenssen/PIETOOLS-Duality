%% Sector-bounded memoryless Delta: hard IQC and dissipativity
% Standalone base-MATLAB script. No PDE/plant or toolboxes required.
% Same example as the editable Sector IQC presentation.
clear; close all;
alpha=0.2; beta=1.2;
t=linspace(0,12,1441)'; s=linspace(0,1,161);
z=(1-exp(-2*t)).*(1.6*sin(2*pi*t/4).*cos(pi*s) ...
    +0.4*sin(2*pi*t/1.7).*sin(2*pi*s));
w=0.7*z+0.3*tanh(z);
q=(beta*z-w).*(w-alpha*z);
sigma=trapz(s,q,2); accumulated=cumtrapz(t,sigma);
V=[-alpha*beta,(alpha+beta)/2;(alpha+beta)/2,-1];
qMatrix=V(1,1)*z.^2+2*V(1,2)*z.*w+V(2,2)*w.^2;
assert(min(q(:))>=-1e-12);
assert(max(abs(q(:)-qMatrix(:)))<1e-12);
assert(min(diff(accumulated))>=-1e-12);
fprintf('Minimum supply: %.6g; final hard-IQC integral: %.6g\n',min(q(:)),accumulated(end));
% Analytically, w/z = .7+.3*tanh(z)/z is between .7 and 1
% for z~=0, so the [.2,1.2] sector holds globally; phi(0)=0.
% q>=0 implies integral_0^T sigma(t)dt>=0 for every T, and storage S=0.
% This is a property of Delta, not a closed-loop stability certificate.
j=41; red=[.84 .06 .09]; green=[.08 .49 .38]; blue=[.13 .44 .61];
f=figure('Color','w','Position',[80 80 1300 720]);
ax1=subplot(2,2,[1 3]);hold on; zz=linspace(-2.1,2.1,400);
fill([0 2.1 2.1],[0 alpha*2.1 beta*2.1],[.93 .95 .97],'EdgeColor','none');
fill([0 -2.1 -2.1],[0 -alpha*2.1 -beta*2.1],[.93 .95 .97],'EdgeColor','none');
plot(zz,alpha*zz,'Color',[.5 .5 .5]);plot(zz,beta*zz,'Color',[.5 .5 .5]);
plot(zz,.7*zz+.3*tanh(zz),'Color',red,'LineWidth',2);
scatterPoints=scatter(z(1,1:4:end),w(1,1:4:end),12,[.6 .6 .6],'filled');
point=plot(0,0,'o','MarkerFaceColor',red,'MarkerEdgeColor',red);
gap1=plot([0 0],[0 0],'Color',blue,'LineWidth',3);
gap2=plot([0 0],[0 0],'Color',green,'LineWidth',3);
xlabel('$z_\Delta(t,s)$','Interpreter','latex');ylabel('$w_\Delta(t,s)$','Interpreter','latex');
title('Sector [0.2,1.2]');xlim([-2.2 2.2]);ylim([-2.6 2.6]);box off;
ax2=subplot(2,2,2);hold on;
input=plot(nan,nan,'Color',blue,'LineWidth',1.7);output=plot(nan,nan,'Color',red,'LineWidth',1.7);
xlim([0 12]);ylim([-2 2]);title('Input/output at s=0.25');legend('z_\Delta(t,0.25)','w_\Delta(t,0.25)','Location','northeast');box off;
ax3=subplot(2,2,4);hold on;intline=plot(nan,nan,'Color',green,'LineWidth',2);
xlim([0 12]);ylim([0 accumulated(end)*1.1]);xlabel('Time [s]');ylabel('Hard-IQC integral');box off;
for i=1:6:length(t)
 if ~isgraphics(f),break;end
 set(scatterPoints,'XData',z(i,1:4:end),'YData',w(i,1:4:end));
 set(point,'XData',z(i,j),'YData',w(i,j));
 set(gap1,'XData',[z(i,j) z(i,j)],'YData',[beta*z(i,j) w(i,j)]);
 set(gap2,'XData',[z(i,j) z(i,j)],'YData',[w(i,j) alpha*z(i,j)]);
 set(input,'XData',t(1:i),'YData',z(1:i,j));set(output,'XData',t(1:i),'YData',w(1:i,j));
 set(intline,'XData',t(1:i),'YData',accumulated(1:i));
 title(ax3,sprintf('Integral = %.3f; spatial supply = %.3f',accumulated(i),sigma(i)));
 drawnow;pause(.025);
end
