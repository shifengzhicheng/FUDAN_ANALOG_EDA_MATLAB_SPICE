function comparison = compareResults(candidateResult, baselineResult, entry)
% COMPARERESULTS Compare native output against the configured baseline.
% The comparison uses one normalized signal contract, records per-signal
% maxima, and keeps backend metadata alongside pass/fail so reports stay
% actionable instead of only returning a boolean.
candidate = spice.regression.normalizeResult(candidateResult, entry.probeSelection);
baseline = spice.regression.normalizeResult(baselineResult, entry.probeSelection);

candidateNames = candidate.signalNames;
baselineNames = baseline.signalNames;
missingSignals = setdiff(baselineNames, candidateNames);
extraSignals = setdiff(candidateNames, baselineNames);
commonSignals = intersect(candidateNames, baselineNames, 'stable');

signalSummaries = repmat(struct( ...
    'name', "", ...
    'kind', "", ...
    'domain', "real", ...
    'alignMode', "exact", ...
    'passed', false, ...
    'maxAbsError', NaN, ...
    'maxRelError', NaN, ...
    'maxPhaseDegError', NaN, ...
    'maxErrorAxisValue', NaN), 0, 1);

for idx = 1:numel(commonSignals)
    signalName = commonSignals(idx);
    candidateSignal = candidate.signals(candidateNames == signalName);
    baselineSignal = baseline.signals(baselineNames == signalName);
    signalSummaries(end + 1, 1) = compareSignal(candidateSignal, baselineSignal, candidate.analysisType, entry.toleranceProfile); %#ok<AGROW>
end

operatingPoint = compareOperatingPoint(candidate.operatingPoint, baseline.operatingPoint, entry.toleranceProfile);
notes = strings(0, 1);
if ~isempty(missingSignals)
    notes(end + 1, 1) = "missing baseline signals in native result: " + strjoin(missingSignals, ", "); %#ok<AGROW>
end
if ~isempty(extraSignals)
    notes(end + 1, 1) = "extra native-only signals: " + strjoin(extraSignals, ", "); %#ok<AGROW>
end

maxAbsError = maxOrNaN([signalSummaries.maxAbsError, operatingPoint.maxAbsError]);
maxRelError = maxOrNaN([signalSummaries.maxRelError, operatingPoint.maxRelError]);
passedSignals = all([signalSummaries.passed]);
passedOperatingPoint = operatingPoint.passed;
passed = isempty(missingSignals) && isempty(extraSignals) && passedSignals && passedOperatingPoint;

comparison = struct( ...
    'passed', passed, ...
    'maxAbsError', maxAbsError, ...
    'maxRelError', maxRelError, ...
    'signalSummaries', signalSummaries, ...
    'missingSignals', missingSignals, ...
    'extraSignals', extraSignals, ...
    'operatingPoint', operatingPoint, ...
    'backend', string(candidateResult.meta.backend), ...
    'backendReason', string(candidateResult.meta.backendReason), ...
    'newtonSummary', candidateResult.meta.newton, ...
    'notes', notes);
end

function summary = compareSignal(candidateSignal, baselineSignal, analysisType, tolerances)
[candidateAxis, baselineValues, alignMode] = alignBaseline(candidateSignal.axisValues, baselineSignal.axisValues, baselineSignal.values);
summary = struct( ...
    'name', string(candidateSignal.name), ...
    'kind', string(candidateSignal.kind), ...
    'domain', string(candidateSignal.domain), ...
    'alignMode', string(alignMode), ...
    'passed', false, ...
    'maxAbsError', NaN, ...
    'maxRelError', NaN, ...
    'maxPhaseDegError', NaN, ...
    'maxErrorAxisValue', NaN);

if string(candidateSignal.domain) == "complex"
    [baselineMagnitude, baselinePhaseDeg, phaseAlignMode] = alignComplexParts(candidateSignal.axisValues, baselineSignal.axisValues, baselineSignal);
    candidateMagnitude = candidateSignal.magnitude;
    if isempty(candidateMagnitude)
        candidateMagnitude = abs(candidateSignal.values);
    end
    candidatePhaseDeg = candidateSignal.phaseDeg;
    if isempty(candidatePhaseDeg)
        candidatePhaseDeg = rad2deg(angle(candidateSignal.values));
    end
    magnitudeAbsError = abs(candidateMagnitude - baselineMagnitude);
    magnitudeRelError = safeRelativeError(candidateMagnitude, baselineMagnitude);
    phaseDegError = abs(wrapTo180Local(candidatePhaseDeg - baselinePhaseDeg));
    [summary.maxAbsError, maxIndex] = max(magnitudeAbsError);
    summary.maxRelError = maxOrNaN(magnitudeRelError);
    summary.maxPhaseDegError = maxOrNaN(phaseDegError);
    summary.maxErrorAxisValue = axisValueAt(candidateAxis, maxIndex);
    summary.alignMode = string(phaseAlignMode);
    summary.passed = summary.maxRelError <= tolerances.magnitudeRel && summary.maxPhaseDegError <= tolerances.phaseAbsDeg;
