function nextContext = advanceTransientState(circuit, nativeCircuit, options, previousContext, convergedContext, solution, timePoint, stepTime)
% ADVANCETRANSIENTSTATE Commit dynamic device histories after a solved step.
nextContext = spice.analysis.native.AnalysisContext("trans", nativeCircuit, options, ...
    'Time', timePoint, 'TimeStep', stepTime, ...
    'OperatingPointSolution', solution, ...
    'TransientHistory', previousContext.TransientHistory);
nextContext.DeviceStates = convergedContext.DeviceStates;

for deviceIdx = 1:numel(circuit.Elements)
    device = circuit.Elements{deviceIdx};
    device.updateDynamicState(nativeCircuit, solution, previousContext, nextContext, convergedContext.deviceState(device.Name));
end
end
