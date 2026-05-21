classdef Diode < spice.model.Device
    % DIODE Nonlinear diode with native Newton linearization support.
    properties (Constant)
        Kind = "diode"
    end

    methods
        function obj = Diode(name, nodeTokens, modelId, lineNumber, rawTokens)
            if numel(nodeTokens) ~= 2
                error('spice:model:Diode:BadNodeCount', 'Diode %s expects exactly two nodes.', name);
            end
            params = struct('modelId', modelId);
            obj@spice.model.Device(name, nodeTokens, params, lineNumber, rawTokens);
        end

        function tf = supportsNativeAnalysis(~, analysisType, ~)
            tf = any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"]);
        end

        function initialGuessContribution(obj, assembler, nativeCircuit, ~, ~)
            spice.util.ensureLegacyPath();
            model = nativeCircuit.diodeModel(obj.Parameters.modelId);
            [conductance, currentEq] = Diode_Calculator(0.66, model.Parameters.is, 27);
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addConductance(n1, n2, conductance);
            assembler.addCurrentSource(n1, n2, currentEq);
        end

        function state = evaluateOperatingPoint(obj, nativeCircuit, solution, ~)
            spice.util.ensureLegacyPath();
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            vpn = 0;
            if ~isempty(solution)
                vpn = nativeCircuit.nodeVoltage(solution, n1) - nativeCircuit.nodeVoltage(solution, n2);
            end
            model = nativeCircuit.diodeModel(obj.Parameters.modelId);
            [conductance, currentEq] = Diode_Calculator(vpn, model.Parameters.is, 27);
            state = struct( ...
                'n1', n1, ...
                'n2', n2, ...
                'vpn', vpn, ...
                'conductance', conductance, ...
                'currentEq', currentEq, ...
                'current', conductance * vpn + currentEq, ...
                'saturationCurrent', model.Parameters.is);
        end

        function stampDcLinearized(~, assembler, ~, state, ~)
            assembler.addConductance(state.n1, state.n2, state.conductance);
            assembler.addCurrentSource(state.n1, state.n2, state.currentEq);
        end

        function stampAcLinearized(~, assembler, ~, state, ~)
            assembler.addConductance(state.n1, state.n2, state.conductance);
        end

        function stampTransientLinearized(~, assembler, ~, state, ~)
            assembler.addConductance(state.n1, state.n2, state.conductance);
            assembler.addCurrentSource(state.n1, state.n2, state.currentEq);
        end

        function current = currentForProbe(obj, analysisType, nativeCircuit, solutionMatrix, ~, portName)
            switch string(analysisType)
                case {"dc", "dcsweep", "trans", "shoot"}
                    current = zeros(1, size(solutionMatrix, 2));
                    if isvector(solutionMatrix)
                        current = obj.sampleCurrent(nativeCircuit, solutionMatrix);
                    else
                        for idx = 1:size(solutionMatrix, 2)
                            current(idx) = obj.sampleCurrent(nativeCircuit, solutionMatrix(:, idx));
                        end
                    end
                case "ac"
                    state = nativeCircuit.OperatingPointContext.deviceState(obj.Name);
                    n1 = state.n1;
                    n2 = state.n2;
                    voltageDrop = nativeCircuit.nodeVoltage(solutionMatrix, n1) - nativeCircuit.nodeVoltage(solutionMatrix, n2);
                    current = state.conductance .* voltageDrop;
                otherwise
                    error('spice:model:Diode:UnsupportedCurrentProbe', ...
                        'Unsupported analysis %s for diode current probe.', analysisType);
            end
            if string(portName) == "-"
                current = -current;
            end
        end

        function exportToLegacy(obj, collector)
            collector.addDiode(obj);
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            if numel(tokens) < 4
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 4 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.Diode(tokens{1}, string(tokens(2:3)), str2double(tokens{4}), lineNumber, tokens);
        end
    end

    methods (Access = private)
        function current = sampleCurrent(obj, nativeCircuit, solutionColumn)
            state = obj.evaluateOperatingPoint(nativeCircuit, solutionColumn, []);
            current = state.current;
        end
    end
end
