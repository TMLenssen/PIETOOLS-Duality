%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS_Hinf_gain_grid.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Modified PIETOOLS_Hinf_gain executive. The H-infinity LPI is the same as
% PIETOOLS_Hinf_gain, but the KYP block operator is assembled with
% gridBuilder instead of direct bracket concatenation.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [prog,R,gam] = PIETOOLS_Hinf_gain_grid(PIE,settings)

if ~isa(PIE,'pie_struct')
    error('The PIE must be specified as a pie_struct.');
else
    PIE = initialize(PIE);
end

if PIE.dim==2
    if nargin==1
        [prog,R,gam] = PIETOOLS_Hinf_gain_2D(PIE);
    else
        [prog,R,gam] = PIETOOLS_Hinf_gain_2D(PIE,settings);
    end
    return
end

Top = PIE.T;    Twop = PIE.Tw;
Aop = PIE.A;    Bwop = PIE.Bw;
Czop = PIE.Cz;  Dzwop = PIE.Dzw;

if ~(Twop==0)
    fprintf('\n --- Non-coercive LPIs cannot currently be solved for systems with disturbances at the boundary. Calling the coercive version.---\n');
    if nargin==1
        [prog,R,gam] = PIETOOLS_Hinf_gain_coercive(PIE);
    else
        [prog,R,gam] = PIETOOLS_Hinf_gain_coercive(PIE,settings);
    end
    return
end

if nargin<2
    settings_PIETOOLS_light;
    settings.sos_opts.simplify = 1;
    settings.eppos = 1e-4;
    settings.eppos2 = 1e-6;
    settings.epneg = 0;
end

dd1 = settings.dd1;
dd12 = settings.dd12;
sos_opts = settings.sos_opts;
options1 = settings.options1;
options12 = settings.options12;
override1 = settings.override1;
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

fprintf('\n --- Searching for Hinf gain bound using primal KYP lemma (gridBuilder assembly) --- \n')
prog = lpiprogram(PIE.vars(:,1),PIE.vars(:,2),PIE.dom);

dpvar gamDec;
prog = lpidecvar(prog,gamDec);
prog = lpi_ineq(prog,gamDec);
prog = lpisetobj(prog,gamDec);

disp('- Declaring Positive Lyapunov Operator variable using specified options...');
[prog,R1op] = poslpivar(prog,Top.dim,dd1,options1);
if override1~=1
    [prog,P2op] = poslpivar(prog,Top.dim,dd12,options12);
    Rop = R1op+P2op;
else
    Rop = R1op;
end

Qdeg = get_lpivar_degs(Rop,Top);
[prog,Qop] = lpivar(prog,Top.dim,Qdeg);
prog = lpi_eq(prog,Top'*Qop-Rop);

disp('- Constructing the Negativity Constraint...');
Iw = mat2opvar(eye(size(Bwop,2)),Bwop.dim(:,2),PIE.vars,PIE.dom);
Iz = mat2opvar(eye(size(Czop,1)),Czop.dim(:,1),PIE.vars,PIE.dom);

wDim = Bwop.dim(:,2);
zDim = Czop.dim(:,1);
xDim = Top.dim(:,1);
fullDim = ioDimensions(["w","z","x"],[wDim'; zDim'; xDim']);
DopGrid = gridBuilder(fullDim,fullDim,PIE.vars,PIE.dom);
DopGrid(1,1) = -gamDec*Iw;
DopGrid(1,2) = Dzwop';
DopGrid(1,3) = Bwop'*Qop;
DopGrid(2,1) = Dzwop;
DopGrid(2,2) = -gamDec*Iz;
DopGrid(2,3) = Czop;
DopGrid(3,1) = Qop'*Bwop;
DopGrid(3,2) = Czop';
DopGrid(3,3) = Aop'*Qop+Qop'*Aop;
Dop = DopGrid();

disp('- Enforcing the Negativity Constraint...');
if sosineq_on
    disp('  - Using lpi_ineq...');
    prog = lpi_ineq(prog,-Dop,opts);
else
    disp('  - Using an Equality constraint...');
    [prog,De1op] = poslpivar(prog,Dop.dim,dd2,options2);
    if override2~=1
        [prog,De2op] = poslpivar(prog,Dop.dim,dd3,options3);
        Deop = De1op+De2op;
    else
        Deop = De1op;
    end
    prog = lpi_eq(prog,Deop+Dop,'symmetric');
end

disp('- Solving the LPI using the specified SDP solver...');
prog = lpisolve(prog,sos_opts);

R = [];
gam = [];
try
    R = lpigetsol(prog,Rop);
    gam = double(lpigetsol(prog,gamDec));
    disp('The H-infty norm of the given system is upper bounded by:')
    disp(gam);
catch
    disp('No H-infty gain value was extracted from the solved program.');
end

end
