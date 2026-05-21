classdef (Abstract) Device
    % DEVICE Base class for all circuit elements.
    % The class owns parsed netlist identity and exposes the native-solver
    % protocol used by DC operating point, AC small-signal, DC sweep, and
    % fixed-step transient analyses.
    properties (Abstract, Constant)
        Kind
    end

    properties (SetAccess = protected)
        Name (1,1) string
        NodeTokens (1,:) string
        Parameters struct
        LineNumber (1,1) double
        RawTokens cell
    end

    methods
        function obj = Device(name, nodeTokens, parameters, lineNumber, rawTokens)
            obj.Name = string(name);
            obj.NodeTokens = string(nodeTokens);
            obj.Parameters = parameters;
            obj.LineNumber = double(lineNumber);
            obj.RawTokens = rawTokens;
        end

        function ids = nodeIds(obj)
            ids = zeros(1, numel(obj.NodeTokens));
            for idx = 1:numel(obj.NodeTokens)
                ids(idx) = str2double(obj.NodeTokens(idx));
                if isnan(ids(idx))
                    error('spice:model:Device:NonNumericNode', ...
                        'Node token "%s" is not numeric. v1 requires numeric node labels.', obj.NodeTokens(idx));
                end
            end
        end

        function out = toStruct(obj)
            out = struct( ...
                'name', obj.Name, ...
                'kind', obj.Kind, ...
                'nodeTokens', obj.NodeTokens, ...
                'params', obj.Parameters, ...
                'rawTokens', {obj.RawTokens}, ...
                'lineNumber', obj.LineNumber);
        end

        function tf = supportsNativeAnalysis(~, ~, ~)
            tf = false;
        end

        function names = branchVariableNames(~, ~)
            names = string.empty(1, 0);
        end

        function initialGuessContribution(~, ~, ~, ~, ~)
        end

        function state = evaluateOperatingPoint(~, ~, ~, ~)
            state = struct();
        end

        function stampDcLinearized(obj, assembler, nativeCircuit, ~, ~)
            obj.stampDc(assembler, nativeCircuit);
        end

        function stampAcLinearized(obj, assembler, nativeCircuit, ~, context)
            obj.stampAc(assembler, nativeCircuit, context.Omega);
        end

        function stampTransientLinearized(obj, assembler, nativeCircuit, ~, context)
            obj.stampTransient(assembler, nativeCircuit, [], struct('time', context.Time, 'dt', context.TimeStep, 'method', context.Options.TransientMethod));
        end

        function updateDynamicState(~, ~, ~, ~, ~, ~)
        end

        function stampDc(~, ~, ~)
            error('spice:model:Device:NativeDcUnsupported', 'Device does not support native DC stamping.');
        end

        function stampAc(~, ~, ~, ~)
            error('spice:model:Device:NativeAcUnsupported', 'Device does not support native AC stamping.');
        end

        function stampTransient(~, ~, ~, ~, ~)
            error('spice:model:Device:NativeTransientUnsupported', 'Device does not support native transient stamping.');
        end

        function current = currentForProbe(~, ~, ~, ~, ~, ~)
            error('spice:model:Device:NativeCurrentUnsupported', 'Device does not support native current extraction.');
            current = [];
        end
    end

    methods (Abstract)
        exportToLegacy(obj, collector)
    end
end
