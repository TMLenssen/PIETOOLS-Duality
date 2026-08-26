%SIMULATE_SINE_GORDON_STABLE_UNSTABLE
% Uncontrolled shifted sine-Gordon model used in Example_2.
%
%   z_tt = d*z_ss + sigma*sin(z) - damp*z_t
%   z(0,t) = 0,   z_s(1,t) = 0
%
% This is the plant after closing the graph uncertainty
%   wd = z - sin(z)
% and setting u = 0, w = 0, x_b(0) = 0.

% clear; close all; clc;

%% Parameters
d = 1;
sigma = 3;
damp = 0.2;

Nx = 201;
Tfinal = 120;
cfl = 0.20;

s = linspace(0,1,Nx).';
dx = s(2)-s(1);
dt = cfl*dx/sqrt(d);
Nt = ceil(Tfinal/dt);
dt = Tfinal/Nt;

%% z_ss with z(0)=0 and z_s(1)=0
n = Nx-1;
e = ones(n,1);
Dss = spdiags([e -2*e e],-1:1,n,n)/dx^2;
Dss(end,end-1) = 2/dx^2;
Dss(end,end) = -2/dx^2;

%% Initial condition
z0 = 0.12*sin(0.5*pi*s);
v0 = zeros(Nx,1);
y = [z0(2:end); v0(2:end)];

%% Storage
storeStride = max(1,round(Nt/500));
Nstore = floor(Nt/storeStride)+1;
tStore = zeros(Nstore,1);
Zstore = zeros(Nstore,Nx);
tHist = zeros(Nt+1,1);
amp = zeros(Nt+1,1);

tStore(1) = 0;
Zstore(1,:) = z0.';
amp(1) = max(abs(z0));

%% Time integration
storeIdx = 1;
for k = 1:Nt
    y = rk4_step(y,dt,Dss,d,sigma,damp);

    z = [0; y(1:n)];
    t = k*dt;

    tHist(k+1) = t;
    amp(k+1) = max(abs(z));

    if mod(k,storeStride)==0
        storeIdx = storeIdx+1;
        tStore(storeIdx) = t;
        Zstore(storeIdx,:) = z.';
    end
end

tStore = tStore(1:storeIdx);
Zstore = Zstore(1:storeIdx,:);

%% Plots
figure('Name','Uncontrolled shifted sine-Gordon','Color','w');

subplot(2,1,1);
imagesc(s,tStore,Zstore);
axis xy;
colorbar;
xlabel('s');
ylabel('t');
title('z(s,t)');

subplot(2,1,2);
plot(tHist,amp,'LineWidth',1.5);
grid on;
xlabel('t');
ylabel('max_s |z(s,t)|');
title('Open-loop amplitude');

linearThreshold = d*(pi/2)^2;
fprintf('Simulation complete. dx = %.4g, dt = %.4g, Nt = %d\n',dx,dt,Nt);
fprintf('sigma = %.4g, linear instability threshold = %.4g\n',sigma,linearThreshold);
fprintf('Final max |z| = %.4g\n',amp(end));

%% Local functions
function yNew = rk4_step(y,dt,Dss,d,sigma,damp)
k1 = rhs(y,Dss,d,sigma,damp);
k2 = rhs(y+0.5*dt*k1,Dss,d,sigma,damp);
k3 = rhs(y+0.5*dt*k2,Dss,d,sigma,damp);
k4 = rhs(y+dt*k3,Dss,d,sigma,damp);
yNew = y + (dt/6)*(k1+2*k2+2*k3+k4);
end

function dy = rhs(y,Dss,d,sigma,damp)
n = size(Dss,1);
z = y(1:n);
v = y(n+1:2*n);

dz = v;
dv = d*(Dss*z) + sigma*sin(z) - damp*v;
dy = [dz; dv];
end
