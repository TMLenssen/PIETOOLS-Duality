%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PIETOOLS_IQC_graph.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Assemble the common open filtered graph in the paper.
%
% For the primal construction, supply P and Psi. For the dual construction,
% supply P^T and D(Psi). In both cases this function forms
%
%                           G = F*[P;I],
%
% where F is the supplied primal or dual filter.
%
% Controller closure is deliberately not part of this function.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function G = PIETOOLS_IQC_graph(P,F)

narginchk(2,2);
check_boxes(P,F);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define the operators in the supplied system and filter boxes.
vars = P.vars;
dom = P.dom;
TP = P.T;
AP = P.A;
BP = P.B1;
CP = P.C1;
DP = P.D11;

TF = F.T;
AF = F.A;
B1F = F.B1;
B2F = F.B2;
C1F = F.C1;
C2F = F.C2;
D11F = F.D11;
D12F = F.D12;
D21F = F.D21;
D22F = F.D22;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

T = blkdiag(TP,TF);
ZPF = zero_operator(TP.dim(:,1),TF.dim(:,2),vars,dom);
A = [AP,             ZPF;
     B1F*CP,         AF];
B1 = [BP;
      B1F*DP+B2F];
C1 = [D11F*CP,C1F];
C2 = [D21F*CP,C2F];
D11 = D11F*DP+D12F;
D21 = D21F*DP+D22F;

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

function check_boxes(P,F)
if ~isstruct(P) || ~isstruct(F)
    error('P and F must be operator-box structs.');
end
plantFields = {'vars','dom','T','A','B1','C1','D11'};
filterFields = {'T','A','B1','B2','C1','C2', ...
    'D11','D12','D21','D22'};
missing = plantFields(~isfield(P,plantFields));
if ~isempty(missing)
    error('P is missing field(s): %s.',strjoin(missing,', '));
end
missing = filterFields(~isfield(F,filterFields));
if ~isempty(missing)
    error('F is missing field(s): %s.',strjoin(missing,', '));
end
end

function Z = zero_operator(rowDim,colDim,vars,dom)
Z = mat2opvar(zeros(sum(rowDim),sum(colDim)), ...
    [rowDim,colDim],vars,dom);
end
