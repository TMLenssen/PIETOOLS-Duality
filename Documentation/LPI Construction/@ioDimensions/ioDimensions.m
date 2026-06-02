classdef ioDimensions < handle
    properties
        variableList   % cell array of structs: name (string), dimensions (1x2)
    end

    methods
        function obj = ioDimensions(varNames, dimensions)
            obj.variableList = {};

            if nargin == 0
                return;
            end

            validateattributes(varNames, {'string'}, {'vector'});
            n = numel(varNames);

            validateattributes(dimensions, {'numeric'}, {'2d','ncols',2,'integer','nonnegative'});
            if size(dimensions,1) ~= n
                error("ioDimensions:Constructor:SizeMismatch", ...
                    "dimensions must be an Nx2 matrix where N = numel(varNames).");
            end

            for i = 1:n
                obj.add(varNames(i), dimensions(i,:));
            end
        end

        function add(obj, varName, dimensions)
            validateattributes(varName, {'string'}, {'scalartext'});
            validateattributes(dimensions, {'numeric'}, {'vector','numel',2,'integer','nonnegative'});

            varName = string(varName);
            dimensions = dimensions(:).';

            [tf, idx] = obj.exists(varName);
            if tf
                existingDims = obj.variableList{idx}.dimensions;
                if isequal(existingDims, dimensions)
                    warning('ioDimensions:DuplicateVariable', ...
                        "Variable '%s' with dimensions [%d, %d] already exists at index %d. Not adding duplicate.", ...
                        varName, dimensions(1), dimensions(2), idx);
                    return;
                else
                    error('ioDimensions:DimensionMismatch', ...
                        "Variable '%s' already exists with dimensions [%d, %d], but new dimensions are [%d, %d].", ...
                        varName, existingDims(1), existingDims(2), dimensions(1), dimensions(2));
                end
            end

            obj.variableList{end+1} = struct('name', varName, 'dimensions', dimensions);

            fprintf("Added variable '%s' with dimensions [%d, %d] at index %d\n", ...
                varName, dimensions(1), dimensions(2), numel(obj.variableList));
        end
        function dim = getDimensions(obj)
            dim = zeros(1,2);
            for i = 1:obj.count()
                dim = dim + obj.variableList{i}.dimensions;
            end
        end
        function [tf, index] = exists(obj, varName)
            if ~(isstring(varName))
                error('ioDimensions:Exists:InvalidName', 'varName must be a string.');
            end
            varName = string(varName);

            tf = false;
            index = 0;
            for i = 1:numel(obj.variableList)
                if obj.variableList{i}.name == varName
                    tf = true;
                    index = i;
                    return;
                end
            end
        end

        function idx = indexOf(obj, varName)
            if ~(isstring(varName))
                error('ioDimensions:indexOf:InvalidName', 'varName must be a string.');
            end
            % Return index for a name; error if not found
            [tf, idx] = obj.exists(varName);
            if ~tf
                error('ioDimensions:IndexOf:NotFound', ...
                    "Variable '%s' not found in list.", string(varName));
            end
        end

        function dims = dimension(obj, identifier)
            if nargin ~= 2
                error('ioDimensions:Dimension:InvalidInputs', ...
                    'Expected exactly one input: variable name or index.');
            end

            if isstring(identifier) || ischar(identifier)
                idx = obj.indexOf(identifier);
            elseif isnumeric(identifier) && isscalar(identifier)
                idx = identifier;
                if idx < 1 || idx > obj.count()
                    error('ioDimensions:Dimension:IndexOutOfBounds', ...
                        'Index %d is out of bounds. Valid range: 1 to %d', idx, obj.count());
                end
            else
                error('ioDimensions:Dimension:InvalidIdentifier', ...
                    'Input must be a variable name (string/char) or a scalar numeric index.');
            end

            dims = obj.variableList{idx}.dimensions.'; % 2x1
        end

        function n = count(obj)
            n = numel(obj.variableList);
        end

        function clear(obj)
            obj.variableList = {};
            disp('Variable list cleared');
        end

        function display(obj)
            fprintf('\nCurrent Variable List:\n');
            fprintf('%-10s %-15s %s\n', 'Index', 'Name', 'Dimensions [R, L2]');
            fprintf('%s\n', repmat('-', 40, 1));

            if isempty(obj.variableList)
                fprintf('No variables in list\n\n');
                return;
            end

            for i = 1:numel(obj.variableList)
                c = obj.variableList{i};
                fprintf('%-10d %-15s [%d, %d]\n', i, c.name, c.dimensions(1), c.dimensions(2));
            end
            fprintf('\n');
        end
    end
end
