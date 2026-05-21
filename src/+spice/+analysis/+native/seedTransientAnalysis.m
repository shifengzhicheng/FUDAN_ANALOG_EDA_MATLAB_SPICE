function [initialSolution, stateContext, operatingPoint, dcStats] = seedTransientAnalysis( ...
        circuit, nativeCircuit, solver, options, stepTime)
% SEEDTRANSIENTANALYSIS Build the initial state for transient-like analyses.
analysisType = string(circuit.Analysis.Type);
operatingPoint = [];
if string(options.TransientInitMethod) == "DC"
    [operatingPoint, ~, dcStats] = spice.analysis.native.solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
    initialSolution = operatingPoint;
else
    dcStats = struct('iterations', 0, 'converged', true);
    nativeCircuit.configureAnalysis(transientConfigureKind(analysisType), 'TransientMethod', options.TransientMethod);
    initialSolution = zeros(nativeCircuit.matrixSize(), 1);
end
stateContext = spice.analysis.native.seedTransientContext(nativeCircuit, options, initialSolution, stepTime);
end

function kind = transientConfigureKind(analysisType)
if string(analysisType) == "shoot"
    kind = "trans";
else
    kind = string(analysisType);
end
end