else
    absError = abs(candidateSignal.values - baselineValues);
    relError = safeRelativeError(candidateSignal.values, baselineValues);
    [summary.maxAbsError, maxIndex] = max(absError);
    summary.maxRelError = maxOrNaN(relError);
    summary.maxErrorAxisValue = axisValueAt(candidateAxis, maxIndex);
    summary.passed = summary.maxAbsError <= toleranceForRealSignal(string(analysisType), string(candidateSignal.kind), tolerances);
end
end

function operatingPoint = compareOperatingPoint(candidateOp, baselineOp, tolerances)
operatingPoint = struct( ...
    'available', false, ...
    'passed', true, ...
    'nodeIds', zeros(0, 1), ...
    'maxAbsError', NaN, ...
    'maxRelError', NaN, ...
    'maxErrorNode', NaN);
if isempty(candidateOp.nodeIds) || isempty(baselineOp.nodeIds)
    return;
end
commonNodes = intersect(candidateOp.nodeIds, baselineOp.nodeIds, 'stable');
if isempty(commonNodes)
    return;
end
candidateValues = candidateOp.values(ismember(candidateOp.nodeIds, commonNodes));
baselineValues = baselineOp.values(ismember(baselineOp.nodeIds, commonNodes));
absError = abs(candidateValues - baselineValues);
relError = safeRelativeError(candidateValues, baselineValues);
[maxAbsError, maxIndex] = max(absError);
operatingPoint.available = true;
operatingPoint.nodeIds = commonNodes;
operatingPoint.maxAbsError = maxAbsError;
operatingPoint.maxRelError = maxOrNaN(relError);
operatingPoint.maxErrorNode = commonNodes(maxIndex);
operatingPoint.passed = maxAbsError <= tolerances.nodeAbs;
end

function [candidateAxis, baselineValues, alignMode] = alignBaseline(candidateAxis, baselineAxis, baselineValues)
if numel(candidateAxis) <= 1 || numel(baselineAxis) <= 1
    alignMode = "scalar";
    baselineValues = baselineValues(:).';
    candidateAxis = candidateAxis(:).';
    return;
end

candidateAxis = candidateAxis(:).';
baselineAxis = baselineAxis(:).';
if numel(candidateAxis) == numel(baselineAxis) && max(abs(candidateAxis - baselineAxis)) <= max(1e-15, 1e-12 * max(1, max(abs(candidateAxis))))
    alignMode = "exact";
    baselineValues = baselineValues(:).';
    return;
end

alignMode = "interp";
if ~isreal(baselineValues)
    baselineValues = interp1(baselineAxis, real(baselineValues), candidateAxis, 'linear', 'extrap') + ...
        1i * interp1(baselineAxis, imag(baselineValues), candidateAxis, 'linear', 'extrap');
else
    baselineValues = interp1(baselineAxis, baselineValues, candidateAxis, 'linear', 'extrap');
end
end

function [baselineMagnitude, baselinePhaseDeg, alignMode] = alignComplexParts(candidateAxis, baselineAxis, baselineSignal)
[~, baselineValues, alignMode] = alignBaseline(candidateAxis, baselineAxis, baselineSignal.values);
baselineMagnitude = abs(baselineValues);
baselinePhaseDeg = rad2deg(angle(baselineValues));
end

function relError = safeRelativeError(candidateValues, baselineValues)
denom = max(abs(baselineValues), 1e-18);
relError = abs(candidateValues - baselineValues) ./ denom;
end

function tol = toleranceForRealSignal(analysisType, signalKind, tolerances)
switch analysisType
    case "trans"
        if signalKind == "deviceCurrent"
            tol = tolerances.waveformCurrentAbs;
        else
            tol = tolerances.waveformAbs;
        end
    otherwise
        if signalKind == "deviceCurrent"
            tol = tolerances.currentAbs;
        else
            tol = tolerances.nodeAbs;
        end
end
end

function value = axisValueAt(axisValues, index)
if isempty(axisValues) || isempty(index) || isnan(index)
    value = NaN;
elseif numel(axisValues) < index
    value = axisValues(end);
else
    value = axisValues(index);
end
end

function wrapped = wrapTo180Local(values)
wrapped = mod(values + 180, 360) - 180;
end

function value = maxOrNaN(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = max(values);
end
end
