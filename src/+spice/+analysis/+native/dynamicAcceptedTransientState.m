function [acceptedSolution, acceptedContext] = dynamicAcceptedTransientState( ...
        circuit, nativeCircuit, options, previousContext, fullSolution, halfSolution, halfContext, targetTime, stepTime)
% DYNAMICACCEPTEDTRANSIENTSTATE Return accepted state for adaptive BE/TR steps.
if upper(string(options.TransientMethod)) ~= "TR"
    acceptedSolution = halfSolution;
    acceptedContext = halfContext;
    return;
end

acceptedSolution = halfSolution + (halfSolution - fullSolution) / 3;
acceptedSolution = nativeCircuit.clampNodeVoltages(acceptedSolution);
refreshedContext = spice.analysis.native.refreshTransientDeviceContext(nativeCircuit, options, halfContext, acceptedSolution);
acceptedContext = spice.analysis.native.advanceTransientState( ...
    circuit, nativeCircuit, options, previousContext, refreshedContext, acceptedSolution, targetTime, stepTime);
end
