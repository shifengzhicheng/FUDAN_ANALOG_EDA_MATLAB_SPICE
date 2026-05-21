classdef VoltageSource < spice.model.IndependentSource
    % VOLTAGESOURCE Independent voltage source with native MNA branch stamping.
    properties (Constant)
        Kind = "voltageSource"
        LegacySourceKind = "voltageSource"
    end

    methods
        function obj = VoltageSource(name, nodeTokens, waveformParams, lineNumber, rawTokens)
            obj@spice.model.IndependentSource(name, nodeTokens, waveformParams, lineNumber, rawTokens);
        end

        function tf = supportsNativeAnalysis(~, analysisType, ~)
            tf = any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"]);
        end

        function names = branchVariableNames(obj, analysisType)
            if any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"])
                names = obj.Name;
            else
                names = string.empty(1, 0);
            end
        end

        function initialGuessContribution(obj, assembler, nativeCircuit, context, ~)
            if string(context.AnalysisType) == "trans"
                obj.stampSource(assembler, nativeCircuit, spice.analysis.native.sourceValueAtTime(obj.Parameters, context.Time));
            else
                obj.stampDcLinearized(assembler, nativeCircuit, obj.evaluateOperatingPoint(nativeCircuit, [], context), context);
            end
        end

        function state = evaluateOperatingPoint(obj, ~, ~, context)
            state = struct('dcValue', context.overrideDcValue(obj.Name, obj.Parameters.dcValue));
        end

        function stampDc(obj, assembler, nativeCircuit)
            obj.stampSource(assembler, nativeCircuit, obj.Parameters.dcValue);
        end

        function stampAc(obj, assembler, nativeCircuit, ~)
            obj.stampSource(assembler, nativeCircuit, spice.analysis.native.sourcePhasor(obj.Parameters));
        end

        function stampTransient(obj, assembler, nativeCircuit, ~, stepState)
            obj.stampSource(assembler, nativeCircuit, spice.analysis.native.sourceValueAtTime(obj.Parameters, stepState.time));
        end

        function stampDcLinearized(obj, assembler, nativeCircuit, state, ~)
            obj.stampSource(assembler, nativeCircuit, state.dcValue);
        end

        function current = currentForProbe(obj, ~, nativeCircuit, solutionMatrix, ~, portName)
            current = nativeCircuit.branchCurrent(solutionMatrix, nativeCircuit.branchVarIndex(obj.Name));
            if string(portName) == "-"
                current = -current;
            end
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            params = spice.model.IndependentSource.parseWaveform(tokens, lineNumber);
            obj = spice.model.VoltageSource(tokens{1}, string(tokens(2:3)), params, lineNumber, tokens);
        end
    end

    methods (Access = private)
        function stampSource(obj, assembler, nativeCircuit, sourceValue)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            branchIndex = nativeCircuit.branchVarIndex(obj.Name);
            assembler.addBranchKcl(n1, n2, branchIndex);
            assembler.addBranchEquation(n1, n2, branchIndex, 0, sourceValue);
        end
    end
end
