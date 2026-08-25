%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS_IQC_analysis.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% General KYP/IQC analysis executive for an assembled filtered graph G.
% The primal and dual graph realizations differ, but their KYP LPI is the
% same. Assemble GP or GD with PIETOOLS_IQC_graph before calling this
% function.
%
% INPUT:
% prog     - initialized PIETOOLS program containing any multiplier
%            decision variables and constraints
% settings - an lpisettings() structure
% G        - assembled graph with fields
%            vars,dom,T,A,B1,C1,C2,D11,D21
% V        - primal or dual multiplier as numeric/dpvar or opvar/dopvar
%
% OUTPUT:
% P        - storage operator proving the IQC inequality
% prog     - solved PIETOOLS LPI program
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [P,prog] = PIETOOLS_IQC_analysis(prog,settings,G,V)

% Check if all inputs are properly specified.
narginchk(4,4);
if ~isstruct(prog) || ~isfield(prog,'decvartable')
    error('prog must be initialized with lpiprogram before this call.');
end
if ~isstruct(G)
    error('G must be an assembled filtered-graph struct.');
end
graphFields = {'vars','dom','T','A','B1','C1','C2','D11','D21'};
missing = graphFields(~isfield(G,graphFields));
if ~isempty(missing)
    error('G is missing field(s): %s.',strjoin(missing,', '));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define the operators in the assembled graph box.
% This is the block to edit when the box definitions change.
vars = G.vars;
dom = G.dom;
T = G.T;
A = G.A;
B = G.B1;
C = [G.C1;
     G.C2];
D = [G.D11;
     G.D21];
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
epsilon = epneg;

if isnumeric(V) || isa(V,'dpvar')
    if ~isequal(size(V),[sum(C.dim(:,1)),sum(C.dim(:,1))])
        error('V has dimensions incompatible with the realization output.');
    end
    V = mat2opvar(V,C.dim(:,1),vars,dom);
elseif ~(isa(V,'opvar') || isa(V,'dopvar'))
    error('V must be a numeric/dpvar matrix or opvar/dopvar.');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 1: Declare the positive storage operator.
[prog,P1] = poslpivar(prog,T.dim,dd1,options1);
if override1~=1
    [prog,P2] = poslpivar(prog,T.dim(:,1),dd12,options12);
    Pdec = P1+P2;
else
    Pdec = P1;
end

% Enforce strict positivity of the storage operator.
Imat = blkdiag(eppos*eye(Pdec.dim(1,:)), ...
               eppos2*eye(Pdec.dim(2,:)));
Pdec = Pdec+mat2opvar(Imat,Pdec.dim(:,2),vars,dom);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 2: Define the KYP operator from Theorem dual-KYP.
Iw = mat2opvar(eye(sum(B.dim(:,2))),B.dim(:,2),vars,dom);
KYP = [T'*Pdec*A+(T'*Pdec*A)', T'*Pdec*B;
       B'*Pdec*T,              epsilon*Iw] ...
      +[C,D]'*V*[C,D];

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

% Solve the LPI program and extract the storage operator.
prog = quiet_lpisolve(prog,sos_opts);
P = lpigetsol(prog,Pdec);

end

function prog = quiet_lpisolve(prog,sos_opts) %#ok<INUSD>
evalc('prog = lpisolve(prog,sos_opts);');
end
