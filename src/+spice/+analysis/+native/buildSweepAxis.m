function sweepValues = buildSweepAxis(startValue, stopValue, stepValue)
% BUILDSWEEPAXIS Build inclusive DC sweep values with SPICE-style tolerance.
stepValue = double(stepValue);
if stepValue == 0
    error('spice:analysis:native:BadSweepStep', 'DC sweep step must be non-zero.');
end

sampleCount = floor((stopValue - startValue) / stepValue + 0.5) + 1;
if sampleCount < 1
    sampleCount = 1;
end

sweepValues = startValue + (0:sampleCount - 1) * stepValue;
if stepValue > 0
    sweepValues = sweepValues(sweepValues <= stopValue + abs(stepValue) * 1e-9);
else
    sweepValues = sweepValues(sweepValues >= stopValue - abs(stepValue) * 1e-9);
end
end
