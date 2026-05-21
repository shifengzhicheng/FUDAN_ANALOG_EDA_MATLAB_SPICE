function writeCaseReport(caseOutputDir, entry, caseReport, nativeResult, legacyResult, emitPlots)
% WRITECASEREPORT Write machine-readable and human-readable regression reports.
summaryPath = fullfile(caseOutputDir, 'summary.json');
diffPath = fullfile(caseOutputDir, 'signal_diff.csv');
hspiceDiffPath = fullfile(caseOutputDir, 'hspice_waveform_diff.csv');
maxErrorPath = fullfile(caseOutputDir, 'max_error.csv');
backendSummaryPath = fullfile(caseOutputDir, 'backend_summary.txt');

summaryStruct = struct( ...
    'caseName', entry.caseName, ...
    'analysisType', entry.analysisType, ...
    'netlistPath', string(entry.netlistPath), ...
    'baseline', entry.baseline, ...
    'expectedFail', entry.expectedFail, ...
    'passed', caseReport.passed, ...
    'comparison', caseReport.comparison, ...
    'audit', caseReport.audit);
writeJson(summaryPath, summaryStruct);
writeSignalDiffCsv(diffPath, caseReport.comparison.signalSummaries);
writeSignalDiffCsv(hspiceDiffPath, caseReport.comparison.hspiceWaveform.signalSummaries);
writeMaxErrorCsv(maxErrorPath, caseReport.comparison);
writeBackendSummary(backendSummaryPath, caseReport, nativeResult, legacyResult);

if emitPlots && ~isempty(nativeResult) && ~isempty(legacyResult)
    writeDiffPlots(fullfile(caseOutputDir, 'plots'), nativeResult, legacyResult, entry);
end
end

function writeJson(outputPath, value)
fid = fopen(outputPath, 'w');
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(spice.output.toSerializable(value)), 'char');
clear cleanup
end

function writeSignalDiffCsv(outputPath, summaries)
fid = fopen(outputPath, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'signal_name,kind,domain,align_mode,passed,max_abs_error,max_rel_error,max_phase_deg_error,max_error_axis_value\n');
for idx = 1:numel(summaries)
    item = summaries(idx);
    fprintf(fid, '%s,%s,%s,%s,%d,%.15g,%.15g,%.15g,%.15g\n', ...
        escapeCsv(item.name), escapeCsv(item.kind), escapeCsv(item.domain), escapeCsv(item.alignMode), item.passed, ...
        item.maxAbsError, item.maxRelError, item.maxPhaseDegError, item.maxErrorAxisValue);
end
clear cleanup
end

function writeMaxErrorCsv(outputPath, comparison)
fid = fopen(outputPath, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'category,max_abs_error,max_rel_error,reference\n');
fprintf(fid, 'overall,%.15g,%.15g,%s\n', comparison.maxAbsError, comparison.maxRelError, escapeCsv(comparison.backendReason));
if comparison.operatingPoint.available
    fprintf(fid, 'operating_point,%.15g,%.15g,node_%g\n', ...
        comparison.operatingPoint.maxAbsError, comparison.operatingPoint.maxRelError, comparison.operatingPoint.maxErrorNode);
end
if comparison.hspiceWaveform.available
    fprintf(fid, 'hspice_waveform,%.15g,%.15g,%s@%.15g\n', ...
        comparison.hspiceWaveform.maxVoltageAbsError, NaN, ...
        escapeCsv(comparison.hspiceWaveform.maxErrorSignal), comparison.hspiceWaveform.maxErrorTime);
end
clear cleanup
end

function writeBackendSummary(outputPath, caseReport, nativeResult, legacyResult)
fid = fopen(outputPath, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'case=%s\n', caseReport.caseName);
fprintf(fid, 'analysis=%s\n', caseReport.analysisType);
fprintf(fid, 'passed=%d\n', caseReport.passed);
fprintf(fid, 'expected_fail=%d\n', caseReport.expectedFail);
fprintf(fid, 'comparison_backend=%s\n', caseReport.comparison.backend);
fprintf(fid, 'comparison_backend_reason=%s\n', caseReport.comparison.backendReason);
if ~isempty(nativeResult)
    fprintf(fid, 'native_backend=%s\n', string(nativeResult.meta.backend));
    fprintf(fid, 'native_backend_reason=%s\n', string(nativeResult.meta.backendReason));
end
if ~isempty(legacyResult)
    fprintf(fid, 'legacy_backend=%s\n', string(legacyResult.meta.backend));
    fprintf(fid, 'legacy_backend_reason=%s\n', string(legacyResult.meta.backendReason));
