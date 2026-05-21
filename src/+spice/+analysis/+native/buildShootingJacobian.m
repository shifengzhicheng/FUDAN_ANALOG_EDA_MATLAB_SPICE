function jacobian = buildShootingJacobian(circuit, nativeCircuit, solver, options, stateGuess, finalState, period, stepTime)
% BUILDSHOOTINGJACOBIAN Estimate the shooting map Jacobian by finite differences.
stateCount = numel(stateGuess);
jacobian = zeros(stateCount, stateCount);
for idx = 1:stateCount
    perturbation = max(1e-8, 1e-6 * max(1, abs(stateGuess(idx))));
    perturbedState = stateGuess;
    perturbedState(idx) = perturbedState(idx) + perturbation;
    [~, perturbedSolutionMatrix] = spice.analysis.native.integrateTransientWindow( ...
        circuit, nativeCircuit, solver, options, perturbedState, period, stepTime);
    perturbedFinalState = perturbedSolutionMatrix(:, end);
    jacobian(:, idx) = (perturbedFinalState - finalState) / perturbation;
end
end
