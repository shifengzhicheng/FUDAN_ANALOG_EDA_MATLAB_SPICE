function [solution, context, stats] = solveOperatingPoint(nativeCircuit, solver, options, analysisType, initialGuess)
% SOLVEOPERATINGPOINT Solve and store the native operating point context.
context = spice.analysis.native.AnalysisContext(analysisType, nativeCircuit, options);
[solution, context, stats] = solver.solve(context, initialGuess);
nativeCircuit.OperatingPointSolution = solution;
nativeCircuit.OperatingPointContext = context;
end
