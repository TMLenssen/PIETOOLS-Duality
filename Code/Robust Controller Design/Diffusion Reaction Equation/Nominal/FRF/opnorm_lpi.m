function [nrm, gam_opt, prob] = opnorm_lpi(P, settings)
% Upper bound on induced operator norm of opvar P using
%   min gamma
%   s.t. gamma*I - P'*P >= 0
%
% INPUT:
%   P     : opvar
%   psatz : optional, default 1
%
% OUTPUT:
%   nrm     : sqrt(gamma_opt)
%   gam_opt : optimal gamma
%   prob    : solved LPI program

    if nargin < 2
        settings = lpisettings("light");
    end

    prob = lpiprogram(P.vars, P.I);

    [prob, gam] = lpidecvar(prob, 'gam');

    Dop = -gam - P'*P;
    % Enforce gamma*I - P'*P >= 0
    prob = setDop(prob, -Dop, settings);

    % Minimize gamma
    prob = lpisetobj(prob, gam);

    % Solve
    prob = lpisolve(prob);

    gam_opt = double(lpigetsol(prob, gam));
    nrm = sqrt(gam_opt);
end
function prog = setDop(prog, Dop, settings)
disp('- Enforcing the Negativity Constraint...');
if settings.sosineq_on
    disp('  - Using lpi_ineq...');
    prog = lpi_ineq(prog, -Dop, settings.sos_opts);
    return;
end

disp('  - Using an Equality constraint...');
[prog, De1op] = poslpivar(prog, Dop.dim, settings.dd2, settings.options2);

if settings.override2 ~= 1
    [prog, De2op] = poslpivar(prog, Dop.dim, settings.dd3, settings.options3);
    Deop = De1op + De2op;
else
    Deop = De1op;
end

% Dop = -Deop enforced via equality
prog = lpi_eq(prog, Deop + Dop, 'symmetric');
end