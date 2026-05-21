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
[sourceText, sourceName, ~] = spice.util.readInput(entry.netlistPath, "file");
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
[audit, comparison.hspiceWaveform] = spice.regression.collectAudit(entry, rootDir, circuit, nativeResult, legacyResult);

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
    spice.regression.writeCaseArtifacts(caseOutputDir, nativeResult, legacyResult, opts.EmitPlots);
end
if opts.WriteReports
    spice.regression.writeCaseReport(caseOutputDir, entry, caseReport, nativeResult, legacyResult, opts.EmitPlots);
end
end

function [result, errorInfo] = collectLegacyResult(circuit, ir, options) %#ok<INUSD>
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

function [result, errorInfo] = collectNativeResult(circuit, ir, options) %#ok<INUSD>
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
    comparison = spice.regression.failedComparison("legacy baseline failed: " + legacyError.identifier + " " + legacyError.message, legacyError.identifier);
    return;
end
if nativeError.raised
    comparison = spice.regression.failedComparison("native execution failed: " + nativeError.identifier + " " + nativeError.message, nativeError.reason);
    return;
end

comparison = spice.regression.compareResults(nativeResult, legacyResult, entry);
comparison.hspiceWaveform = spice.regression.emptyHspiceWaveformSummary();
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
