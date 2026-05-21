function [tf, nativeCircuit, reason] = canRun(circuit, options)
% CANRUN Report whether the circuit can use the native backend.
analysisType = string(circuit.Analysis.Type);
nativeCircuit = spice.analysis.native.NativeCircuit(circuit);
[tf, reason] = nativeCircuit.supportsAnalysis(analysisType, options);
end
