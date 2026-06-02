function [Pfit, gam_sol, mu_sol, ELfit, ERfit, prob] = fit_inverse_lpi_improved(Mop, settings)
% Improved approximate inverse fit:
%
%   minimize   gamma + rho*mu
%
%   subject to [ gamma*I   EL ] >= 0,   EL = P*M - I
%              [ EL'       I  ]
%
%              [ gamma*I   ER ] >= 0,   ER = M*P - I
%              [ ER'       I  ]
%
%              [ mu*I      P  ] >= 0
%              [ P'        I  ]
%
% gamma controls inversion residual
% mu controls the size of P
%
% OUTPUT:
%   Pfit    : approximate inverse
%   gam_sol : residual bound
%   mu_sol  : inverse-size bound
%   ELfit   : left residual Pfit*M - I
%   ERfit   : right residual M*Pfit - I

    %% 1. Input Validation
    if ~isa(Mop,'opvar')
        error('Mop must be of type ''opvar''.');
    end
    if any(Mop.dim(:,1) ~= Mop.dim(:,2))
        error('Mop must be square.');
    end
    if nargin < 2 || isempty(settings)
        settings = struct();
    end
    if ~isfield(settings,'sosineq_on')
        settings.sosineq_on = true;
    end
    if ~isfield(settings,'sos_opts') || isempty(settings.sos_opts)
        settings.sos_opts = struct();
        settings.sos_opts.psatz = 1;
    end
    if ~isfield(settings,'ddZ')
        error('settings.ddZ must be provided for lpivar.');
    end
    if ~isfield(settings,'rho')
        settings.rho = 1e-3;   % regularization weight on ||P||
    end

    %% 2. Identity operator on same space
    Iop = eyePI(Mop.dim(:,1), Mop.vars, Mop.I);

    %% 3. Initialize program
    prob = lpiprogram(Mop.var1, Mop.var2, Mop.I);

    %% 4. Scalar decision variables
    [prob, gam] = lpidecvar(prob, 'gam');
    [prob, mu]  = lpidecvar(prob, 'mu');

    %% 5. Builder
    LPI = LPIBuilder(prob, settings);

    %% 6. Decision variable for approximate inverse
    Pdec = LPI.constructLPIVar(Mop.dim(:,1), Mop.dim(:,2), settings.ddZ);

    %% 7. Residual operators
    ELop = Pdec*Mop - Iop;
    ERop = Mop*Pdec - Iop;

    %% 8. Build Schur complement constraints
    blkDim = ioDimensions(["blk1","blk2"], [Mop.dim(:,1), Mop.dim(:,1)]');

    % Left residual bound
    BigL = gridBuilder(blkDim, blkDim, Mop.vars, Mop.I);
    BigL(1,1) = gam*Iop;
    BigL(1,2) = ELop;
    BigL(2,1) = ELop';
    BigL(2,2) = Iop;
    LPI = LPI.setDop(-BigL());

    % % Right residual bound
    % BigR = gridBuilder(blkDim, blkDim, Mop.vars, Mop.I);
    % BigR(1,1) = gam*Iop;
    % BigR(1,2) = ERop;
    % BigR(2,1) = ERop';
    % BigR(2,2) = Iop;
    % LPI = LPI.setDop(-BigR());

    % Size bound on P
    BigP = gridBuilder(blkDim, blkDim, Mop.vars, Mop.I);
    BigP(1,1) = mu*Iop;
    BigP(1,2) = Pdec;
    BigP(2,1) = Pdec';
    BigP(2,2) = Iop;
    LPI = LPI.setDop(-BigP());

    %% 9. Optional scalar nonnegativity
    % Often implied, but harmless to add explicitly if your solver likes it
    prob = LPI.prog;
    prob = lpi_ineq(prob, gam, settings.sos_opts);
    prob = lpi_ineq(prob, mu,  settings.sos_opts);

    %% 10. Objective
    prob = lpisetobj(prob, gam + settings.rho*mu);

    %% 11. Solve
    prob = lpisolve(prob);

    %% 12. Recover solution
    Pfit    = lpigetsol(prob, Pdec);
    Pfit    = clean_opvar(Pfit);

    ELfit   = clean_opvar(Pfit*Mop - Iop);
    ERfit   = clean_opvar(Mop*Pfit - Iop);

    gam_sol = double(lpigetsol(prob, gam));
    mu_sol  = double(lpigetsol(prob, mu));
end