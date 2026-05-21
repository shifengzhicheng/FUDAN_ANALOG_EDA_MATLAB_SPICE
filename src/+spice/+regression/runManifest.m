function summary = runManifest(opts)
% RUNMANIFEST Execute the full native-vs-legacy regression matrix.
% The runner collects native and forced-legacy results, compares them with
% one tolerance policy, emits human-readable artifacts under runs/regression,
% and attaches HSPICE operating-point audit data when a .lis file exists.
arguments
    opts.RootDir {mustBeTextScalar} = ""
    opts.OutputRoot {mustBeTextScalar} = ""
    opts.IncludeCases string = strings(0, 1)
    opts.EmitPlots (1,1) logical = true
    opts.WriteCaseArtifacts (1,1) logical = false
    opts.WriteReports (1,1) logical = true
end

rootDir = resolveRootDir(opts.RootDir);
outputRoot = resolveOutputRoot(rootDir, opts.OutputRoot);
entries = spice.regression.manifest(rootDir);
if ~isempty(opts.IncludeCases)
    mask = ismember([entries.caseName], string(opts.IncludeCases));
    entries = entries(mask);
end

caseReports = cell(numel(entries), 1);
for idx = 1:numel(entries)
    caseReports{idx, 1} = runEntry(entries(idx), rootDir, outputRoot, opts);
end
caseReports = vertcat(caseReports{:});

unexpectedFailures = [caseReports.unexpectedFailure];
expectedFailures = [caseReports.expectedFail] & ~[caseReports.passed];
unexpectedPasses = [caseReports.expectedFail] & [caseReports.passed];
summary = struct( ...
    'passed', ~any(unexpectedFailures), ...
    'caseReports', caseReports, ...
    'totalCases', numel(caseReports), ...
    'passedCount', sum([caseReports.passed]), ...
    'unexpectedFailureCount', sum(unexpectedFailures), ...
    'expectedFailureCount', sum(expectedFailures), ...
    'unexpectedPassCount', sum(unexpectedPasses), ...
    'outputRoot', string(outputRoot));
end

function caseReport = runEntry(entry, rootDir, outputRoot, opts)
[sourceText, sourceName, sourcePath] = spice.util.readInput(entry.netlistPath, "file");
spice.util.ensureLegacyPath();
options = spice.model.defaultOptions();
options.OutputDir = "";
options.EmitPlots = false;
options.WriteJSON = false;
options.WriteMAT = false;
options.WriteCSV = false;
options = applyEntryOptions(options, entry);

circuit = spice.parser.parseNetlist(sourceText, SourceName=sourceName);
ir = spice.ir.build(circuit);
caseOutputDir = fullfile(outputRoot, char(entry.caseName), char(entry.analysisType));
if ~isfolder(caseOutputDir)
    mkdir(caseOutputDir);
end

[legacyResult, legacyError] = collectLegacyResult(circuit, ir, options);
[nativeResult, nativeError] = collectNativeResult(circuit, ir, options);
comparison = buildComparison(nativeResult, nativeError, legacyResult, legacyError, entry);
[audit, comparison.hspiceWaveform] = collectAudit(entry, rootDir, circuit, nativeResult, legacyResult);

passed = determinePassed(entry, comparison);
unexpectedFailure = ~passed && ~entry.expectedFail;

caseReport = struct( ...
    'caseName', entry.caseName, ...
    'analysisType', entry.analysisType, ...
    'passed', passed, ...
    'expectedFail', entry.expectedFail, ...
    'unexpectedFailure', unexpectedFailure, ...
    'comparison', comparison, ...
    'audit', audit, ...
    'outputDir', string(caseOutputDir));

if opts.WriteCaseArtifacts
    writeCaseArtifacts(caseOutputDir, nativeResult, legacyResult, opts.EmitPlots);
end
if opts.WriteReports
    writeReport(caseOutputDir, entry, caseReport, nativeResult, legacyResult, opts.EmitPlots);
end
end

function [result, errorInfo] = collectLegacyResult(circuit, ir, options)
errorInfo = struct('raised', false, 'identifier', "", 'message', "");
try
    [~, result] = evalc('spice.analysis.runLegacy(circuit, ir, options, "forced_legacy_baseline")');
catch err
    result = [];
    errorInfo = struct('raised', true, 'identifier', string(err.identifier), 'message', string(err.message));
end
end

