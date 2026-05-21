function initialGuess = chooseTransientInitialGuess(options, previousSolution, isFirstStep)
% CHOOSETRANSIENTINITIALGUESS Select Newton seed for a transient step.
if isFirstStep && string(options.TransientInitMethod) == "Poweron"
    initialGuess = [];
else
    initialGuess = previousSolution;
end
end
