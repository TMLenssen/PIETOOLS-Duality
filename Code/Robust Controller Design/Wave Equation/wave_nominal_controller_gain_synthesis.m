clear; clc; close all; clear stateNameGenerator
echo on

path_to_PIE = 'C:\Program Files\MATLAB\PIETOOLS\PIETOOLS';
addpath(genpath(path_to_PIE))
addpath(genpath("C:\Program Files\Mosek\11.0\toolbox\r2019b")) 
addpath(genpath("C:\Program Files\MATLAB\R2023a\toolbox\symbolic"));
% =============================================
% === Declare the system of interest

% % Declare system as PDE
% Declare independent variables (time and space)
pvar t s
a=0;
b=1;
% Declare state, input, and output variables
x = pde_var('state',1,[],[]);
v1 = pde_var(s,[a,b]);
v2 = pde_var(s,[a,b]);
z1 = pde_var('output',1); 
z2 = pde_var('output',1); 
w = pde_var('input',1);
u = pde_var('control',1);
d = 1;
lam = 4;
% Declare the system equations
PDE = [diff(v1,t) == v2;    % PDE
    diff(v2,t) == d*diff(v1,s,2) +s*(2-s)*w;
    diff(x,t) == u;
    z2 == x;
    z1 == int(v1,s,[a,b]);
    
    subs(v1,s,a) == 0;
    subs(v2,s,a) == 0;
    subs(diff(v1,s),s,1)==x];


display_PDE(PDE);


% Alternative implementation, using phi = [x_{s}; x_{t}]
phi = pde_var('state',2,s,[0,1]);   x = pde_var('state',1,[],[]);
w = pde_var('input',1);             r = pde_var('output',2);
u = pde_var('control');   
eq_dyn = [diff(x,t,1)==u
          diff(phi,t,1)==[0 1; d 0]*diff(phi,s,1)+[0;s*(s-1)]*w];
eq_out= r ==[x;int([1 0]*phi,s,[0,1])];
bc1 = [0 1]*subs(phi,s,0)==0;   
bc2 = [1 0]*subs(phi,s,1)==x;
PDE = [eq_dyn;eq_out;bc1;bc2];

% % Convert PDE to PIE
PIE = convert(PDE);
misc = PIE.misc;
dim = PIE.dim;
dom = PIE.dom;
vars = PIE.vars;
T = PIE.T;      Tw = PIE.Tw;    Tu = PIE.Tu;
A = PIE.A;      Bw = PIE.B1;    Bu = PIE.B2;
Cz = PIE.C1;    Dzw = PIE.D11;  Dzu = PIE.D12;



%%



settings = lpisettings('heavy');
% settings.sosineq_on = 1;
% settings.opts.pzats = 1;
settings.sos_opts.solver = 'mosek';
PIETOOLS_Hinf_control(PIE, settings)
dd1 = settings.dd1;
dd12 = settings.dd12;
sos_opts = settings.sos_opts;
options1 = settings.options1;
options12 = settings.options12;
override1 = settings.override1;
eppos = settings.eppos;
epneg = settings.epneg;
eppos2 = settings.eppos2;
ddZ = settings.ddZ;
sosineq_on = settings.sosineq_on;
if sosineq_on
    opts = settings.opts;
else
    override2 = settings.override2;
    options2 = settings.options2;
    options3 = settings.options3;
    dd2 = settings.dd2;
    dd3 = settings.dd3;
end
if ~(Tw==0)
    error('\n --- Non-coercive LPIs cannot currently be solved for systems with disturbances at the boundary. ---\n');
end