function options = applyEntryOptions(options, entry)
switch string(entry.caseName)
    case {"bufferTransDynamic", "bjtAmplifierTransDynamic"}
        options.TransientStepMode = "Dynamic";
        options.TransientMethod = "BE";
    case {"bufferTransDynamicTR", "bjtAmplifierTransDynamicTR"}
        options.TransientStepMode = "Dynamic";
        options.TransientMethod = "TR";
        options.TransientInitMethod = "DC";
    case {"bufferShoot", "bjtAmplifierShoot", "dbmixerShoot", "diftestShoot"}
        options.TransientStepMode = "Fix";
        options.TransientMethod = "BE";
    otherwise
        % Keep the default options for all other regression entries.
end
end

function [result, errorInfo] = collectNativeResult(circuit, ir, options)
errorInfo = struct('raised', false, 'identifier', "", 'message', "", 'reason', "native_success");
[canUseNative, ~, reason] = spice.analysis.native.canRun(circuit, options);
if ~canUseNative
    result = [];
    errorInfo = struct('raised', true, 'identifier', "spice:regression:NativeUnavailable", 'message', "Native backend cannot run this case.", 'reason', string(reason));
    return;
end
try
    [~, result] = evalc('spice.analysis.native.run(circuit, ir, options)');
catch err
    result = [];
    errorInfo = struct('raised', true, 'identifier', string(err.identifier), 'message', string(err.message), 'reason', "native_runtime_error");
end
end

function comparison = buildComparison(nativeResult, nativeError, legacyResult, legacyError, entry)
if legacyError.raised
    comparison = failedComparison("legacy baseline failed: " + legacyError.identifier + " " + legacyError.message, legacyError.identifier);
    return;
end
if nativeError.raised
    comparison = failedComparison("native execution failed: " + nativeError.identifier + " " + nativeError.message, nativeError.reason);
    return;
end

comparison = spice.regression.compareResults(nativeResult, legacyResult, entry);
comparison.hspiceWaveform = emptyHspiceWaveformSummary();
comparison.relaxedOnly = isRelaxedTransientOnly(nativeResult);
if comparison.relaxedOnly
    comparison.passed = false;
    comparison.notes(end + 1, 1) = "Transient result used relaxed convergence and is not accepted by regression.";
end
end

function tf = isRelaxedTransientOnly(result)
tf = false;
if isempty(result) || string(result.analysisType) ~= "trans" || ~isfield(result.meta, 'newton')
    return;
end
newton = result.meta.newton;
if isstruct(newton) && isfield(newton, 'relaxedUsed')
    tf = logical(newton.relaxedUsed);
end
end

function passed = determinePassed(entry, comparison)
if comparison.relaxedOnly
    passed = false;
    return;
end
if string(entry.waveformAudit.kind) == "hspiceTr0"
    passed = comparison.hspiceWaveform.available && comparison.hspiceWaveform.passed;
else
    passed = comparison.passed;
end
end

function summary = emptyHspiceWaveformSummary()
summary = struct( ...
    'available', false, ...
    'passed', false, ...
    'maxVoltageAbsError', NaN, ...
    'maxErrorSignal', "", ...
    'maxErrorTime', NaN, ...
    'signalSummaries', repmat(struct( ...
        'name', "", 'kind', "", 'domain', "", 'alignMode', "", ...
        'passed', false, 'maxAbsError', NaN, 'maxRelError', NaN, ...
        'maxPhaseDegError', NaN, 'maxErrorAxisValue', NaN), 0, 1), ...
    'missingSignals', strings(0, 1), ...
    'extraSignals', strings(0, 1), ...
    'notes', strings(0, 1));
end

function comparison = failedComparison(message, backendReason)
comparison = struct( ...
    'passed', false, ...
    'maxAbsError', NaN, ...
    'maxRelError', NaN, ...
    'signalSummaries', repmat(struct( ...
        'name', "", 'kind', "", 'domain', "", 'alignMode', "", ...
        'passed', false, 'maxAbsError', NaN, 'maxRelError', NaN, ...
        'maxPhaseDegError', NaN, 'maxErrorAxisValue', NaN), 0, 1), ...
    'missingSignals', {{}}, ...
    'extraSignals', {{}}, ...
    'operatingPoint', struct('available', false, 'passed', false, 'nodeIds', zeros(0, 1), 'maxAbsError', NaN, 'maxRelError', NaN, 'maxErrorNode', NaN), ...
    'backend', "native", ...
    'backendReason', string(backendReason), ...
    'newtonSummary', struct(), ...
    'notes', string(message), ...
    'hspiceWaveform', emptyHspiceWaveformSummary(), ...
    'relaxedOnly', false);
