function indexedOpvar = indexOpvar(opvarObj, outputIndexRange, inputIndexRange)
%INDEXOPVAR  Extract sub-operator using index ranges.
%   outputIndexRange: struct with fields R, L2
%   inputIndexRange : struct with fields R, L2
%   Empty ranges are allowed and will produce 0-sized dimensions/blocks.
    % Minimal checks
    if nargin ~= 3
        error('indexOpvar:Args', 'Usage: indexOpvar(opvar, outputIndexRange, inputIndexRange)');
    end
    if ~isa(opvarObj,'opvar') && ~isa(opvarObj,'dopvar')
        error('indexOpvar:Type', 'opvar must be opvar or dopvar.');
    end
    if ~isstruct(outputIndexRange) || ~isstruct(inputIndexRange)
        error('indexOpvar:RangeType', 'outputIndexRange and inputIndexRange must be structs.');
    end
    if ~all(isfield(outputIndexRange, {'R','L2'})) || ~all(isfield(inputIndexRange, {'R','L2'}))
        error('indexOpvar:RangeFields', 'Ranges must have fields R and L2.');
    end

    outR = outputIndexRange.R;
    outL = outputIndexRange.L2;
    inR  = inputIndexRange.R;
    inL  = inputIndexRange.L2;

    % Minimal index validity (only if non-empty)
    checkIdx(outR, 'outputIndexRange.R');
    checkIdx(outL, 'outputIndexRange.L2');
    checkIdx(inR,  'inputIndexRange.R');
    checkIdx(inL,  'inputIndexRange.L2');

    % Dimensions: empties imply 0
    outputDim = [numel(outR); numel(outL)];
    inputDim  = [numel(inR);  numel(inL)];

    % Indexing that preserves 0-sized shapes when one side is empty
    newP  = safe2D(opvarObj.P,  outR, inR);
    newQ1 = safe2D(opvarObj.Q1, outR, inL);
    newQ2 = safe2D(opvarObj.Q2, outL, inR);

    fn = fieldnames(opvarObj.R);
    newR = struct();
    for k = 1:numel(fn)
        newR.(fn{k}) = safe2D(opvarObj.R.(fn{k}), outL, inL);
    end
    
    indexedOpvar      = opvar();
    indexedOpvar.dim  = [outputDim, inputDim];
    indexedOpvar.I    = opvarObj.I;
    indexedOpvar.var1 = opvarObj.var1;
    indexedOpvar.var2 = opvarObj.var2;
    indexedOpvar.P    = newP;
    indexedOpvar.Q1   = newQ1;
    indexedOpvar.Q2   = newQ2;
    indexedOpvar.R    = newR;

    % --- helpers ---
    function checkIdx(idx, name)
        if isempty(idx), return; end
        if any(idx < 1) || any(idx ~= floor(idx))
            error('indexOpvar:BadIndex', '%s must contain positive integers.', name);
        end
    end

    function S = safe2D(A, rr, cc)
        % Ensures correct empty shape (m-by-0 or 0-by-n) by indexing with [] explicitly.
        if isempty(rr) && isempty(cc)
            S = A([], []);
        elseif isempty(rr)
            S = A([], cc);
        elseif isempty(cc)
            S = A(rr, []);
        else
            S = A(rr, cc);
        end
    end
end
