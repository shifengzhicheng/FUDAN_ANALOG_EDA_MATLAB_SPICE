classdef Capacitor < spice.model.TwoTerminalValueDevice
    % CAPACITOR Two-terminal capacitor with AC admittance and transient companions.
    properties (Constant)
        Kind = "capacitor"
        LegacyPassiveKind = "C"
    end

    methods
        function obj = Capacitor(name, nodeTokens, value, lineNumber, rawTokens)
            obj@spice.model.TwoTerminalValueDevice(name, nodeTokens, value, lineNumber, rawTokens);
        end

        function tf = supportsNativeAnalysis(~, analysisType, ~)
            tf = any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"]);
        end

        function state = evaluateOperatingPoint(obj, nativeCircuit, solution, context)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            voltage = 0;
            if ~isempty(solution)
                voltage = nativeCircuit.nodeVoltage(solution, n1) - nativeCircuit.nodeVoltage(solution, n2);
            end
            state = struct( ...
                'dynamicCaps', spice.model.Capacitor.makeCapState(obj.Name, n1, n2, obj.Parameters.value, context.capacitorHistory(obj.Name)), ...
                'voltage', voltage);
        end

        function stampDc(~, ~, ~)
        end

        function stampAc(obj, assembler, nativeCircuit, omega)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addConductance(n1, n2, 1i * omega * obj.Parameters.value);
        end

        function stampTransient(obj, assembler, nativeCircuit, ~, stepState)
            history = stepState.capacitorHistory(obj.Name);
            [conductance, rhsCurrent] = spice.analysis.native.capacitorCompanion(obj.Parameters.value, stepState.dt, ...
                stepState.method, history.voltage, history.current);
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            assembler.addConductance(n1, n2, conductance);
            assembler.addRhsCurrentInjection(n1, n2, rhsCurrent);
        end

        function stampAcLinearized(~, assembler, ~, state, context)
            caps = state.dynamicCaps;
            for idx = 1:numel(caps)
                assembler.addConductance(caps(idx).n1, caps(idx).n2, 1i * context.Omega * caps(idx).value);
            end
        end

        function stampTransientLinearized(~, assembler, ~, state, context)
            caps = state.dynamicCaps;
            for idx = 1:numel(caps)
                [conductance, rhsCurrent] = spice.analysis.native.capacitorCompanion(caps(idx).value, context.TimeStep, ...
                    context.Options.TransientMethod, caps(idx).history.voltage, caps(idx).history.current);
                assembler.addConductance(caps(idx).n1, caps(idx).n2, conductance);
                assembler.addRhsCurrentInjection(caps(idx).n1, caps(idx).n2, rhsCurrent);
            end
        end

        function updateDynamicState(obj, nativeCircuit, solutionColumn, previousContext, nextContext, ~)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            voltageNow = nativeCircuit.nodeVoltage(solutionColumn, n1) - nativeCircuit.nodeVoltage(solutionColumn, n2);
            history = previousContext.capacitorHistory(obj.Name);
            stepTime = nextContext.TimeStep;
            if upper(string(previousContext.Options.TransientMethod)) == "TR"
                currentNow = history.current + 2 * obj.Parameters.value / stepTime * (voltageNow - history.voltage);
            else
                currentNow = obj.Parameters.value / stepTime * (voltageNow - history.voltage);
            end
            nextContext.setCapacitorHistory(obj.Name, voltageNow, currentNow);
        end

        function current = currentForProbe(obj, analysisType, nativeCircuit, solutionMatrix, axisValues, portName)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            switch string(analysisType)
                case {"dc", "dcsweep"}
                    current = zeros(1, size(solutionMatrix, 2));
                    if isvector(solutionMatrix)
                        current = 0;
                    end
                case "ac"
                    voltageDrop = nativeCircuit.nodeVoltage(solutionMatrix, n1) - nativeCircuit.nodeVoltage(solutionMatrix, n2);
                    current = 1i * (2 * pi * axisValues) .* obj.Parameters.value .* voltageDrop;
                case {"trans", "shoot"}
                    voltageDrop = nativeCircuit.nodeVoltage(solutionMatrix, n1) - nativeCircuit.nodeVoltage(solutionMatrix, n2);
                    current = zeros(1, numel(voltageDrop));
                    method = upper(string(nativeCircuit.TransientMethod));
                    for idx = 2:numel(voltageDrop)
                        dt = timeStepAt(axisValues, idx);
                        if method == "TR"
                            current(idx) = current(idx - 1) + 2 * obj.Parameters.value / dt * (voltageDrop(idx) - voltageDrop(idx - 1));
                        else
                            current(idx) = obj.Parameters.value / dt * (voltageDrop(idx) - voltageDrop(idx - 1));
                        end
                    end
                otherwise
                    error('spice:model:Capacitor:UnsupportedCurrentProbe', ...
                        'Unsupported analysis %s for capacitor.', analysisType);
            end
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
            obj = spice.model.Capacitor(tokens{1}, string(tokens(2:3)), spice.util.parseNumericWithSuffix(tokens{4}), lineNumber, tokens);
        end

        function capState = makeCapState(historyKey, n1, n2, value, history)
            capState = struct('historyKey', string(historyKey), 'n1', n1, 'n2', n2, 'value', value, 'history', history);
        end
    end
end

function dt = timeStepAt(axisValues, idx)
if numel(axisValues) <= 1 || idx <= 1
    dt = 1;
else
    dt = axisValues(idx) - axisValues(idx - 1);
end
end