dpvar gamV gamVhat;


    % Don't support boundary disturbances


    % Declare an SOS program and initialize domain and opvar spaces
    %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    prog = lpiprogram(PIE.vars(:,1),PIE.vars(:,2),PIE.dom);      % Initialize the program structure
    % % 
    prog = lpidecvar(prog, gamV); % set gam = gamma as decision variable
    prog = lpi_ineq(prog, gamV);  % enforce gamma>=0
    prog = lpisetobj(prog, gamV); % set gamma as objective function to minimize
    % %     % STEP 1: declare the posopvar variable, Pop, which defines the storage
    % function candidate and the indefinite operator Zop, which is used to
    % contruct the estimator gain
    disp('- Declaring Positive Lyapunov Operator variable using specified options...');

    [prog, R1op] = poslpivar(prog, T.dim,dd1,options1);

    if override1~=1
        [prog, P2op] = poslpivar(prog, T.dim,dd12,options12);
        Rop=R1op+P2op;
    else
        Rop=R1op;
    end

    % Also declare an indefinite operator Qop=Pop*Top so that Rop = Top'*Qop.   % DJ, 01/06/2025
    Qdeg = get_lpivar_degs(Rop,T);
    [prog, Q] = lpivar(prog,T.dim,Qdeg);
    prog = lpi_eq(prog, T'*Q-Rop);

    [prog,Z] = lpivar(prog,Bu.dim(:,[2,1]),ddZ);

    Iw = mat2opvar(eye(size(Bw,2)), Bw.dim(:,2), PIE.vars, PIE.dom);
    Iz = mat2opvar(eye(size(Cz,1)), Cz.dim(:,1), PIE.vars, PIE.dom);

    Zw = mat2opvar(zeros(1,1), [1,1;0,0], PIE.vars, PIE.dom);
    Zzw = mat2opvar(zeros(2,1), [2,1;0,0], PIE.vars, PIE.dom);
    Zxz = mat2opvar(zeros(3,2), [1,2;2,0], PIE.vars, PIE.dom);

    V_hat = [Iw, Zzw'; Zzw, -gamV*Iz];
    Op2 = [Bw, Zxz; Dzw, Iz];
    eps = 1e-9;

    % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % STEP 2: Define the KYP matrix


    disp('- Constructing the Negativity Constraint...');

    Dop1 = [A*Q+Bu*Z+Q'*A'+Z'*Bu', Q'*Cz'+Z'*Dzu';
            Cz*Q+Dzu*Z,                  eps*Iz];

    Dop3 = Op2*V_hat*Op2';

    Dop = Dop1 + Dop3;


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % STEP 3: Impose Negativity Constraint. There are two methods, depending on
    % the options chosen
    %
    disp('- Enforcing the Negativity Constraint...');
    if sosineq_on
        disp('  - Using lpi_ineq');
        prog = lpi_ineq(prog,-Dop,opts);
    else
        disp('  - Using an Equality constraint...');
        [prog, De1op] = poslpivar(prog, Dop.dim, dd2, options2);

        if override2~=1
            [prog, De2op] = poslpivar(prog, Dop.dim, dd3, options3);
            Deop=De1op+De2op;
        else
            Deop=De1op;
        end
        prog = lpi_eq(prog,Deop+Dop,'symmetric'); %Dop=-Deop
    end


    %solving the sos program
    disp('- Solving the LPI using the specified SDP solver...');
    prog = lpisolve(prog,sos_opts);
    %Feasibility
    is_pinf = prog.solinfo.info.pinf;       % is primal feasible?
    is_dinf = prog.solinfo.info.dinf;       % is dual feasible?
    feasrat = prog.solinfo.info.feasratio;  % ratio should be close to 1

    if is_dinf || is_pinf || abs(feasrat-1)>0.1   % Stability cannot be verified --> decrease value of rho...
        feas = false;
    else
        % The system is stable --> try larger value of rho...
        feas = true;
    end
    % V11 = lpigetsol(prog,V11);
    if feas
        validated_gam = sqrt(double(lpigetsol(prog,gamV)))
        % validated_V = V11;
        Q = lpigetsol(prog,Q);
        Z = lpigetsol(prog,Z);
        tol = 1e-5;
        Kval = Z*inv(Q,tol);
    end

