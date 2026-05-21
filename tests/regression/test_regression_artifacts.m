function test_regression_artifacts()
% TEST_REGRESSION_ARTIFACTS Ensure one regression case emits diff plots.
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

summary = spice.regression.runManifest(RootDir=rootDir, IncludeCases='bufferAC', EmitPlots=true, WriteCaseArtifacts=false, WriteReports=true);
plotDir = fullfile(summary.outputRoot, 'bufferAC', 'ac', 'plots');
assert(isfolder(plotDir));
plotFiles = dir(fullfile(plotDir, '*.png'));
assert(~isempty(plotFiles));

disp('REGRESSION_ARTIFACTS_PASSED');
end
