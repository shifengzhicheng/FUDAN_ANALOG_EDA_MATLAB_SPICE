function test_regression_smoke()
% TEST_REGRESSION_SMOKE Run the manifest-driven regression harness.
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

summary = spice.regression.runManifest( ...
    RootDir=rootDir, ...
    IncludeCases=["bufferDC", "bufferAC", "diftestSweep", "bufferTrans"], ...
    EmitPlots=false, ...
    WriteCaseArtifacts=false, ...
    WriteReports=true);
assert(summary.totalCases == 4);
assert(summary.unexpectedFailureCount == 0);
assert(summary.expectedFailureCount >= 1);
assert(isfolder(summary.outputRoot));
assert(isfile(fullfile(summary.outputRoot, 'bufferDC', 'dc', 'summary.json')));
assert(isfile(fullfile(summary.outputRoot, 'bufferDC', 'dc', 'backend_summary.txt')));

disp('REGRESSION_SMOKE_PASSED');
end
