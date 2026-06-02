function indexRange = indexRange2D(startIdx, endIdx)
%indexRange2D Returns row and column indices between two points in a 2D grid
%
%   [#R, #L2] = indexRange2D([R1, L1], [R2, L2])
%       #R  : R indices from R1 to R2 (inclusive)
%       #L2  : L2 indices from C1 to C2 (inclusive)

    R1 = startIdx(1); C1 = startIdx(2);
    R2 = endIdx(1);   C2 = endIdx(2);

    indexRange.R = R1:R2;
    indexRange.L2 = C1:C2;
end
