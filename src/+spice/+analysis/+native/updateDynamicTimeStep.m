function nextStep = updateDynamicTimeStep(currentStep, maxStep, lteMetric, tolerance)
% UPDATEDYNAMICTIMESTEP Grow accepted non-TR dynamic steps conservatively.
if lteMetric < 0.1 * tolerance
    nextStep = min(2 * currentStep, maxStep);
elseif lteMetric < 0.5 * tolerance
    nextStep = min(1.25 * currentStep, maxStep);
else
    nextStep = currentStep;
end
end
