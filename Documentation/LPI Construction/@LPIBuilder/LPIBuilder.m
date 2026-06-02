classdef LPIBuilder < handle
    properties (Access = private)
        settings
    end

    properties (GetAccess = public, SetAccess = private)                    
        prog
    end

    methods
        function obj = LPIBuilder(prog, settings)
            obj.prog     = prog;
            obj.settings = settings;
        end

        function obj = setDop(obj, Dop)
            disp('- Enforcing the Negativity Constraint...');
            if obj.settings.sosineq_on
                disp('  - Using lpi_ineq...');
                obj.prog = lpi_ineq(obj.prog, -Dop, obj.settings.sos_opts);
                return;
            end

            disp('  - Using an Equality constraint...');
            [obj.prog, De1op] = poslpivar(obj.prog, Dop.dim, obj.settings.dd2, obj.settings.options2);

            if obj.getSettingDefault('override2', 0) ~= 1
                [obj.prog, De2op] = poslpivar(obj.prog, Dop.dim, obj.settings.dd3, obj.settings.options3);
                Deop = De1op + De2op;
            else
                Deop = De1op;
            end

            % Dop = -Deop enforced via equality
            obj.prog = lpi_eq(obj.prog, Deop + Dop, 'symmetric');
        end

        function [lyapOp, R] = constructLyapOp(obj, mappingOp, coercive)
            disp('- Declaring Positive Lyapunov Operator variables...');

            [obj.prog, Rop] = poslpivar(obj.prog, mappingOp.dim, obj.settings.dd1, obj.settings.options1);

            if obj.getSettingDefault('override1', 0) ~= 1
                [obj.prog, P2] = poslpivar(obj.prog, mappingOp.dim, obj.settings.dd12, obj.settings.options12);
                R = Rop + P2;
            else
                R = Rop;
            end
            
            if coercive
                lyapOp = R;
            else
                % Also declare an indefinite operator Qop=Pop*Top so that Rop = Top'*Qop.   % DJ, 01/06/2025
                Qdeg = get_lpivar_degs(R, mappingOp);
                [obj.prog, lyapOp] = lpivar(obj.prog,mappingOp.dim,Qdeg);
                obj.prog = lpi_eq(obj.prog, mappingOp'*lyapOp-R);
            end
        end

        function decvar = constructLPIVar(obj, outputDim, inputDim, deg)
            if nargin < 4 || isempty(deg)
                deg = obj.settings.ddZ;
            end
            [obj.prog, decvar] = lpivar(obj.prog, [outputDim, inputDim], deg);
        end
        function prog = setInequality(obj, Dop, opts)
            disp('  - Using lpi_ineq...');
            obj.prog = lpi_ineq(obj.prog, Dop, opts);
            prog = obj.prog;
        end
    end



    methods (Access = private)
        function val = getSettingDefault(obj, field, default)
            if isfield(obj.settings, field)
                val = obj.settings.(field);
            else
                val = default;
            end
        end
    end
end
