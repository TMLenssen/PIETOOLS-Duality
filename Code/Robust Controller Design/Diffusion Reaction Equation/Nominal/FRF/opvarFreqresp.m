function FRF = opvarFreqresp(PIE_CL, omega, invSettings, opts)
%SOLVEOPVARFREQRESPMIMO Frequency response for MIMO closed-loop PIE using solve_opvar.
%
%   FRF = solveOpvarFreqrespMIMO(PIE_CL, omega)
%   FRF = solveOpvarFreqrespMIMO(PIE_CL, omega, invSettings)
%   FRF = solveOpvarFreqrespMIMO(PIE_CL, omega, invSettings, opts)
%
% Computes the MIMO frequency response for a closed-loop PIE by solving the real-valued
% block system. The transfer functions between each input-output pair are computed.
%
% Inputs
% ------
% PIE_CL       Closed-loop PIE structure with fields:
%              T, A, B1, C1, D11, vars, dom
%
% omega        Frequency grid in rad/s.
%
% invSettings  Optional LPI settings for solve_opvar.
%
% opts.verbose Optional logical flag. Default true.
%
% Output
% ------
% FRF.G        Matrix of complex frequency response (size: Nw x Ny x Nu).
% FRF.mag      Magnitude (size: Nw x Ny x Nu).
% FRF.phase    Unwrapped phase (size: Nw x Ny x Nu).
% FRF.phaseDeg Unwrapped phase in degrees (size: Nw x Ny x Nu).
% FRF.gamma    solve_opvar returned gamma (size: Nw).
% FRF.eps      sqrt(gamma) (size: Nw).
% FRF.rhsNorm  L2 norm of RHS (size: Nw).
% FRF.mxNorm   L2 norm of Mop*X (size: Nw).
% FRF.eta      Heuristic relative residual metric (size: Nw).

    if nargin < 3 || isempty(invSettings)
        invSettings = lpisettings('veryheavy');
    end

    if nargin < 4
        opts = struct();
    end

    if ~isfield(opts, "verbose")
        opts.verbose = true;
    end

    omega = omega(:);
    Nw = numel(omega);

    % Dimensions (now for MIMO systems)
    nx = PIE_CL.A.dim(:,1);
    nw = PIE_CL.B1.dim(:,2);
    nz = PIE_CL.C1.dim(:,1);

    if nw(2)~=0 || nz(2)~=0
        error('only finite dimensional channels are supported')
    end

    % Allocate outputs for MIMO
    G       = NaN(Nw, nz(1), nw(1));  % Complex frequency response (Ny x Nu)
    gamma   = NaN(Nw, 1);       % gamma (one for each frequency)
    epsFit  = NaN(Nw, 1);       % sqrt(gamma)
    rhsNorm = NaN(Nw, 1);       % RHS L2 norm
    mxNorm  = NaN(Nw, 1);       % Mop*X L2 norm
    eta     = NaN(Nw, 1);       % Heuristic residual metric

    % Real/imaginary doubled dimensions for MIMO
    stateDimC  = ioDimensions(["xr","xc"], [nx,nx]');
    inputDimC  = ioDimensions(["wr","wc"], [nw,nw]');
    outputDimC = ioDimensions(["zr","zc"], [nz,nz]');

    M    = gridBuilder(stateDimC,  stateDimC,  PIE_CL.vars, PIE_CL.dom);
    Bblk = gridBuilder(stateDimC,  inputDimC,  PIE_CL.vars, PIE_CL.dom);
    Cblk = gridBuilder(outputDimC, stateDimC,  PIE_CL.vars, PIE_CL.dom);
    Dblk = gridBuilder(outputDimC, inputDimC,  PIE_CL.vars, PIE_CL.dom);

    % Constant blocks for MIMO system
    Bblk(1,1) = PIE_CL.B1;
    Bblk(2,2) = PIE_CL.B1;

    Cblk(1,1) = PIE_CL.C1;
    Cblk(2,2) = PIE_CL.C1;

    Dblk(1,1) = PIE_CL.D11;
    Dblk(2,2) = PIE_CL.D11;

    % Real-input selector for MIMO
    wEye = eyePI(nw, PIE_CL.vars, PIE_CL.dom);
    wZero = zerosPI(nw, nw, PIE_CL.vars, PIE_CL.dom);
    Win = [wEye; wZero];

    RHS = Bblk() * Win;

    Cfull = Cblk();
    Dfull = Dblk();

    for k = 1:Nw
        wfreq = omega(k);

        if opts.verbose
            fprintf("solve_opvar frequency response: omega = %.4g rad/s (%d/%d)\n", ...
                wfreq, k, Nw);
        end

        % Real-valued block representation of jw*T - A for MIMO.
        M(1,1) = -PIE_CL.A;
        M(1,2) = -wfreq * PIE_CL.T;
        M(2,1) =  wfreq * PIE_CL.T;
        M(2,2) = -PIE_CL.A;

        Mop = M();

        % Solve Mop * X ≈ RHS
        [X, gamma(k), ~] = solve_opvar(Mop, RHS, invSettings);

        % Transfer function: [Re(G); Im(G)] = Cfull*X + Dfull*Win
        Z = Cfull * X + Dfull * Win;

        % Store frequency response for each input-output pair
        for i = 1:nz(1)
            for j = 1:nw(1)
                G(k, i, j) = double(Z.P(i,j)) + 1i * double(Z.P((i+nz(1)),j));
            end
        end

        % Compute residual and error metrics
        epsFit(k)  = sqrt(gamma(k));
        rhsNorm(k) = L2(RHS);
        mxNorm(k)  = L2(Mop * X);

        eta(k) = epsFit(k) / (mxNorm(k) + rhsNorm(k));
    end

    % Output structure
    FRF = struct();
    FRF.omega    = omega;
    FRF.G        = G;  % Matrix of frequency response
    FRF.mag      = abs(G);  % Magnitude
    FRF.phase    = unwrap(angle(G));  % Phase in radians
    FRF.phaseDeg = unwrap(angle(G)) * 180/pi;  % Phase in degrees

    FRF.gamma    = gamma;
    FRF.eps      = epsFit;
    FRF.rhsNorm  = rhsNorm;
    FRF.mxNorm   = mxNorm;
    FRF.eta      = eta;
end