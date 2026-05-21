classdef Bjt < spice.model.Device
    % BJT Three-terminal bipolar transistor with native nonlinear support.
    % The class wraps the legacy Gummel-Poon-style companion formulas and
    % exposes one device state reused by DC Newton, AC small-signal, DC
    % sweep, and fixed-step transient analyses.
    properties (Constant)
        Kind = "bjt"
    end

    methods
        function obj = Bjt(name, nodeTokens, polarity, junctionArea, modelId, lineNumber, rawTokens)
            if numel(nodeTokens) ~= 3
                error('spice:model:Bjt:BadNodeCount', 'BJT %s expects exactly three nodes.', name);
            end
            params = struct('polarity', char(polarity), 'junctionArea', junctionArea, 'modelId', modelId);
            obj@spice.model.Device(name, nodeTokens, params, lineNumber, rawTokens);
        end

        function tf = supportsNativeAnalysis(~, analysisType, ~)
            tf = any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"]);
        end

        function initialGuessContribution(obj, assembler, nativeCircuit, ~, ~)
            spice.util.ensureLegacyPath();
            model = nativeCircuit.bjtModel(obj.Parameters.modelId);
            legacyModel = num2cell([model.Id; model.Parameters.js; model.Parameters.alphaF; model.Parameters.alphaR; model.Parameters.cje; model.Parameters.cjc]);
            if strcmpi(obj.Parameters.polarity, 'npn')
                vbe0 = 0.7;
                vbc0 = 0.1;
            else
                vbe0 = -0.7;
                vbc0 = -0.1;
            end
            [rbe, gbc_e, ieq, rbc, gbe_c, icq] = BJT_Calculator(vbe0, vbc0, legacyModel, obj.Parameters.junctionArea, obj.bjtFlag(), 300);
            state = struct( ...
                'cNode', nativeCircuit.nodeVarIndex(obj.NodeTokens(1)), ...
                'bNode', nativeCircuit.nodeVarIndex(obj.NodeTokens(2)), ...
                'eNode', nativeCircuit.nodeVarIndex(obj.NodeTokens(3)), ...
                'gbe', 1 ./ rbe, ...
                'gbc_e', gbc_e, ...
                'ieq', ieq, ...
                'gbc', 1 ./ rbc, ...
                'gbe_c', gbe_c, ...
                'icq', icq);
            obj.stampConductivePart(assembler, state);
        end

        function state = evaluateOperatingPoint(obj, nativeCircuit, solution, context)
            spice.util.ensureLegacyPath();
            cNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            bNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            eNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(3));

            vc = 0;
            vb = 0;
            ve = 0;
            if ~isempty(solution)
                vc = nativeCircuit.nodeVoltage(solution, cNode);
                vb = nativeCircuit.nodeVoltage(solution, bNode);
                ve = nativeCircuit.nodeVoltage(solution, eNode);
            end

            vbe = vb - ve;
            vbc = vb - vc;
            flag = obj.bjtFlag();
            model = nativeCircuit.bjtModel(obj.Parameters.modelId);
            legacyModel = num2cell([model.Id; model.Parameters.js; model.Parameters.alphaF; model.Parameters.alphaR; model.Parameters.cje; model.Parameters.cjc]);
            [rbe, gbc_e, ieq, rbc, gbe_c, icq] = BJT_Calculator(vbe, vbc, legacyModel, obj.Parameters.junctionArea, flag, 300);
            gbe = 1 ./ rbe;
            gbc = 1 ./ rbc;

            emitterCurrent = -gbe * vbe + gbc_e * vbc + ieq;
            collectorCurrent = -gbc * vbc + gbe_c * vbe + icq;
            conductiveBranches = struct( ...
                'emitterResistive', -gbe * vbe, ...
                'emitterControlled', gbc_e * vbc, ...
                'emitterIeq', ieq, ...
                'collectorResistive', -gbc * vbc, ...
                'collectorControlled', gbe_c * vbe, ...
                'collectorIeq', icq);
            dynamicCaps = obj.dynamicCapState(context, model, cNode, bNode, eNode, vbe, vbc);

            state = struct( ...
                'cNode', cNode, ...
                'bNode', bNode, ...
                'eNode', eNode, ...
                'vc', vc, ...
                'vb', vb, ...
                've', ve, ...
                'vbe', vbe, ...
                'vbc', vbc, ...
                'flag', flag, ...
                'gbe', gbe, ...
                'gbc_e', gbc_e, ...
                'ieq', ieq, ...
                'gbc', gbc, ...
                'gbe_c', gbe_c, ...
                'icq', icq, ...
                'collectorCurrent', collectorCurrent, ...
                'emitterCurrent', emitterCurrent, ...
                'conductiveBranches', conductiveBranches, ...
                'dynamicCaps', dynamicCaps);
        end

        function stampDcLinearized(~, assembler, ~, state, ~)
            spice.model.Bjt.stampConductivePart(assembler, state);
        end

        function stampAcLinearized(obj, assembler, ~, state, context)
            obj.stampConductivePart(assembler, state);
            obj.stampCapacitivePart(assembler, state.dynamicCaps, context.Omega);
        end

        function stampTransientLinearized(obj, assembler, ~, state, context)
            obj.stampConductivePart(assembler, state);
            obj.stampTransientCaps(assembler, state.dynamicCaps, context.TimeStep, context.Options.TransientMethod);
        end

        function updateDynamicState(~, nativeCircuit, solutionColumn, previousContext, nextContext, deviceState)
            stepTime = nextContext.TimeStep;
            for idx = 1:numel(deviceState.dynamicCaps)
                cap = deviceState.dynamicCaps(idx);
                voltageNow = nativeCircuit.nodeVoltage(solutionColumn, cap.n1) - nativeCircuit.nodeVoltage(solutionColumn, cap.n2);
                history = previousContext.capacitorHistory(cap.historyKey);
                if upper(string(previousContext.Options.TransientMethod)) == "TR"
                    currentNow = history.current + 2 * cap.value / stepTime * (voltageNow - history.voltage);
                else
                    currentNow = cap.value / stepTime * (voltageNow - history.voltage);
                end
                nextContext.setCapacitorHistory(cap.historyKey, voltageNow, currentNow);
            end
        end

        function current = currentForProbe(obj, analysisType, nativeCircuit, solutionMatrix, axisValues, portName)
            switch string(analysisType)
                case {"dc", "dcsweep"}
                    [collectorTrace, baseTrace, emitterTrace] = obj.sampleDcLikeCurrents(nativeCircuit, solutionMatrix);
                case "ac"
                    [collectorTrace, baseTrace, emitterTrace] = obj.sampleAcCurrents(nativeCircuit, solutionMatrix, axisValues);
                case {"trans", "shoot"}
                    [collectorTrace, baseTrace, emitterTrace] = obj.sampleTransientCurrents(nativeCircuit, solutionMatrix, axisValues);
                otherwise
                    error('spice:model:Bjt:UnsupportedCurrentProbe', ...
                        'Unsupported analysis %s for BJT.', analysisType);
            end

            switch string(portName)
                case "c"
                    current = collectorTrace;
                case "b"
                    current = baseTrace;
                case "e"
                    current = emitterTrace;
                otherwise
                    error('spice:model:Bjt:UnsupportedPort', 'Unsupported BJT port %s.', portName);
            end
        end

        function exportToLegacy(obj, collector)
            collector.addBjt(obj);
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            if numel(tokens) < 7
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 7 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.Bjt(tokens{1}, string(tokens(2:4)), tokens{5}, ...
                spice.util.parseNumericWithSuffix(tokens{6}), str2double(tokens{7}), lineNumber, tokens);
        end

        function stampConductivePart(assembler, state)
            assembler.addConductance(state.eNode, state.bNode, state.gbe);
            assembler.addVccs(state.eNode, state.bNode, state.bNode, state.cNode, state.gbc_e);
            assembler.addCurrentSource(state.eNode, state.bNode, state.ieq);

            assembler.addConductance(state.cNode, state.bNode, state.gbc);
            assembler.addVccs(state.cNode, state.bNode, state.bNode, state.eNode, state.gbe_c);
            assembler.addCurrentSource(state.cNode, state.bNode, state.icq);
        end
    end

    methods (Access = private)
        function flag = bjtFlag(obj)
            if strcmpi(obj.Parameters.polarity, 'npn')
                flag = 1;
            else
                flag = -1;
            end
        end

        function dynamicCaps = dynamicCapState(obj, context, model, cNode, bNode, eNode, vbe, vbc)
            me = 0.41;
            mc = 0.41;
            fy_e = 0.76;
            fy_c = 0.70;
            scale = obj.Parameters.junctionArea;

            cbe = scale * model.Parameters.cje / obj.capScale(vbe, fy_e, me);
            cbc = scale * model.Parameters.cjc / obj.capScale(vbc, fy_c, mc);
            dynamicCaps = [ ...
                spice.model.Capacitor.makeCapState(obj.Name + "_Cbe", bNode, eNode, cbe, obj.capHistory(context, obj.Name + "_Cbe")); ...
                spice.model.Capacitor.makeCapState(obj.Name + "_Cbc", bNode, cNode, cbc, obj.capHistory(context, obj.Name + "_Cbc"))];
        end

        function value = capScale(~, voltage, fy, exponent)
            raw = 1 - abs(voltage) / fy;
            raw = max(raw, 1e-3);
            value = raw ^ exponent;
        end

        function history = capHistory(~, context, historyKey)
            if isempty(context)
                history = struct('voltage', 0, 'current', 0);
            else
                history = context.capacitorHistory(historyKey);
            end
        end

        function stampCapacitivePart(~, assembler, caps, omega)
            for idx = 1:numel(caps)
                assembler.addConductance(caps(idx).n1, caps(idx).n2, 1i * omega * caps(idx).value);
            end
        end

        function stampTransientCaps(~, assembler, caps, dt, method)
            for idx = 1:numel(caps)
                [conductance, rhsCurrent] = spice.analysis.native.capacitorCompanion(caps(idx).value, dt, method, ...
                    caps(idx).history.voltage, caps(idx).history.current);
                assembler.addConductance(caps(idx).n1, caps(idx).n2, conductance);
                assembler.addRhsCurrentInjection(caps(idx).n1, caps(idx).n2, rhsCurrent);
            end
        end

        function [collectorTrace, baseTrace, emitterTrace] = sampleDcLikeCurrents(obj, nativeCircuit, solutionMatrix)
            if isvector(solutionMatrix)
                state = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix, []);
                collectorTrace = obj.conductiveCollectorCurrent(state);
                emitterTrace = obj.conductiveEmitterCurrent(state);
                baseTrace = -(collectorTrace + emitterTrace);
                return;
            end
            collectorTrace = zeros(1, size(solutionMatrix, 2));
            baseTrace = zeros(1, size(solutionMatrix, 2));
            emitterTrace = zeros(1, size(solutionMatrix, 2));
            for idx = 1:size(solutionMatrix, 2)
                state = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix(:, idx), []);
                collectorTrace(idx) = obj.conductiveCollectorCurrent(state);
                emitterTrace(idx) = obj.conductiveEmitterCurrent(state);
                baseTrace(idx) = -(collectorTrace(idx) + emitterTrace(idx));
            end
        end

        function [collectorTrace, baseTrace, emitterTrace] = sampleAcCurrents(obj, nativeCircuit, solutionMatrix, axisValues)
            opState = nativeCircuit.OperatingPointContext.deviceState(obj.Name);
            vb = nativeCircuit.nodeVoltage(solutionMatrix, opState.bNode);
            vc = nativeCircuit.nodeVoltage(solutionMatrix, opState.cNode);
            ve = nativeCircuit.nodeVoltage(solutionMatrix, opState.eNode);
            vbe = vb - ve;
            vbc = vb - vc;

            collectorConductive = -opState.gbc .* vbc + opState.gbe_c .* vbe;
            emitterConductive = -opState.gbe .* vbe + opState.gbc_e .* vbc;
            cbe = obj.capTrace(opState.dynamicCaps(1), nativeCircuit, solutionMatrix, axisValues, "ac");
            cbc = obj.capTrace(opState.dynamicCaps(2), nativeCircuit, solutionMatrix, axisValues, "ac");

            collectorTrace = collectorConductive - cbc;
            emitterTrace = emitterConductive - cbe;
            baseTrace = -(collectorConductive + emitterConductive) + cbe + cbc;
        end

        function [collectorTrace, baseTrace, emitterTrace] = sampleTransientCurrents(obj, nativeCircuit, solutionMatrix, axisValues)
            if isvector(solutionMatrix)
                solutionMatrix = solutionMatrix(:);
            end
            sampleCount = size(solutionMatrix, 2);
            collectorConductive = zeros(1, sampleCount);
            emitterConductive = zeros(1, sampleCount);
            cbe = zeros(1, sampleCount);
            cbc = zeros(1, sampleCount);
            for idx = 1:sampleCount
                state = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix(:, idx), []);
                collectorConductive(idx) = obj.conductiveCollectorCurrent(state);
                emitterConductive(idx) = obj.conductiveEmitterCurrent(state);
                if idx > 1
                    previousState = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix(:, idx - 1), []);
                    dt = obj.timeStepAt(axisValues, idx);
                    cbe(idx) = state.dynamicCaps(1).value / dt * (state.vbe - previousState.vbe);
                    cbc(idx) = state.dynamicCaps(2).value / dt * (state.vbc - previousState.vbc);
                end
            end

            collectorTrace = collectorConductive - cbc;
            emitterTrace = emitterConductive - cbe;
            baseTrace = -(collectorConductive + emitterConductive) + cbe + cbc;
        end

        function trace = capTrace(~, capState, nativeCircuit, solutionMatrix, axisValues, mode)
            voltageDrop = nativeCircuit.nodeVoltage(solutionMatrix, capState.n1) - nativeCircuit.nodeVoltage(solutionMatrix, capState.n2);
            switch string(mode)
                case "ac"
                    trace = 1i * (2 * pi * axisValues) .* capState.value .* voltageDrop;
                case "trans"
                    trace = zeros(1, numel(voltageDrop));
                    for idx = 2:numel(voltageDrop)
                        dt = obj.timeStepAt(axisValues, idx);
                        trace(idx) = capState.value / dt * (voltageDrop(idx) - voltageDrop(idx - 1));
                    end
                otherwise
                    trace = zeros(1, numel(voltageDrop));
            end
        end

        function current = conductiveCollectorCurrent(~, state)
            current = state.conductiveBranches.collectorResistive + ...
                state.conductiveBranches.collectorControlled + ...
                state.conductiveBranches.collectorIeq;
        end

        function current = conductiveEmitterCurrent(~, state)
            current = state.conductiveBranches.emitterResistive + ...
                state.conductiveBranches.emitterControlled + ...
                state.conductiveBranches.emitterIeq;
        end

        function dt = timeStepAt(~, axisValues, idx)
            if numel(axisValues) <= 1 || idx <= 1
                dt = 1;
            else
                dt = axisValues(idx) - axisValues(idx - 1);
            end
        end
    end
end