end
fprintf(fid, 'hspice_waveform_available=%d\n', caseReport.comparison.hspiceWaveform.available);
fprintf(fid, 'hspice_waveform_passed=%d\n', caseReport.comparison.hspiceWaveform.passed);
fprintf(fid, 'hspice_waveform_max_voltage_abs_error=%.15g\n', caseReport.comparison.hspiceWaveform.maxVoltageAbsError);
fprintf(fid, 'hspice_waveform_max_error_signal=%s\n', string(caseReport.comparison.hspiceWaveform.maxErrorSignal));
fprintf(fid, 'hspice_waveform_max_error_time=%.15g\n', caseReport.comparison.hspiceWaveform.maxErrorTime);
for idx = 1:numel(caseReport.comparison.notes)
    fprintf(fid, 'note_%d=%s\n', idx, string(caseReport.comparison.notes(idx)));
end
for idx = 1:numel(caseReport.audit.notes)
    fprintf(fid, 'audit_note_%d=%s\n', idx, string(caseReport.audit.notes{idx}));
end
clear cleanup
end

function writeDiffPlots(plotDir, nativeResult, legacyResult, entry)
if ~isfolder(plotDir)
    mkdir(plotDir);
end
native = spice.regression.normalizeResult(nativeResult, entry.probeSelection);
legacy = spice.regression.normalizeResult(legacyResult, entry.probeSelection);
commonSignals = intersect(native.signalNames, legacy.signalNames, 'stable');
for idx = 1:numel(commonSignals)
    signalName = commonSignals(idx);
    nativeSignal = native.signals(native.signalNames == signalName);
    legacySignal = legacy.signals(legacy.signalNames == signalName);
    outputPath = fullfile(plotDir, [spice.output.sanitizeFileName(signalName) '.png']);
    writeOneDiffPlot(nativeResult.analysisType, nativeResult.axis, nativeSignal, legacyResult.axis, legacySignal, outputPath);
end
end

function writeOneDiffPlot(analysisType, candidateAxis, candidateSignal, baselineAxis, baselineSignal, outputPath)
figureHandle = figure('Visible', 'off');
cleanup = onCleanup(@() closeIfNeeded(figureHandle));
if string(candidateSignal.domain) == "complex"
    candidateValues = magnitudeForPlot(candidateSignal);
    baselineValues = interpolateForPlot(candidateAxis.values, baselineAxis.values, magnitudeForPlot(baselineSignal));
    if string(candidateAxis.scale) == "dec"
        semilogx(candidateAxis.values, candidateValues, 'LineWidth', 1.2);
        hold on;
        semilogx(candidateAxis.values, baselineValues, '--', 'LineWidth', 1.2);
    else
        plot(candidateAxis.values, candidateValues, 'LineWidth', 1.2);
        hold on;
        plot(candidateAxis.values, baselineValues, '--', 'LineWidth', 1.2);
    end
    ylabel('|signal|');
else
    candidateValues = real(candidateSignal.values);
    baselineValues = interpolateForPlot(candidateAxis.values, baselineAxis.values, real(baselineSignal.values));
    plot(candidateAxis.values, candidateValues, 'LineWidth', 1.2);
    hold on;
    plot(candidateAxis.values, baselineValues, '--', 'LineWidth', 1.2);
    ylabel(candidateSignal.unit);
end
xlabel(candidateAxis.name);
title(sprintf('%s native vs legacy (%s)', candidateSignal.name, analysisType));
legend({'native', 'legacy'}, 'Interpreter', 'none', 'Location', 'best');
grid on;
saveas(figureHandle, outputPath);
clear cleanup
end

function values = interpolateForPlot(candidateAxis, baselineAxis, baselineValues)
candidateAxis = candidateAxis(:).';
baselineAxis = baselineAxis(:).';
baselineValues = baselineValues(:).';
sampleCount = min(numel(baselineAxis), numel(baselineValues));
baselineAxis = baselineAxis(1:sampleCount);
baselineValues = baselineValues(1:sampleCount);
if isempty(candidateAxis) || isempty(baselineAxis) || isempty(baselineValues)
    values = NaN(size(candidateAxis));
    return;
end
if numel(candidateAxis) <= 1 || numel(baselineAxis) <= 1 || (numel(candidateAxis) == numel(baselineAxis) && all(abs(candidateAxis - baselineAxis) < 1e-15))
    values = baselineValues;
    return;
end
values = interp1(baselineAxis, baselineValues, candidateAxis, 'linear', 'extrap');
end

function values = magnitudeForPlot(signal)
if ~isempty(signal.magnitude)
    values = signal.magnitude;
else
    values = abs(signal.values);
end
end

function closeIfNeeded(figureHandle)
if ishghandle(figureHandle)
    close(figureHandle);
end
end

function value = escapeCsv(text)
value = strrep(char(string(text)), ',', ';');
end
