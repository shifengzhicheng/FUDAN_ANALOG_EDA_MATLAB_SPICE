function [solution, context, stats] = solveTransientStep(solver, stepContext, initialGuess)
% SOLVETRANSIENTSTEP Solve one transient step with strict then relaxed Newton.
try
    [solution, context, stats] = solver.solve(stepContext, initialGuess);
    stats.mode = "strict";
    return;
catch err
    if string(err.identifier) ~= "spice:analysis:native:NonlinearNotConverged"
        rethrow(err);
    end
end

if isempty(initialGuess)
    guess = solver.buildInitialGuess(stepContext);
else
    guess = initialGuess;
end

guess = stepContext.NativeCircuit.clampNodeVoltages(guess);
maxRelaxIterations = 60;
tolerance = stepContext.Options.ErrorTolerance;
context = stepContext.copy();

for idx = 1:maxRelaxIterations
    [matrix, rhs, iterationContext] = solver.assembleLinearized(stepContext.copy(), guess);
    candidate = spice.solver.solveLinearSystem(matrix, rhs);
    candidate = stepContext.NativeCircuit.clampNodeVoltages(candidate);
    if norm(candidate - guess, inf) <= max(tolerance, tolerance * max(1, norm(candidate, inf)))
        context = iterationContext;
        context.OperatingPointSolution = candidate;
        solution = candidate;
        stats = struct('iterations', idx, 'converged', true, 'mode', "relaxed");
        return;
    end
    guess = 0.5 * guess + 0.5 * candidate;
    context = iterationContext;
end

solution = guess;
context.OperatingPointSolution = solution;
stats = struct('iterations', maxRelaxIterations, 'converged', false, 'mode', "failed");
end
