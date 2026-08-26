%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS_IQC_controller_synthesis.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function executes the dual-IQC state-feedback synthesis LPI in
% equation (controller-kyp) of the paper.
%
% INPUT:
% prog     - initialized PIETOOLS program containing any multiplier
%            decision variables, constraints, and objective
% settings - an lpisettings() structure
% P        - generalized-plant box with PI operators as fields
% Theta    - filter container; Theta.dual is the dual-filter box
% Vbar     - dual multiplier, as a numeric/dpvar matrix or opvar/dopvar
%
% OUTPUT:
% K    - controller satisfying K = Z'*P^(-1)
% Z    - controller variable satisfying Z = P*K'
% P    - storage operator proving the dual IQC inequality
% prog - solved PIETOOLS LPI program
%
% REQUIRED MEMBERS OF P:
% vars, dom, T, A, B1, C1, D11, and either the plant-box aliases Bu/Dzu
% or the standard pie_struct names B2/D12
%
% REQUIRED FIELDS OF Theta.dual:
% T, A, B1, B2, C1, C2, D11, D12, D21, D22
%
% OPTIONAL SETTING:
% settings.kmax - certified induced-norm upper bound on K
%
% NOTE: Initialize prog and declare the parameters in Vbar before calling
% this function. Bounds and objectives on those parameters must also be
% added to prog by the caller.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [K,Z,P,prog] = PIETOOLS_IQC_controller_synthesis(prog,settings,P,Theta,Vbar)

% Check if all inputs are properly specified.
narginchk(5,5);
if ~isstruct(prog) || ~isfield(prog,'decvartable')
    error('prog must be initialized with lpiprogram before this call.');
end
if ~isstruct(P) && ~isa(P, 'pie_struct')
    error('P must be a generalized-plant struct.');
end
if ~isstruct(Theta) && ~isa(Theta, 'pie_struct')
    error('Theta must be a filter struct or a container with a .dual field.');
end
if has_member(Theta,'dual')
    ThetaD = Theta.dual;
else
    ThetaD = Theta;
end
if ~isstruct(ThetaD) && ~isa(ThetaD,'pie_struct')
    error('Theta.dual must be a struct or pie_struct.');
end

plantFields = {'vars','dom','T','A','B1','C1','D11'};
filterFields = {'T','A','B1','B2','C1','C2', ...
    'D11','D12','D21','D22'};
missing = missing_members(P,plantFields);
if ~isempty(missing)
    error('P is missing field(s): %s.',strjoin(missing,', '));
end
missing = missing_members(ThetaD,filterFields);
if ~isempty(missing)
    error('Theta.dual is missing field(s): %s.',strjoin(missing,', '));
end

% Generalized-plant structs use Bu/Dzu; native pie_struct objects use the
% standard PIETOOLS names B2/D12 for the same control channel.
if has_member(P,'Bu')
    Bu = P.Bu;
elseif has_member(P,'B2')
    Bu = P.B2;
else
    error('P is missing the control-input operator Bu (or B2).');
end
if has_member(P,'Dzu')
    Dzu = P.Dzu;
elseif has_member(P,'D12')
    Dzu = P.D12;
else
    error('P is missing the control feedthrough Dzu (or D12).');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define the operators in the generalized-plant and dual-filter boxes.
% This is the block to edit when the box definitions change.
vars = P.vars;
dom = P.dom;
TP = P.T;
AP = P.A;
BP = P.B1;
CP = P.C1;
DP = P.D11;

TD = ThetaD.T;
AD = ThetaD.A;
B1D = ThetaD.B1;
B2D = ThetaD.B2;
C1D = ThetaD.C1;
C2D = ThetaD.C2;
D11D = ThetaD.D11;
D12D = ThetaD.D12;
D21D = ThetaD.D21;
D22D = ThetaD.D22;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Get settings information, following the PIETOOLS executive structure.
if ~isstruct(settings)
    error('settings must be an lpisettings() structure.');
