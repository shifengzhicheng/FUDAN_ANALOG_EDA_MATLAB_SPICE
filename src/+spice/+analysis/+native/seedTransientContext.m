function context = seedTransientContext(nativeCircuit, options, initialSolution, stepTime)
% SEEDTRANSIENTCONTEXT Initialize device states and companion histories.
context = spice.analysis.native.AnalysisContext("trans", nativeCircuit, options, ...
    'Time', 0, 'TimeStep', stepTime, 'OperatingPointSolution', initialSolution);

for idx = 1:numel(nativeCircuit.Circuit.Elements)
    device = nativeCircuit.Circuit.Elements{idx};
    state = device.evaluateOperatingPoint(nativeCircuit, initialSolution, context);
    context.setDeviceState(device.Name, state);
    if isfield(state, 'dynamicCaps')
        for capIdx = 1:numel(state.dynamicCaps)
            cap = state.dynamicCaps(capIdx);
            voltage = nativeCircuit.nodeVoltage(initialSolution, cap.n1) - nativeCircuit.nodeVoltage(initialSolution, cap.n2);
            context.setCapacitorHistory(cap.historyKey, voltage, 0);
        end
    end
    if isfield(state, 'branchIndex')
        current = nativeCircuit.branchCurrent(initialSolution, state.branchIndex);
        context.setInductorHistory(state.historyKey, 0, current);
    end
end
end
