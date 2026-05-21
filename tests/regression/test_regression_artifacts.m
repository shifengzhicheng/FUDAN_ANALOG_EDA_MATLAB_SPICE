function test_regression_artifacts()
% TEST_REGRESSION_ARTIFACTS Ensure one regression case emits diff plots.
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

summary = spice.regression.runManifest(RootDir=rootDir, IncludeCases='bufferAC', EmitPlots=true, WriteCaseArtifacts=false, WriteReports=true);
plotDir = fullfile(summary.outputRoot, 'bufferAC', 'ac', 'plots');
assert(isfolder(plotDir));
plotFiles = dir(fullfile(plotDir, '*.png'));
assert(~isempty(plotFiles));

assertComplexCsvBackfillsMagnitude();
assertComplexComparisonHandlesLengthMismatch();

disp('REGRESSION_ARTIFACTS_PASSED');
end

function assertComplexCsvBackfillsMagnitude()
outputDir = tempname();
mkdir(outputDir);
cleanup = onCleanup(@() cleanupDirectory(outputDir));

result = struct();
result.analysisType = "pz";
result.axis = struct('name', "root_index", 'values', [], 'unit', "", 'scale', "categorical");
result.signals = struct( ...
    'name', "Poles(test)", ...
    'kind', "poleRoots", ...
    'axisName', "root_index", ...
    'axisValues', [1 2], ...
    'unit', "rad/s", ...
    'domain', "complex", ...
    'values', [3 + 4i, -5 + 12i], ...
    'magnitude', [], ...
    'phaseDeg', []);

artifacts = spice.output.emit(result, OutputDir=outputDir, EmitPlots=false, WriteJSON=false, WriteMAT=false, WriteCSV=true);
assert(numel(artifacts.csvFiles) == 1);
csvText = fileread(artifacts.csvFiles{1});
assert(contains(csvText, "root_index,real,imag,magnitude,phase_deg"));
assert(contains(csvText, "1,3,4,5"));
assert(contains(csvText, "2,-5,12,13"));

clear cleanup
end

function assertComplexComparisonHandlesLengthMismatch()
candidate = comparisonFixtureResult([1 + 2i, 3 + 4i]);
baseline = comparisonFixtureResult(1 + 2i);
entry = struct( ...
    'probeSelection', "all", ...
    'toleranceProfile', struct( ...
        'nodeAbs', 1e-3, ...
        'currentAbs', 1e-6, ...
        'magnitudeRel', 0.02, ...
        'phaseAbsDeg', 2, ...
        'waveformAbs', 1e-2, ...
        'waveformCurrentAbs', 1e-4));

comparison = spice.regression.compareResults(candidate, baseline, entry);
assert(~comparison.passed);
assert(contains(comparison.signalSummaries(1).alignMode, "length_mismatch"));
end

function result = comparisonFixtureResult(values)
result = struct();
result.analysisType = "pz";
result.axis = struct('name', "root_index", 'values', 1:numel(values), 'unit', "", 'scale', "categorical");
result.signals = struct( ...
    'name', "Poles(test)", ...
    'kind', "poleRoots", ...
    'axisName', "root_index", ...
    'axisValues', 1:numel(values), ...
    'unit', "rad/s", ...
    'domain', "complex", ...
    'values', values, ...
    'magnitude', [], ...
    'phaseDeg', []);
result.operatingPoint = struct();
result.meta = struct('backend', "native", 'backendReason', "test", 'newton', struct());
end

function cleanupDirectory(outputDir)
if isfolder(outputDir)
    rmdir(outputDir, 's');
end
end
