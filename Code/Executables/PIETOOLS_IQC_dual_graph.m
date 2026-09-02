%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS_IQC_dual_graph.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Assemble the dual controller-filter graph from the paper,
%
%             D(Theta)*[(K star P)^T; I] : wbar -> [ztildebar; wtildebar].
%
% The supplied filter box is the dual filter D(Theta), with underlined
% realization operators. The controller operator is ordered as
% K = [K_p K_Theta] and maps the augmented state [x_P; x_Theta] to u.
% If K is omitted or empty, the zero controller is used.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function G = PIETOOLS_IQC_dual_graph(P,DTheta,K)

narginchk(2,3);
if nargin < 3
    K = [];
end
DTheta = select_filter(DTheta,'dual','DTheta');
check_boxes(P,DTheta);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define the operators in the primal plant and supplied dual-filter boxes.
vars = P.vars;
dom = P.dom;
TP = P.T;
AP = P.A;
BP = P.B1;
Bu = get_member_alias(P,'Bu','B2','P', ...
    'control-input operator Bu (or B2)');
CP = P.C1;
DP = P.D11;
Dzu = get_member_alias(P,'Dzu','D12','P', ...
    'control feedthrough Dzu (or D12)');

TD = DTheta.T;
AD = DTheta.A;
B1D = DTheta.B1;
B2D = DTheta.B2;
C1D = DTheta.C1;
C2D = DTheta.C2;
D11D = DTheta.D11;
D12D = DTheta.D12;
D21D = DTheta.D21;
D22D = DTheta.D22;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

T = block_diag2(TP',TD,vars,dom);
K = compatible_operator(K,Bu.dim(:,2),T.dim(:,2),vars,dom,'K');

ZPTheta = zero_operator(TP.dim(:,1),TD.dim(:,2),vars,dom);
ZuTheta = zero_operator(Bu.dim(:,2),TD.dim(:,2),vars,dom);

% These blocks expand exactly to Eq. (dual-system-components) with
% K = [K_p K_Theta].
A0 = block_2x2(AP',ZPTheta,B1D*BP',AD,vars,dom);
Cy = block_hcat(Bu',ZuTheta,vars,dom);
A = A0+K'*Cy;

B1 = block_vcat(CP',B1D*DP'+B2D,vars,dom)+K'*Dzu';
C1 = block_hcat(D11D*BP',C1D,vars,dom);
C2 = block_hcat(D21D*BP',C2D,vars,dom);
D11 = D11D*DP'+D12D;
D21 = D21D*DP'+D22D;

G.vars = vars;
G.dom = dom;
G.T = T;
G.A = A;
G.B1 = B1;
G.C1 = C1;
G.C2 = C2;
G.D11 = D11;
G.D21 = D21;

end

function check_boxes(P,DTheta)
if ~isstruct(P) && ~isa(P,'pie_struct')
    error('P must be an operator-box struct or pie_struct.');
end
if ~isstruct(DTheta) && ~isa(DTheta,'pie_struct')
    error('DTheta must be an operator-box struct or pie_struct.');
end
plantFields = {'vars','dom','T','A','B1','C1','D11'};
filterFields = {'T','A','B1','B2','C1','C2', ...
    'D11','D12','D21','D22'};
missing = missing_members(P,plantFields);
if ~isempty(missing)
    error('P is missing field(s): %s.',strjoin(missing,', '));
end
missing = missing_members(DTheta,filterFields);
if ~isempty(missing)
    error('DTheta is missing field(s): %s.',strjoin(missing,', '));
end
end

function F = select_filter(container,field,name)
F = container;
if (isstruct(container) || isobject(container)) && has_member(container,field)
    F = container.(field);
end
if ~isstruct(F) && ~isa(F,'pie_struct')
    error('%s must be a dual-filter box or a container with .%s.',name,field);
end
end

function value = get_member_alias(container,primary,alias,containerName,description)
if has_member(container,primary)
    value = container.(primary);
elseif has_member(container,alias)
    value = container.(alias);
else
    error('%s is missing the %s.',containerName,description);
end
end

function P = compatible_operator(value,outputDim,inputDim,vars,dom,name)
if isempty(value)
    P = zero_operator(outputDim,inputDim,vars,dom);
elseif isnumeric(value) || isa(value,'dpvar')
    if ~isequal(size(value),[sum(outputDim),sum(inputDim)])
        error('%s has incompatible dimensions.',name);
    end
    P = mat2opvar(value,[outputDim,inputDim],vars,dom);
elseif isa(value,'opvar') || isa(value,'dopvar')
    if ~isequal(value.dim(:,1),outputDim) || ...
            ~isequal(value.dim(:,2),inputDim)
        error('%s has incompatible dimensions.',name);
    end
    P = value;
else
    error('%s must be numeric, dpvar, opvar, or dopvar.',name);
end
end

function tf = has_member(container,name)
if isstruct(container)
    tf = isfield(container,name);
elseif isobject(container)
    tf = isprop(container,name);
else
    tf = false;
end
end

function missing = missing_members(container,required)
present = cellfun(@(name) has_member(container,name),required);
missing = required(~present);
end

function Z = zero_operator(rowDim,colDim,vars,dom)
Z = mat2opvar(zeros(sum(rowDim),sum(colDim)), ...
    [rowDim,colDim],vars,dom);
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
