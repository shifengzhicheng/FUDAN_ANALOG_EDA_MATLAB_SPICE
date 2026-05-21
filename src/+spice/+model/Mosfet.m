classdef Mosfet < spice.model.Device
    % MOSFET Three-terminal MOSFET with native nonlinear linearization.
    % The class reuses the legacy level-1 calculator formulas, then exposes
    % one consistent device state used by DC Newton, AC small-signal, DC
    % sweep, and fixed-step transient analyses.
    properties (Constant)
        Kind = "mosfet"
    end

    methods
        function obj = Mosfet(name, nodeTokens, polarity, width, lengthValue, modelId, lineNumber, rawTokens)
            if numel(nodeTokens) ~= 3
                error('spice:model:Mosfet:BadNodeCount', 'MOSFET %s expects exactly three nodes.', name);
            end
            params = struct('polarity', char(polarity), 'width', width, 'length', lengthValue, 'modelId', modelId);
            obj@spice.model.Device(name, nodeTokens, params, lineNumber, rawTokens);
        end

        function tf = supportsNativeAnalysis(~, analysisType, ~)
            tf = any(string(analysisType) == ["dc", "dcsweep", "ac", "trans"]);
        end

        function initialGuessContribution(obj, assembler, nativeCircuit, ~, ~)
            spice.util.ensureLegacyPath();
            model = nativeCircuit.mosModel(obj.Parameters.modelId);
            legacyModel = [model.Id; model.Parameters.vt; model.Parameters.mu; model.Parameters.cox; model.Parameters.lambda; model.Parameters.cj0];
            supply = max(1, nativeCircuit.estimatedSupplyVoltage());
            if lower(string(obj.Parameters.polarity)) == "n"
                vgs = max(model.Parameters.vt + 0.5, 0.8);
            else
                vgs = min(model.Parameters.vt - 0.5, -0.8);
            end
            vds = max(0.5, 0.5 * supply);
            [ieq, gm, gds] = Mos_Calculator(vds, vgs, legacyModel, obj.Parameters.width, obj.Parameters.length);
            dNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            gNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            sNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(3));
            assembler.addConductance(dNode, sNode, gds);
            assembler.addVccs(dNode, sNode, gNode, sNode, gm);
            assembler.addCurrentSource(dNode, sNode, ieq);
        end

        function state = evaluateOperatingPoint(obj, nativeCircuit, solution, context)
            spice.util.ensureLegacyPath();
            dNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(1));
            gNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(2));
            sNode = nativeCircuit.nodeVarIndex(obj.NodeTokens(3));

            vd = 0;
            vg = 0;
            vs = 0;
            if ~isempty(solution)
                vd = nativeCircuit.nodeVoltage(solution, dNode);
                vg = nativeCircuit.nodeVoltage(solution, gNode);
                vs = nativeCircuit.nodeVoltage(solution, sNode);
            end

            [flag, controlNode, vds, vgs] = obj.resolveBiasFrame(vd, vg, vs, dNode, sNode);
            model = nativeCircuit.mosModel(obj.Parameters.modelId);
            legacyModel = [model.Id; model.Parameters.vt; model.Parameters.mu; model.Parameters.cox; model.Parameters.lambda; model.Parameters.cj0];
            [ieqLocal, gmLocal, gds] = Mos_Calculator(vds, vgs, legacyModel, obj.Parameters.width, obj.Parameters.length);

            gm = gmLocal * flag;
            ieq = ieqLocal * flag;
            controlVoltage = vg - nativeCircuit.nodeVoltage(solutionOrZeros(solution, nativeCircuit.matrixSize()), controlNode);
            current = gds * (vd - vs) + gm * controlVoltage + ieq;
            conductiveBranches = struct( ...
                'gds', gds * (vd - vs), ...
                'gm', gm * controlVoltage, ...
                'ieq', ieq);
            dynamicCaps = obj.dynamicCapState(context, model, dNode, gNode, sNode);

            state = struct( ...
                'dNode', dNode, ...
                'gNode', gNode, ...
                'sNode', sNode, ...
                'vd', vd, ...
                'vg', vg, ...
                'vs', vs, ...
                'vds', vds, ...
                'vgs', vgs, ...
                'flag', flag, ...
                'controlNode', controlNode, ...
                'gds', gds, ...
                'gm', gm, ...
                'ieq', ieq, ...
                'current', current, ...
                'conductiveBranches', conductiveBranches, ...
                'dynamicCaps', dynamicCaps);
        end

        function stampDcLinearized(~, assembler, ~, state, ~)
            assembler.addConductance(state.dNode, state.sNode, state.gds);
            assembler.addVccs(state.dNode, state.sNode, state.gNode, state.controlNode, state.gm);
            assembler.addCurrentSource(state.dNode, state.sNode, state.ieq);
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
                    [idTrace, gateTrace, sourceTrace] = obj.sampleDcLikeCurrents(nativeCircuit, solutionMatrix);
                case "ac"
                    [idTrace, gateTrace, sourceTrace] = obj.sampleAcCurrents(nativeCircuit, solutionMatrix, axisValues);
                case {"trans", "shoot"}
                    [idTrace, gateTrace, sourceTrace] = obj.sampleTransientCurrents(nativeCircuit, solutionMatrix, axisValues);
                otherwise
                    error('spice:model:Mosfet:UnsupportedCurrentProbe', ...
                        'Unsupported analysis %s for MOSFET.', analysisType);
            end

            switch string(portName)
                case "d"
                    current = idTrace;
                case "g"
                    current = gateTrace;
                case "s"
                    current = sourceTrace;
                otherwise
                    error('spice:model:Mosfet:UnsupportedPort', 'Unsupported MOSFET port %s.', portName);
            end
        end

        function exportToLegacy(obj, collector)
            collector.addMosfet(obj);
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            if numel(tokens) < 8
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 8 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.Mosfet(tokens{1}, string(tokens(2:4)), tokens{5}, ...
                spice.util.parseNumericWithSuffix(tokens{6}), spice.util.parseNumericWithSuffix(tokens{7}), ...
                str2double(tokens{8}), lineNumber, tokens);
        end
    end

    methods (Access = private)
        function [flag, controlNode, vds, vgs] = resolveBiasFrame(obj, vd, vg, vs, dNode, sNode)
            polarity = lower(string(obj.Parameters.polarity));
            swapTerminals = (polarity == "n" && vd < vs) || (polarity == "p" && vd > vs);
            if swapTerminals
                flag = -1;
                controlNode = dNode;
                vds = vs - vd;
                vgs = vg - vd;
            else
                flag = 1;
                controlNode = sNode;
                vds = vd - vs;
                vgs = vg - vs;
            end
        end

        function dynamicCaps = dynamicCapState(obj, context, model, dNode, gNode, sNode)
            width = obj.Parameters.width;
            lengthValue = obj.Parameters.length;
            cgs = 0.5 * width * lengthValue * model.Parameters.cox;
            cgd = 0.5 * width * lengthValue * model.Parameters.cox;
            cd = model.Parameters.cj0;
            cs = model.Parameters.cj0;

            dynamicCaps = [ ...
                spice.model.Capacitor.makeCapState(obj.Name + "_Cgs", gNode, sNode, cgs, obj.capHistory(context, obj.Name + "_Cgs")); ...
                spice.model.Capacitor.makeCapState(obj.Name + "_Cgd", gNode, dNode, cgd, obj.capHistory(context, obj.Name + "_Cgd")); ...
                spice.model.Capacitor.makeCapState(obj.Name + "_Cd", dNode, 0, cd, obj.capHistory(context, obj.Name + "_Cd")); ...
                spice.model.Capacitor.makeCapState(obj.Name + "_Cs", sNode, 0, cs, obj.capHistory(context, obj.Name + "_Cs"))];
        end

        function history = capHistory(~, context, historyKey)
            if isempty(context)
                history = struct('voltage', 0, 'current', 0);
            else
                history = context.capacitorHistory(historyKey);
            end
        end

        function stampConductivePart(~, assembler, state)
            assembler.addConductance(state.dNode, state.sNode, state.gds);
            assembler.addVccs(state.dNode, state.sNode, state.gNode, state.controlNode, state.gm);
            assembler.addCurrentSource(state.dNode, state.sNode, state.ieq);
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

        function [drainTrace, gateTrace, sourceTrace] = sampleDcLikeCurrents(obj, nativeCircuit, solutionMatrix)
            if isvector(solutionMatrix)
                state = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix, []);
                drainTrace = obj.conductiveDrainCurrent(state);
                gateTrace = 0;
                sourceTrace = -state.current;
                return;
            end
            drainTrace = zeros(1, size(solutionMatrix, 2));
            gateTrace = zeros(1, size(solutionMatrix, 2));
            sourceTrace = zeros(1, size(solutionMatrix, 2));
            for idx = 1:size(solutionMatrix, 2)
                state = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix(:, idx), []);
                drainTrace(idx) = obj.conductiveDrainCurrent(state);
                sourceTrace(idx) = -state.current;
            end
        end

        function [drainTrace, gateTrace, sourceTrace] = sampleAcCurrents(obj, nativeCircuit, solutionMatrix, axisValues)
            opState = nativeCircuit.OperatingPointContext.deviceState(obj.Name);
            vd = nativeCircuit.nodeVoltage(solutionMatrix, opState.dNode);
            vg = nativeCircuit.nodeVoltage(solutionMatrix, opState.gNode);
            vs = nativeCircuit.nodeVoltage(solutionMatrix, opState.sNode);
            vctrl = vg - nativeCircuit.nodeVoltage(solutionMatrix, opState.controlNode);
            conduction = opState.gds .* (vd - vs) + opState.gm .* vctrl;

            cgs = obj.capTrace(opState.dynamicCaps(1), nativeCircuit, solutionMatrix, axisValues, "ac");
            cgd = obj.capTrace(opState.dynamicCaps(2), nativeCircuit, solutionMatrix, axisValues, "ac");
            cd = obj.capTrace(opState.dynamicCaps(3), nativeCircuit, solutionMatrix, axisValues, "ac");
            cs = obj.capTrace(opState.dynamicCaps(4), nativeCircuit, solutionMatrix, axisValues, "ac");

            drainTrace = conduction - cgd + cd;
            gateTrace = cgs + cgd;
            sourceTrace = -conduction - cgs + cs;
        end

        function [drainTrace, gateTrace, sourceTrace] = sampleTransientCurrents(obj, nativeCircuit, solutionMatrix, axisValues)
            if isvector(solutionMatrix)
                solutionMatrix = solutionMatrix(:);
            end
            sampleCount = size(solutionMatrix, 2);
            conduction = zeros(1, sampleCount);
            cgs = zeros(1, sampleCount);
            cgd = zeros(1, sampleCount);
            cd = zeros(1, sampleCount);
            cs = zeros(1, sampleCount);
            for idx = 1:sampleCount
                state = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix(:, idx), []);
                conduction(idx) = obj.conductiveDrainCurrent(state);
                if idx > 1
                    previousState = obj.evaluateOperatingPoint(nativeCircuit, solutionMatrix(:, idx - 1), []);
                    dt = obj.timeStepAt(axisValues, idx);
                    cgs(idx) = state.dynamicCaps(1).value / dt * ((state.vg - state.vs) - (previousState.vg - previousState.vs));
                    cgd(idx) = state.dynamicCaps(2).value / dt * ((state.vg - state.vd) - (previousState.vg - previousState.vd));
                    cd(idx) = state.dynamicCaps(3).value / dt * (state.vd - previousState.vd);
                    cs(idx) = state.dynamicCaps(4).value / dt * (state.vs - previousState.vs);
                end
            end

            drainTrace = conduction - cgd + cd;
            gateTrace = cgs + cgd;
            sourceTrace = -conduction - cgs + cs;
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

        function current = conductiveDrainCurrent(~, state)
            current = state.conductiveBranches.gds + state.conductiveBranches.gm + state.conductiveBranches.ieq;
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

function out = solutionOrZeros(solution, matrixSize)
if isempty(solution)
    out = zeros(matrixSize, 1);
else
    out = solution;
end
end
