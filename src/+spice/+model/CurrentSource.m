classdef CurrentSource < spice.model.IndependentSource
    % CURRENTSOURCE Independent current source with native RHS injection.
    properties (Constant)
        Kind = "currentSource"
        LegacySourceKind = "currentSource"
    end

    methods
        function obj = CurrentSource(name, nodeTokens, waveformParams, lineNumber, rawTokens)
            obj@spice.model.IndependentSource(name, nodeTokens, waveformParams, lineNumber, rawTokens);
        end

        function tf = supportsNativeAnalysis(~, analysisType, ~)
            tf = any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"]);
        end

        function initialGuessContribution(obj, assembler, nativeCircuit, context, ~)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            if string(context.AnalysisType) == "trans"
                value = spice.analysis.native.sourceValueAtTime(obj.Parameters, context.Time);
            else
                value = context.overrideDcValue(obj.Name, obj.Parameters.dcValue);
            end
            assembler.addCurrentSource(n1, n2, value);
        end

        function state = evaluateOperatingPoint(obj, ~, ~, context)
            state = struct('dcValue', context.overrideDcValue(obj.Name, obj.Parameters.dcValue));
        end

        function stampDc(obj, assembler, nativeCircuit)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addCurrentSource(n1, n2, obj.Parameters.dcValue);
        end

        function stampAc(obj, assembler, nativeCircuit, ~)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addCurrentSource(n1, n2, spice.analysis.native.sourcePhasor(obj.Parameters));
        end

        function stampTransient(obj, assembler, nativeCircuit, ~, stepState)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addCurrentSource(n1, n2, spice.analysis.native.sourceValueAtTime(obj.Parameters, stepState.time));
        end

        function stampDcLinearized(obj, assembler, nativeCircuit, state, ~)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addCurrentSource(n1, n2, state.dcValue);
        end

        function current = currentForProbe(obj, analysisType, nativeCircuit, ~, axisValues, portName)
            switch string(analysisType)
                case "dc"
                    current = obj.Parameters.dcValue;
                case "dcsweep"
                    if nativeCircuit.Circuit.Analysis.Parameters.deviceName == obj.Name
                        current = axisValues;
                    else
                        current = repmat(obj.Parameters.dcValue, 1, numel(axisValues));
                    end
                case "ac"
                    current = repmat(spice.analysis.native.sourcePhasor(obj.Parameters), 1, numel(axisValues));
                case {"trans", "shoot"}
                    current = zeros(1, numel(axisValues));
                    for idx = 1:numel(axisValues)
                        current(idx) = spice.analysis.native.sourceValueAtTime(obj.Parameters, axisValues(idx));
                    end
                otherwise
                    error('spice:model:CurrentSource:UnsupportedCurrentProbe', ...
                        'Unsupported analysis %s for current source.', analysisType);
            end
            if string(portName) == "-"
                current = -current;
            end
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            params = spice.model.IndependentSource.parseWaveform(tokens, lineNumber);
            obj = spice.model.CurrentSource(tokens{1}, string(tokens(2:3)), params, lineNumber, tokens);
        end
    end
end
