function [timeAxis, solutionMatrix, finalContext, stepIterations, stepModes] = integrateTransientWindow( ...
        circuit, nativeCircuit, solver, options, initialSolution, totalTime, stepTime)
% INTEGRATETRANSIENTWINDOW Integrate a fixed-step transient interval.
timeAxis = 0:stepTime:totalTime;
stateContext = spice.analysis.native.seedTransientContext(nativeCircuit, options, initialSolution, stepTime);
solutionMatrix = zeros(nativeCircuit.matrixSize(), numel(timeAxis));
solutionMatrix(:, 1) = initialSolution;
stepIterations = zeros(1, max(numel(timeAxis) - 1, 0));
stepModes = strings(1, max(numel(timeAxis) - 1, 0));
previousSolution = initialSolution;

for idx = 2:numel(timeAxis)
    initialGuess = spice.analysis.native.chooseTransientInitialGuess(options, previousSolution, idx == 2);
    [solutionMatrix(:, idx), stateContext, stats] = spice.analysis.native.solveTransientOneStep( ...
        circuit, nativeCircuit, solver, options, stateContext, timeAxis(idx), stepTime, initialGuess);
    stepIterations(idx - 1) = stats.iterations;
    if stats.converged
        stepModes(idx - 1) = string(stats.mode);
    else
        stepModes(idx - 1) = "failed";
    end
    previousSolution = solutionMatrix(:, idx);
end

finalContext = stateContext;
nativeCircuit.OperatingPointSolution = solutionMatrix(:, end);
nativeCircuit.OperatingPointContext = stateContext;
end
