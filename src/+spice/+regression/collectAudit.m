function [audit, hspiceWaveform] = collectAudit(entry, rootDir, circuit, nativeResult, legacyResult)
% COLLECTAUDIT Attach optional HSPICE operating-point and waveform audits.
audit = struct( ...
    'available', false, ...
    'sourcePath', "", ...
    'parsedBlockCount', 0, ...
    'hspiceOperatingPointNodeCount', 0, ...
    'nativeOperatingPoint', struct(), ...
    'legacyOperatingPoint', struct(), ...
    'waveformSourcePath', "", ...
    'nativeWaveform', spice.regression.emptyHspiceWaveformSummary(), ...
    'legacyWaveform', spice.regression.emptyHspiceWaveformSummary(), ...
    'notes', {{}});
hspiceWaveform = spice.regression.emptyHspiceWaveformSummary();

operatingPointAudit = entry.operatingPointAudit;
if string(operatingPointAudit.kind) == "hspiceLis"
    lisPath = fullfile(rootDir, operatingPointAudit.path);
    if isfile(lisPath)
        parsed = spice.regression.parseHspiceLis(lisPath);
        audit.available = true;
        audit.sourcePath = string(lisPath);
        audit.parsedBlockCount = numel(parsed.analysisBlocks);
        audit.hspiceOperatingPointNodeCount = numel(parsed.operatingPoint.nodeIds);
        audit.nativeOperatingPoint = compareAgainstHspiceOperatingPoint(nativeResult, parsed);
        audit.legacyOperatingPoint = compareAgainstHspiceOperatingPoint(legacyResult, parsed);
        audit.notes = appendOperatingPointAuditNote(audit);
    else
        audit.notes{end + 1} = sprintf('HSPICE operating-point audit file missing: %s', lisPath);
    end
end

waveformAudit = entry.waveformAudit;
if string(waveformAudit.kind) == "hspiceTr0"
    tr0Path = fullfile(rootDir, waveformAudit.path);
    if isfile(tr0Path)
        tr0 = spice.regression.parseHspiceTr0(tr0Path);
        hspiceResult = spice.regression.buildHspiceTransientReference(circuit, tr0);
        audit.available = true;
        audit.waveformSourcePath = string(tr0Path);
        audit.nativeWaveform = compareAgainstHspiceWaveform(nativeResult, hspiceResult, entry, circuit);
        audit.legacyWaveform = compareAgainstHspiceWaveform(legacyResult, hspiceResult, entry, circuit);
        hspiceWaveform = audit.nativeWaveform;
        audit.notes = appendWaveformAuditNote(audit);
    else
        audit.notes{end + 1} = sprintf('HSPICE waveform audit file missing: %s', tr0Path);
    end
end
end

function notes = appendOperatingPointAuditNote(audit)
notes = audit.notes;
if audit.nativeOperatingPoint.available && audit.legacyOperatingPoint.available
    if audit.nativeOperatingPoint.maxAbsError < audit.legacyOperatingPoint.maxAbsError
        notes{end + 1} = 'Native operating point is currently closer to HSPICE than legacy for this audit file.';
    elseif audit.nativeOperatingPoint.maxAbsError > audit.legacyOperatingPoint.maxAbsError
        notes{end + 1} = 'Legacy operating point is currently closer to HSPICE than native for this audit file.';
    end
end
end

function notes = appendWaveformAuditNote(audit)
notes = audit.notes;
if audit.nativeWaveform.available && audit.legacyWaveform.available
    if audit.nativeWaveform.maxVoltageAbsError < audit.legacyWaveform.maxVoltageAbsError
        notes{end + 1} = 'Native transient node voltages are currently closer to HSPICE than legacy.';
    elseif audit.nativeWaveform.maxVoltageAbsError > audit.legacyWaveform.maxVoltageAbsError
        notes{end + 1} = 'Legacy transient node voltages are currently closer to HSPICE than native.';
    end
end
end

function summary = compareAgainstHspiceOperatingPoint(result, parsed)
summary = struct('available', false, 'maxAbsError', NaN, 'maxRelError', NaN, 'maxErrorNode', NaN, 'nodeCount', 0);
if isempty(result)
    return;
end

normalized = spice.regression.normalizeResult(result, "all");
if isempty(normalized.operatingPoint.nodeIds) || isempty(parsed.operatingPoint.nodeIds)
    return;
end

commonNodes = intersect(normalized.operatingPoint.nodeIds, parsed.operatingPoint.nodeIds, 'stable');
if isempty(commonNodes)
    return;
end

nativeValues = normalized.operatingPoint.values(ismember(normalized.operatingPoint.nodeIds, commonNodes));
hspiceValues = parsed.operatingPoint.values(ismember(parsed.operatingPoint.nodeIds, commonNodes));
absError = abs(nativeValues - hspiceValues);
relError = absError ./ max(abs(hspiceValues), 1e-18);
[maxAbsError, maxIndex] = max(absError);
summary.available = true;
summary.maxAbsError = maxAbsError;
summary.maxRelError = max(relError);
summary.maxErrorNode = commonNodes(maxIndex);
summary.nodeCount = numel(commonNodes);
end

function summary = compareAgainstHspiceWaveform(result, hspiceResult, entry, circuit)
summary = spice.regression.emptyHspiceWaveformSummary();
if isempty(hspiceResult.signals)
    return;
end

summary.available = true;
if isempty(result)
    summary.notes(end + 1, 1) = "native result unavailable for HSPICE waveform comparison";
    return;
end

waveEntry = entry;
waveEntry.probeSelection = nodeVoltageProbeSelection(circuit);
if isempty(waveEntry.probeSelection)
    return;
end

comparison = spice.regression.compareResults(result, hspiceResult, waveEntry);
summary.passed = comparison.passed;
summary.signalSummaries = comparison.signalSummaries;
summary.missingSignals = string(comparison.missingSignals);
summary.extraSignals = string(comparison.extraSignals);
summary.notes = string(comparison.notes);
summary.maxVoltageAbsError = comparison.maxAbsError;
if ~isempty(comparison.signalSummaries)
    [~, maxIndex] = max([comparison.signalSummaries.maxAbsError]);
    summary.maxErrorSignal = string(comparison.signalSummaries(maxIndex).name);
    summary.maxErrorTime = comparison.signalSummaries(maxIndex).maxErrorAxisValue;
end
end

function names = nodeVoltageProbeSelection(circuit)
names = strings(0, 1);
for idx = 1:numel(circuit.Probes)
    probe = circuit.Probes{idx};
    if probe.Kind == "nodeVoltage"
        names(end + 1, 1) = probe.DisplayName; %#ok<AGROW>
    end
end
end
