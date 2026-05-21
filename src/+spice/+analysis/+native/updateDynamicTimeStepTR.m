function nextStep = updateDynamicTimeStepTR(currentStep, controller, errorNorm, accepted)
% UPDATEDYNAMICTIMESTEPTR Update TR step size from normalized LTE error.
effectiveError = max(errorNorm / controller.acceptErrorNorm, 1e-6);
factor = controller.safety * effectiveError ^ (-1 / 3);
if accepted
    factor = clampScalar(factor, 0.75, 2.0);
else
    factor = clampScalar(factor, 0.25, 0.5);
end
nextStep = currentStep * factor;
nextStep = min(max(nextStep, controller.minStep), controller.maxStep);
end

function value = clampScalar(value, minValue, maxValue)
value = min(max(value, minValue), maxValue);
end
