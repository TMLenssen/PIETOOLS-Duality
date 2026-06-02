function prog = PIETOOLS_Solve_LPI(prog, Dop, settings)
%% 1. Input Validation & Default Settings
    if nargin < 3
        error('PIETOOLS_Solve_LPI requires 3 inputs: prog, Dop, and settings.');
    end
disp('- Enforcing the Negativity Constraint...');
if settings.sosineq_on
    disp('  - Using lpi_ineq...');
    prog = lpi_ineq(prog,-Dop,settings.opts);
else
    disp('  - Using an Equality constraint...');
    [prog, De1op] = poslpivar(prog, Dop.dim, settings.dd2, settings.options2);

    if settings.override2~=1
        [prog, De2op] = poslpivar(prog, Dop.dim, settings.dd3, settings.options3);
        Deop=De1op+De2op;
    else
        Deop=De1op;
    end
    prog = lpi_eq(prog,Deop+Dop,'symmetric'); %Dop=-Deop
end

%solving the sos program
disp('- Solving the LPI using the specified SDP solver...');
prog = lpisolve(prog,settings.sos_opts);
end