end

function [audit, hspiceWaveform] = collectAudit(entry, rootDir, circuit, nativeResult, legacyResult)
audit = struct( ...
    'available', false, ...
    'sourcePath', "", ...
    'parsedBlockCount', 0, ...
    'hspiceOperatingPointNodeCount', 0, ...
    'nativeOperatingPoint', struct(), ...
    'legacyOperatingPoint', struct(), ...
    'waveformSourcePath', "", ...
    'nativeWaveform', emptyHspiceWaveformSummary(), ...
    'legacyWaveform', emptyHspiceWaveformSummary(), ...
    'notes', {{}});
hspiceWaveform = emptyHspiceWaveformSummary();

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
        if audit.nativeOperatingPoint.available && audit.legacyOperatingPoint.available
            if audit.nativeOperatingPoint.maxAbsError < audit.legacyOperatingPoint.maxAbsError
                audit.notes{end + 1} = 'Native operating point is currently closer to HSPICE than legacy for this audit file.';
            elseif audit.nativeOperatingPoint.maxAbsError > audit.legacyOperatingPoint.maxAbsError
                audit.notes{end + 1} = 'Legacy operating point is currently closer to HSPICE than native for this audit file.';
            end
        end
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
        if audit.nativeWaveform.available && audit.legacyWaveform.available
            if audit.nativeWaveform.maxVoltageAbsError < audit.legacyWaveform.maxVoltageAbsError
                audit.notes{end + 1} = 'Native transient node voltages are currently closer to HSPICE than legacy.';
            elseif audit.nativeWaveform.maxVoltageAbsError > audit.legacyWaveform.maxVoltageAbsError
                audit.notes{end + 1} = 'Legacy transient node voltages are currently closer to HSPICE than native.';
            end
        end
    else
        audit.notes{end + 1} = sprintf('HSPICE waveform audit file missing: %s', tr0Path);
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
summary = emptyHspiceWaveformSummary();
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

function writeCaseArtifacts(caseOutputDir, nativeResult, legacyResult, emitPlots)
if ~isempty(nativeResult)
    nativeResult.meta.acceptedByRegression = false;
    spice.output.emit(nativeResult, OutputDir=fullfile(caseOutputDir, 'native'), EmitPlots=emitPlots, WriteJSON=true, WriteMAT=true, WriteCSV=true);
end
if ~isempty(legacyResult)
    legacyResult.meta.acceptedByRegression = false;
    spice.output.emit(legacyResult, OutputDir=fullfile(caseOutputDir, 'legacy'), EmitPlots=emitPlots, WriteJSON=true, WriteMAT=true, WriteCSV=true);
end
end

function writeReport(caseOutputDir, entry, caseReport, nativeResult, legacyResult, emitPlots)
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
    emitDiffPlots(fullfile(caseOutputDir, 'plots'), nativeResult, legacyResult, entry);
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

function emitDiffPlots(plotDir, nativeResult, legacyResult, entry)
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
    candidateValues = candidateSignal.magnitude;
    baselineValues = interpolateForPlot(candidateAxis.values, baselineAxis.values, baselineSignal.magnitude);
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
if numel(candidateAxis) <= 1 || numel(baselineAxis) <= 1 || (numel(candidateAxis) == numel(baselineAxis) && all(abs(candidateAxis - baselineAxis) < 1e-15))
    values = baselineValues;
    return;
end
values = interp1(baselineAxis, baselineValues, candidateAxis, 'linear', 'extrap');
end

function closeIfNeeded(figureHandle)
if ishghandle(figureHandle)
    close(figureHandle);
end
end

function value = escapeCsv(text)
value = strrep(char(string(text)), ',', ';');
end

function rootDir = resolveRootDir(inputRoot)
if strlength(string(inputRoot)) > 0
    rootDir = char(string(inputRoot));
else
    regressionDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    rootDir = char(fileparts(regressionDir));
end
end

function outputRoot = resolveOutputRoot(rootDir, inputOutputRoot)
if strlength(string(inputOutputRoot)) > 0
    outputRoot = char(string(inputOutputRoot));
else
    outputRoot = fullfile(rootDir, 'runs', 'regression');
end
end
