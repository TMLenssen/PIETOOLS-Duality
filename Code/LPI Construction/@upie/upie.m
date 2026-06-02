classdef (InferiorClasses={?opvar2d,?dpvar,?polynomial}) upie
    % upie is a class of objects used to describe uncertain PIE systems in
    % PIETOOLS. These classes have been constructed with the help of
    % chatbots.

    properties
        dom  = zeros(1,2);
        vars = polynomial(zeros(1,2));

        T;
        A;
        Bd;
        Bw;
        Bu;

        Cd;
        Dd;
        Ddw;
        Ddu;

        Cz;
        Dzd;
        Dzw;
        Dzu;

        Cy;
        Dyd;
        Dyw;
        Dyu;

        % "misc" field to add any other stuff relevant to the PIE.
        misc;
    end

    properties (Hidden)
        % The tables with standardized information on each of the components
        x_tab  = zeros(0,2);
        u_tab  = zeros(0,2);
        w_tab  = zeros(0,2);
        wd_tab = zeros(0,2);
        y_tab  = zeros(0,2);
        z_tab  = zeros(0,2);
    end

    properties (Dependent)
        % Spatial dimension of the PIE.
        dim = 0;

        nx  = 0;
        nwd = 0;
        nw  = 0;
        nu  = 0;
        nzd = 0;
        nz  = 0;
        ny  = 0;
    end

    methods
        function obj = upie(varargin)
            %UPIE Construct an instance of this class

            if nargin==1
                if ischar(varargin{1})
                    if nargout==0
                        assignin('caller', varargin{1}, upie());
                    end
                elseif isa(varargin{1},'upie')
                    obj = varargin{1};
                elseif isa(varargin{1},'struct')
                    obj = upie();
                    % List of expected fields to copy
                    fields = {'vars','dom','T','A','Bd','Bw','Bu','Cd','Dd','Ddw','Ddu', ...
                              'Cz','Dzd','Dzw','Dzu','Cy','Dyd','Dyw','Dyu', ...
                              'x_tab','u_tab','wd_tab','w_tab','y_tab','z_tab','misc'};
                    for k = 1:length(fields)
                        if isfield(varargin{1}, fields{k})
                            obj.(fields{k}) = varargin{1}.(fields{k});
                        end
                    end
                else
                    error("Input must be strings, a struct, or a upie.");
                end

            elseif nargin > 1
                for i = 1:nargin
                    if ischar(varargin{i})
                        if nargout==0
                            assignin('caller', varargin{i}, upie());
                        end
                    else
                        error("Input must be strings");
                    end
                end
            end

            % -------------------------------------------------------------
            % VERIFY DIMENSIONS (Robust to partial definition)
            % -------------------------------------------------------------
            % Trigger get methods (they ignore empty/un-dimensioned ops)
            try
                obj.nx;
                obj.nwd;
                obj.nw;
                obj.nu;
                obj.nzd;
                obj.nz;
                obj.ny;
            catch ME
                throwAsCaller(ME);
            end

            % -------------------------------------------------------------
            % FILL EMPTY OPERATORS (T through Dyu) AND SET .dim
            % -------------------------------------------------------------
            obj = obj.postprocess_constructor();
        end

        % -----------------------------------------------------------------
        % ROBUST GET METHODS
        % -----------------------------------------------------------------

        function dim_val = get.dim(obj)
            if size(obj.vars,1) == size(obj.dom,1)
                dim_val = size(obj.vars,1);
            else
                dim_val = nan;
            end
        end

        function nx_val = get.nx(obj)
            % nx: dimension of the fundamental state x.
            dims = [];

            % Only use operators whose dim is set (nonzero)
            if obj.has_dim(obj.T),  dims = [dims, obj.T.dim(:,1), obj.T.dim(:,2)]; end
            if obj.has_dim(obj.A),  dims = [dims, obj.A.dim(:,1), obj.A.dim(:,2)]; end

            if obj.has_dim(obj.Bd), dims = [dims, obj.Bd.dim(:,1)]; end
            if obj.has_dim(obj.Bw), dims = [dims, obj.Bw.dim(:,1)]; end
            if obj.has_dim(obj.Bu), dims = [dims, obj.Bu.dim(:,1)]; end

            if obj.has_dim(obj.Cd), dims = [dims, obj.Cd.dim(:,2)]; end
            if obj.has_dim(obj.Cz), dims = [dims, obj.Cz.dim(:,2)]; end
            if obj.has_dim(obj.Cy), dims = [dims, obj.Cy.dim(:,2)]; end

            if isempty(dims)
                nx_val = [0; 0];
            else
                ref_dim = dims(:,1);
                if any(any(dims ~= ref_dim))
                    error('Dimensions of the fundamental state (x) do not match across supplied operators (T, A, B*, C*).');
                end
                nx_val = ref_dim;
            end
        end

        function nwd_val = get.nwd(obj)
            % nwd: dimension of the disturbance input wd.
            dims = [];

            if obj.has_dim(obj.Bd),  dims = [dims, obj.Bd.dim(:,2)];  end
            if obj.has_dim(obj.Dd),  dims = [dims, obj.Dd.dim(:,2)];  end
            if obj.has_dim(obj.Dzd), dims = [dims, obj.Dzd.dim(:,2)]; end
            if obj.has_dim(obj.Dyd), dims = [dims, obj.Dyd.dim(:,2)]; end

            if isempty(dims)
                nwd_val = [0; 0];
            else
                ref_dim = dims(:,1);
                if any(any(dims ~= ref_dim))
                    error('Dimensions of the uncertain input (wd) do not match across supplied operators.');
                end
                nwd_val = ref_dim;
            end
        end

        function nw_val = get.nw(obj)
            % nw: dimension of the exogenous input w.
            dims = [];

            if obj.has_dim(obj.Bw),  dims = [dims, obj.Bw.dim(:,2)];  end
            if obj.has_dim(obj.Ddw), dims = [dims, obj.Ddw.dim(:,2)]; end
            if obj.has_dim(obj.Dzw), dims = [dims, obj.Dzw.dim(:,2)]; end
            if obj.has_dim(obj.Dyw), dims = [dims, obj.Dyw.dim(:,2)]; end

            if isempty(dims)
                nw_val = [0; 0];
            else
                ref_dim = dims(:,1);
                if any(any(dims ~= ref_dim))
                    error('Dimensions of the exogenous input (w) do not match across supplied operators.');
                end
                nw_val = ref_dim;
            end
        end

        function nu_val = get.nu(obj)
            % nu: dimension of the control input u.
            dims = [];

            if obj.has_dim(obj.Bu),  dims = [dims, obj.Bu.dim(:,2)];  end
            if obj.has_dim(obj.Ddu), dims = [dims, obj.Ddu.dim(:,2)]; end
            if obj.has_dim(obj.Dzu), dims = [dims, obj.Dzu.dim(:,2)]; end
            if obj.has_dim(obj.Dyu), dims = [dims, obj.Dyu.dim(:,2)]; end

            if isempty(dims)
                nu_val = [0; 0];
            else
                ref_dim = dims(:,1);
                if any(any(dims ~= ref_dim))
                    error('Dimensions of the actuator input (u) do not match across supplied operators.');
                end
                nu_val = ref_dim;
            end
        end

        function nzd_val = get.nzd(obj)
            % nzd: dimension of the uncertain output zd.
            dims = [];

            if obj.has_dim(obj.Cd),  dims = [dims, obj.Cd.dim(:,1)];  end
            if obj.has_dim(obj.Dd),  dims = [dims, obj.Dd.dim(:,1)];  end
            if obj.has_dim(obj.Ddw), dims = [dims, obj.Ddw.dim(:,1)]; end
            if obj.has_dim(obj.Ddu), dims = [dims, obj.Ddu.dim(:,1)]; end

            if isempty(dims)
                nzd_val = [0; 0];
            else
                ref_dim = dims(:,1);
                if any(any(dims ~= ref_dim))
                    error('Dimensions of the uncertain output (zd) do not match across supplied operators.');
                end
                nzd_val = ref_dim;
            end
        end

        function nz_val = get.nz(obj)
            % nz: dimension of the regulated output z.
            dims = [];

            if obj.has_dim(obj.Cz),  dims = [dims, obj.Cz.dim(:,1)];  end
            if obj.has_dim(obj.Dzd), dims = [dims, obj.Dzd.dim(:,1)]; end
            if obj.has_dim(obj.Dzw), dims = [dims, obj.Dzw.dim(:,1)]; end
            if obj.has_dim(obj.Dzu), dims = [dims, obj.Dzu.dim(:,1)]; end

            if isempty(dims)
                nz_val = [0; 0];
            else
                ref_dim = dims(:,1);
                if any(any(dims ~= ref_dim))
                    error('Dimensions of the regulated output (z) do not match across supplied operators.');
                end
                nz_val = ref_dim;
            end
        end

        function ny_val = get.ny(obj)
            % ny: dimension of the measured output y.
            dims = [];

            if obj.has_dim(obj.Cy),  dims = [dims, obj.Cy.dim(:,1)];  end
            if obj.has_dim(obj.Dyd), dims = [dims, obj.Dyd.dim(:,1)]; end
            if obj.has_dim(obj.Dyw), dims = [dims, obj.Dyw.dim(:,1)]; end
            if obj.has_dim(obj.Dyu), dims = [dims, obj.Dyu.dim(:,1)]; end

            if isempty(dims)
                ny_val = [0; 0];
            else
                ref_dim = dims(:,1);
                if any(any(dims ~= ref_dim))
                    error('Dimensions of the observed output (y) do not match across supplied operators.');
                end
                ny_val = ref_dim;
            end
        end

        function disp(obj)
            % DISP Custom display for the upie object

            fmt = @(x) sprintf('[%d;%d]', x(1), x(2));

            fprintf('  System Dimensions (R; L2):\n');
            fprintf('    nx:  %-10s  nzd: %-10s  nz:  %-10s  ny:  %-10s\n', ...
                fmt(obj.nx), fmt(obj.nzd), fmt(obj.nz), fmt(obj.ny));
            fprintf('    nwd: %-10s  nw:  %-10s  nu:  %-10s\n', ...
                fmt(obj.nwd), fmt(obj.nw), fmt(obj.nu));
            fprintf('\n');

            opType = 'opvar';
            if isa(obj.T,'opvar2d') || isa(obj.A,'opvar2d')
                opType = 'opvar2d';
            end

            szStr = @(r,c) sprintf('(%d,%d)x(%d,%d)', r(1), r(2), c(1), c(2));

            fprintf('  Operators (%s):\n', opType);

            fprintf('     T: %-16s\n', szStr(obj.nx, obj.nx));

            fprintf('     A: %-16s  Bd: %-16s  Bw: %-16s  Bu: %-16s\n', ...
                szStr(obj.nx, obj.nx), szStr(obj.nx, obj.nwd), ...
                szStr(obj.nx, obj.nw), szStr(obj.nx, obj.nu));

            fprintf('    Cd: %-16s  Dd: %-16s Ddw: %-16s Ddu: %-16s\n', ...
                szStr(obj.nzd, obj.nx), szStr(obj.nzd, obj.nwd), ...
                szStr(obj.nzd, obj.nw), szStr(obj.nzd, obj.nu));

            fprintf('    Cz: %-16s Dzd: %-16s Dzw: %-16s Dzu: %-16s\n', ...
                szStr(obj.nz, obj.nx), szStr(obj.nz, obj.nwd), ...
                szStr(obj.nz, obj.nw), szStr(obj.nz, obj.nu));

            fprintf('    Cy: %-16s Dyd: %-16s Dyw: %-16s Dyu: %-16s\n', ...
                szStr(obj.ny, obj.nx), szStr(obj.ny, obj.nwd), ...
                szStr(obj.ny, obj.nw), szStr(obj.ny, obj.nu));

            if ~isempty(obj.misc)
                fprintf('\n  Misc:\n');
                if isstruct(obj.misc)
                    f = fieldnames(obj.misc);
                    for k = 1:length(f)
                        val = obj.misc.(f{k});
                        fprintf('    .%s: [%dx%d %s]\n', f{k}, size(val,1), size(val,2), class(val));
                    end
                else
                    fprintf('    [%dx%d %s]\n', size(obj.misc,1), size(obj.misc,2), class(obj.misc));
                end
            end
            fprintf('\n');
        end
    end

    methods (Access=private)
        function tf = has_dim(obj, op)
            %#ok<INUSD>
            tf = ~isempty(op);
            if ~tf
                return
            end
            try
                d = op.dim;
                tf = ~isempty(d) && ~all(d(:) == 0);
            catch
                tf = false;
            end
        end

        function obj = postprocess_constructor(obj)
            % Fill empty operators T..Dyu with opvar() and set dims consistently.
            %
            % Enforces:
            %   obj.(name).dim = [outDim, inDim]
            % using the dependent dims:
            %   nx,nz,ny,nzd,nwd,nw,nu

            % Obtain current inferred dimensions (getters ignore unset dims)
            nx  = obj.nx;
            nz  = obj.nz;
            ny  = obj.ny;
            nzd = obj.nzd;
            nwd = obj.nwd;
            nw  = obj.nw;
            nu  = obj.nu;

            names = {'T','A','Bd','Bw','Bu','Cd','Dd','Ddw','Ddu', ...
                     'Cz','Dzd','Dzw','Dzu','Cy','Dyd','Dyw','Dyu'};

            outDims = {nx,  nx,  nx,  nx,  nx,  nzd, nzd, nzd, nzd, ...
                       nz,  nz,  nz,  nz,  ny,  ny,  ny,  ny};

            inDims  = {nx,  nx,  nwd, nw,  nu,  nx,  nwd, nw,  nu,  ...
                       nx,  nwd, nw,  nu,  nx,  nwd, nw,  nu};

            for k = 1:numel(names)
                nm = names{k};

                % Fill empties
                if isempty(obj.(nm))
                    obj.(nm) = opvar();
                end

                if ~isprop(obj.(nm),'dim')
                    error('Operator "%s" does not have a .dim property.', nm);
                end

                desiredDim = [outDims{k}, inDims{k}];
                currentDim = obj.(nm).dim;
                % If dim is unset (or all zeros), set it; else verify it
                if isempty(currentDim) || all(currentDim(:) == 0)
                    obj.(nm).dim  = desiredDim;
                    obj.(nm).I    = obj.dom;
                    obj.(nm).var1 = obj.vars(:,1);
                    obj.(nm).var2 = obj.vars(:,2);
                else
                    if ~isequal(currentDim, desiredDim)
                        error('Operator "%s" has dim %s but expected %s.', ...
                              nm, mat2str(currentDim), mat2str(desiredDim));
                    end
                end
            end
        end
    end
end
