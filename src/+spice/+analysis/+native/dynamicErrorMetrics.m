function [lteMetric, tolerance, voltageErrorNorm, currentErrorNorm] = dynamicErrorMetrics( ...
        fullSolution, halfSolution, nativeCircuit, options, method, errorNodeIndices)
% DYNAMICERRORMETRICS Compare full-step and two half-step transient states.
if method ~= "TR"
    tolerance = dynamicTolerance(halfSolution, options.ErrorTolerance);
    lteMetric = norm(halfSolution - fullSolution, inf);
    voltageErrorNorm = NaN;
    currentErrorNorm = NaN;
    return;
end

delta = abs(halfSolution - fullSolution) / 3;
nodeCount = numel(nativeCircuit.NodeIds);
if nargin < 6 || isempty(errorNodeIndices)
    errorNodeIndices = (1:nodeCount).';
else
    errorNodeIndices = errorNodeIndices(:);
    errorNodeIndices = errorNodeIndices(errorNodeIndices >= 1 & errorNodeIndices <= nodeCount);
    if isempty(errorNodeIndices)
        errorNodeIndices = (1:nodeCount).';
    end
end

fullNodes = abs(fullSolution(errorNodeIndices));
halfNodes = abs(halfSolution(errorNodeIndices));
nodeReference = max(max(fullNodes, halfNodes), 1);
effectiveRelTol = spice.analysis.native.dynamicTrRelativeTolerance(options);
nodeTolerance = 1e-6 + effectiveRelTol .* nodeReference;
if nodeCount > 0
    voltageErrorNorm = max(delta(errorNodeIndices) ./ nodeTolerance);
else
    voltageErrorNorm = 0;
end

if numel(delta) > nodeCount
    fullCurrents = abs(fullSolution(nodeCount + 1:end));
    halfCurrents = abs(halfSolution(nodeCount + 1:end));
    currentReference = max(max(fullCurrents, halfCurrents), 1);
    currentTolerance = 1e-9 + 10 * effectiveRelTol .* currentReference;
    currentErrorNorm = max(delta(nodeCount + 1:end) ./ currentTolerance);
else
    currentErrorNorm = 0;
end

lteMetric = voltageErrorNorm;
tolerance = 1;
end

function tolerance = dynamicTolerance(solution, baseTolerance)
reference = max(1, norm(solution, inf));
tolerance = max(1e3 * baseTolerance, 256 * baseTolerance * reference);
end
