classdef Resistor < spice.model.TwoTerminalValueDevice
    % RESISTOR Two-terminal linear resistor with native DC/AC/trans support.
    properties (Constant)
        Kind = "resistor"
        LegacyPassiveKind = "R"
    end

    methods
        function obj = Resistor(name, nodeTokens, value, lineNumber, rawTokens)
            obj@spice.model.TwoTerminalValueDevice(name, nodeTokens, value, lineNumber, rawTokens);
        end

        function tf = supportsNativeAnalysis(~, analysisType, ~)
            tf = any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"]);
        end

        function initialGuessContribution(obj, assembler, nativeCircuit, ~, ~)
            obj.stampDc(assembler, nativeCircuit);
        end

        function state = evaluateOperatingPoint(obj, nativeCircuit, solution, ~)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            voltageDrop = nativeCircuit.nodeVoltage(solution, n1) - nativeCircuit.nodeVoltage(solution, n2);
            state = struct('conductance', 1 / obj.Parameters.value, 'current', voltageDrop / obj.Parameters.value);
        end

        function stampDc(obj, assembler, nativeCircuit)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addConductance(n1, n2, 1 / obj.Parameters.value);
        end

        function stampAc(obj, assembler, nativeCircuit, ~)
            obj.stampDc(assembler, nativeCircuit);
        end

        function stampTransient(obj, assembler, nativeCircuit, ~, ~)
            obj.stampDc(assembler, nativeCircuit);
        end

        function current = currentForProbe(obj, ~, nativeCircuit, solutionMatrix, ~, portName)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            voltageDrop = nativeCircuit.nodeVoltage(solutionMatrix, n1) - nativeCircuit.nodeVoltage(solutionMatrix, n2);
            current = voltageDrop / obj.Parameters.value;
            if string(portName) == "-"
                current = -current;
            end
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            if numel(tokens) < 4
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 4 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.Resistor(tokens{1}, string(tokens(2:3)), spice.util.parseNumericWithSuffix(tokens{4}), lineNumber, tokens);
        end
    end
end
