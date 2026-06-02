function PIE_CL = stateFeedbackCL(PIE, Kval)
%BUILDCLOSEDLOOPPIE Build closed-loop PIE structure for a fixed controller gain.
%
%   PIE_CL = buildClosedLoopPIE(PIE, Kval)
%
% Builds the closed-loop PIE
%
%   A_cl  = A + B2*Kval
%   C1_cl = C1 + D12*Kval
%
% while preserving B1, D11, C2, D21, and metadata needed by PIESIM.

    %% Dimensions
    nx = PIE.A.dim(:,1);
    nw = PIE.B1.dim(:,2);
    nz = PIE.C1.dim(:,1);

    stateDim  = ioDimensions("x1", nx');
    inputDim  = ioDimensions("w",  nw');
    outputDim = ioDimensions("z",  nz');

    %% Build closed-loop operators
    Tcl   = gridBuilder(stateDim,  stateDim,  PIE.vars, PIE.dom);
    Acl   = gridBuilder(stateDim,  stateDim,  PIE.vars, PIE.dom);
    B1cl  = gridBuilder(stateDim,  inputDim,  PIE.vars, PIE.dom);
    C1cl  = gridBuilder(outputDim, stateDim,  PIE.vars, PIE.dom);

    Tcl(1,1)  = PIE.T;
    Acl(1,1)  = PIE.A + PIE.B2*Kval;
    B1cl(1,1) = PIE.B1;
    C1cl(1,1) = PIE.C1 + PIE.D12*Kval;

    %% Assemble PIE data
    data = struct();

    data.misc = PIE.misc;
    data.dim  = PIE.dim;
    data.dom  = PIE.dom;
    data.vars = PIE.vars;

    data.T   = Tcl();
    data.A   = Acl();
    data.B1  = B1cl();
    data.C1  = C1cl();
    data.D11 = PIE.D11;

    % Keep sensed outputs available in PIESIM
    data.C2  = PIE.C2;
    data.D21 = PIE.D21;

    %% Create and initialize PIE structure
    PIE_CL = pie_struct(data);
    PIE_CL = initialize(PIE_CL);

end