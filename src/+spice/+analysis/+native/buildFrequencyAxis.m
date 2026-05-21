function freq = buildFrequencyAxis(params)
% BUILDFREQUENCYAXIS Build the AC analysis frequency grid.
switch lower(string(params.mode))
    case "dec"
        startValue = log10(params.startFreq);
        stopValue = log10(params.stopFreq);
        sampleCount = max(2, floor((stopValue - startValue) * params.points) + 1);
        freq = logspace(startValue, stopValue, sampleCount);
    otherwise
        freq = linspace(params.startFreq, params.stopFreq, params.points);
end
end