end
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
% Use the standard PIETOOLS negativity margin for the epsilon*I term in
% the paper; no additional settings fields are introduced.
epsIQC = epneg;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Assemble the open-loop dual augmented system D(Theta)*[P^T;I].
hasFilterStates = any(TD.dim(:,1)) || any(TD.dim(:,2));
if hasFilterStates
    ZxTheta = mat2opvar(zeros(sum(TP.dim(:,1)),sum(TD.dim(:,2))), ...
        [TP.dim(:,1),TD.dim(:,2)],vars,dom);
    ZuTheta = mat2opvar(zeros(sum(Bu.dim(:,2)),sum(TD.dim(:,2))), ...
        [Bu.dim(:,2),TD.dim(:,2)],vars,dom);

    Tdual = block_diag2(TP',TD,vars,dom);
    A0dual = block_2x2(AP',ZxTheta,B1D*BP',AD,vars,dom);
    B0dual = block_vcat(CP',B1D*DP'+B2D,vars,dom);
    Cdual = block_2x2(D11D*BP',C1D,D21D*BP',C2D,vars,dom);
    BuT = block_hcat(Bu',ZuTheta,vars,dom);
else
    % A feedthrough-only filter has no state to augment. Removing the
    % empty block row/column avoids ambiguous zero-dimensional opvar
    % concatenations and yields the same reduced realization directly.
    Tdual = TP';
    A0dual = AP';
    B0dual = CP';
    Cdual = block_vcat(D11D*BP',D21D*BP',vars,dom);
    BuT = Bu';
end
Ddual = block_vcat(D11D*DP'+D12D,D21D*DP'+D22D,vars,dom);
DzuT = Dzu';

if isnumeric(Vbar) || isa(Vbar,'dpvar')
    if ~isequal(size(Vbar),[sum(Cdual.dim(:,1)),sum(Cdual.dim(:,1))])
        error('Vbar has dimensions incompatible with the dual-filter output.');
    end
    Vbar = mat2opvar(Vbar,Cdual.dim(:,1),vars,dom);
elseif ~(isa(Vbar,'opvar') || isa(Vbar,'dopvar'))
    error('Vbar must be a numeric/dpvar matrix or opvar/dopvar.');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 1: Declare the positive storage operator Pdec and controller
% variable Zdec.
[prog,P1] = poslpivar(prog,Tdual.dim,dd1,options1);
if override1~=1
    [prog,P2] = poslpivar(prog,Tdual.dim(:,1),dd12,options12);
    Pdec = P1+P2;
else
    Pdec = P1;
end

% Enforce strict positivity of the storage operator.
Imat = blkdiag(eppos*eye(Pdec.dim(1,:)), ...
               eppos2*eye(Pdec.dim(2,:)));
Pdec = Pdec+mat2opvar(Imat,Pdec.dim(:,2),vars,dom);

% Z = P*[Kp';KTheta'] maps the controller output space into the augmented
% dual state space.
[prog,Zdec] = lpivar(prog,[Tdual.dim(:,1),BuT.dim(:,1)],ddZ);

% Optional convex controller bound. Since Z=P*K', the Schur complement
% gives K*P*K' <= pmin*kmax^2*I. Together with P>=pmin*I, this implies
% K*K' <= kmax^2*I.
if isfield(settings,'kmax') && ~isempty(settings.kmax)
    kmax = settings.kmax;
    if ~isscalar(kmax) || ~isfinite(kmax) || kmax<=0
        error('settings.kmax must be a positive finite scalar.');
    end
    pmin = min([eppos,eppos2]);
    Iu = mat2opvar(eye(sum(BuT.dim(:,1))),BuT.dim(:,1),vars,dom);
    Kb = block_2x2(pmin*kmax^2*Iu,Zdec',Zdec,Pdec,vars,dom);
    if sosineq_on
        prog = lpi_ineq(prog,Kb,opts);
    else
        [prog,Kb1] = poslpivar(prog,Kb.dim,dd2,options2);
        if override2~=1
            [prog,Kb2] = poslpivar(prog,Kb.dim,dd3,options3);
            Kbp = Kb1+Kb2;
        else
            Kbp = Kb1;
        end
        prog = lpi_eq(prog,Kbp-Kb,'symmetric');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 2: Define the controller KYP operator from (controller-kyp).
% Adual = A0dual+[Kp';KTheta']*[Bu' 0]
% Bdual = B0dual+[Kp';KTheta']*Dzu'
Iw = mat2opvar(eye(sum(B0dual.dim(:,2))),B0dual.dim(:,2),vars,dom);

K11 = Tdual'*Pdec*A0dual+Tdual'*Zdec*BuT+ ...
      (Tdual'*Pdec*A0dual+Tdual'*Zdec*BuT)';
K12 = Tdual'*Pdec*B0dual+Tdual'*Zdec*DzuT;
CDdual = block_hcat(Cdual,Ddual,vars,dom);
KYP = block_2x2(K11,K12,K12',epsIQC*Iw,vars,dom) ...
      +CDdual'*Vbar*CDdual;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 3: Impose the negativity constraint.
if sosineq_on
    prog = lpi_ineq(prog,-KYP,opts);
else
    [prog,De1] = poslpivar(prog,KYP.dim,dd2,options2);
    if override2~=1
        [prog,De2] = poslpivar(prog,KYP.dim,dd3,options3);
        De = De1+De2;
    else
        De = De1;
    end
    prog = lpi_eq(prog,De+KYP,'symmetric');
end

% Solve the LPI program.
prog = quiet_lpisolve(prog,sos_opts);

% Extract the solution and recover K = Z'*P^(-1). For separable P,
% inv_opvar uses the analytic 4-PI inverse.
P = lpigetsol(prog,Pdec);
Z = lpigetsol(prog,Zdec);

K = Z'*inv_opvar(P,0);
K = clean_opvar(K,1e-4);

end

function prog = quiet_lpisolve(prog,sos_opts)
% evalc('prog = lpisolve(prog,sos_opts);');
prog = lpisolve(prog,sos_opts);
end

function tf = has_member(container,name)
if isstruct(container)
    tf = isfield(container,name);
else
    tf = isprop(container,name);
end
end

function missing = missing_members(container,required)
present = cellfun(@(name) has_member(container,name),required);
missing = required(~present);
end

function G = block_vcat(G1,G2,vars,dom)
outDim = ioDimensions(["r1","r2"],[G1.dim(:,1)'; G2.dim(:,1)']);
inDim = ioDimensions("c1",G1.dim(:,2)');
grid = gridBuilder(outDim,inDim,vars,dom);
grid(1,1) = G1;
grid(2,1) = G2;
G = grid();
end

function G = block_hcat(G1,G2,vars,dom)
outDim = ioDimensions("r1",G1.dim(:,1)');
inDim = ioDimensions(["c1","c2"],[G1.dim(:,2)'; G2.dim(:,2)']);
grid = gridBuilder(outDim,inDim,vars,dom);
grid(1,1) = G1;
grid(1,2) = G2;
G = grid();
end

function G = block_2x2(G11,G12,G21,G22,vars,dom)
outDim = ioDimensions(["r1","r2"],[G11.dim(:,1)'; G21.dim(:,1)']);
inDim = ioDimensions(["c1","c2"],[G11.dim(:,2)'; G12.dim(:,2)']);
grid = gridBuilder(outDim,inDim,vars,dom);
grid(1,1) = G11;
grid(1,2) = G12;
grid(2,1) = G21;
grid(2,2) = G22;
G = grid();
end

function G = block_diag2(G1,G2,vars,dom)
dim = ioDimensions(["d1","d2"],[G1.dim(:,1)'; G2.dim(:,1)']);
grid = gridBuilder(dim,dim,vars,dom);
grid(1,1) = G1;
grid(2,2) = G2;
G = grid();
end
