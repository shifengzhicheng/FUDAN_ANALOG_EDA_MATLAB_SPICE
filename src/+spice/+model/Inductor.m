classdef Inductor < spice.model.TwoTerminalValueDevice
    % INDUCTOR Two-terminal inductor using a branch-current MNA variable.
    properties (Constant)
        Kind = "inductor"
        LegacyPassiveKind = "L"
    end

    methods
        function obj = Inductor(name, nodeTokens, value, lineNumber, rawTokens)
            obj@spice.model.TwoTerminalValueDevice(name, nodeTokens, value, lineNumber, rawTokens);
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

        function initialGuessContribution(obj, assembler, nativeCircuit, ~, ~)
            obj.stampDc(assembler, nativeCircuit);
        end

        function state = evaluateOperatingPoint(obj, nativeCircuit, solution, context)
            history = context.inductorHistory(obj.Name);
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            branchIndex = nativeCircuit.branchVarIndex(obj.Name);
            current = 0;
            voltage = 0;
            if ~isempty(solution)
                current = nativeCircuit.branchCurrent(solution, branchIndex);
                voltage = nativeCircuit.nodeVoltage(solution, n1) - nativeCircuit.nodeVoltage(solution, n2);
            end
            state = struct('historyKey', obj.Name, 'n1', n1, 'n2', n2, 'branchIndex', branchIndex, 'value', obj.Parameters.value, ...
                'history', history, 'current', current, 'voltage', voltage);
        end

        function stampDc(obj, assembler, nativeCircuit)
            obj.stampBranchEquation(assembler, nativeCircuit, 0, 0);
        end

        function stampAc(obj, assembler, nativeCircuit, omega)
            obj.stampBranchEquation(assembler, nativeCircuit, 1i * omega * obj.Parameters.value, 0);
        end

        function stampTransient(obj, assembler, nativeCircuit, ~, stepState)
            history = stepState.inductorHistory(obj.Name);
            [seriesCoeff, rhsValue] = spice.analysis.native.inductorCompanion(obj.Parameters.value, stepState.dt, ...
                stepState.method, history.current, history.voltage);
            obj.stampBranchEquation(assembler, nativeCircuit, seriesCoeff, rhsValue);
        end

        function stampTransientLinearized(~, assembler, ~, state, context)
            [seriesCoeff, rhsValue] = spice.analysis.native.inductorCompanion(state.value, context.TimeStep, ...
                context.Options.TransientMethod, state.history.current, state.history.voltage);
            spice.model.Inductor.addStampedBranch(assembler, state.n1, state.n2, state.branchIndex, seriesCoeff, rhsValue);
        end

        function updateDynamicState(~, nativeCircuit, solutionColumn, previousContext, nextContext, deviceState)
            voltageNow = nativeCircuit.nodeVoltage(solutionColumn, deviceState.n1) - nativeCircuit.nodeVoltage(solutionColumn, deviceState.n2);
            currentNow = nativeCircuit.branchCurrent(solutionColumn, deviceState.branchIndex);
            nextContext.setInductorHistory(deviceState.historyKey, voltageNow, currentNow);
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
            if numel(tokens) < 4
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 4 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.Inductor(tokens{1}, string(tokens(2:3)), spice.util.parseNumericWithSuffix(tokens{4}), lineNumber, tokens);
        end

        function addStampedBranch(assembler, n1, n2, branchIndex, branchCoeff, rhsValue)
            assembler.addBranchKcl(n1, n2, branchIndex);
            assembler.addBranchEquation(n1, n2, branchIndex, branchCoeff, rhsValue);
        end
    end

    methods (Access = private)
        function stampBranchEquation(obj, assembler, nativeCircuit, branchCoeff, rhsValue)
            n1 = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            n2 = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            branchIndex = nativeCircuit.branchVarIndex(obj.Name);
            spice.model.Inductor.addStampedBranch(assembler, n1, n2, branchIndex, branchCoeff, rhsValue);
        end
    end
end
