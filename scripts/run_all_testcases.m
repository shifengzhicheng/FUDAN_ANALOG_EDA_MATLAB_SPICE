function summary = run_all_testcases(opts)
% RUN_ALL_TESTCASES Run the full testcase matrix and emit inspection plots.
% This script is the manual-review entry point for the repository: it runs
% every manifest case, writes regression reports, emits native/legacy
% artifacts with plots, and generates one markdown overview under runs/.
arguments
    opts.OutputRoot {mustBeTextScalar} = ""
    opts.IncludeCases string = strings(0, 1)
    opts.EmitPlots (1,1) logical = true
end

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(fullfile(repoRoot, 'src')));

outputRoot = resolveOutputRoot(repoRoot, opts.OutputRoot);
summary = spice.regression.runManifest( ...
    RootDir=repoRoot, ...
    OutputRoot=outputRoot, ...
    IncludeCases=opts.IncludeCases, ...
    EmitPlots=opts.EmitPlots, ...
    WriteCaseArtifacts=true, ...
    WriteReports=true);

overviewPath = fullfile(outputRoot, 'overview.md');
writeOverview(overviewPath, summary);
summary.overviewPath = string(overviewPath);

fprintf('TESTCASE_GALLERY_READY %s\n', outputRoot);
fprintf('TESTCASE_OVERVIEW %s\n', overviewPath);
end

function outputRoot = resolveOutputRoot(repoRoot, inputOutputRoot)
if strlength(string(inputOutputRoot)) > 0
    outputRoot = char(string(inputOutputRoot));
else
    outputRoot = fullfile(repoRoot, 'runs', 'testcase_gallery');
end
end

function writeOverview(outputPath, summary)
fid = fopen(outputPath, 'w');
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Testcase Gallery\n\n');
fprintf(fid, '- total cases: %d\n', summary.totalCases);
fprintf(fid, '- passed: %d\n', summary.passedCount);
fprintf(fid, '- unexpected failures: %d\n', summary.unexpectedFailureCount);
fprintf(fid, '- expected failures: %d\n', summary.expectedFailureCount);
fprintf(fid, '- output root: `%s`\n\n', string(summary.outputRoot));

fprintf(fid, '| Case | Analysis | Passed | ExpectedFail | Backend Reason | Native Artifacts | Legacy Artifacts | Diff Report |\n');
fprintf(fid, '| --- | --- | --- | --- | --- | --- | --- | --- |\n');

for idx = 1:numel(summary.caseReports)
    report = summary.caseReports(idx);
    caseDir = fullfile(char(summary.outputRoot), char(report.caseName), char(report.analysisType));
    nativeDir = fullfile(caseDir, 'native');
    legacyDir = fullfile(caseDir, 'legacy');
    summaryFile = fullfile(caseDir, 'summary.json');
    fprintf(fid, '| %s | %s | %d | %d | `%s` | `%s` | `%s` | `%s` |\n', ...
        string(report.caseName), ...
        string(report.analysisType), ...
        report.passed, ...
        report.expectedFail, ...
        string(report.comparison.backendReason), ...
        string(nativeDir), ...
        string(legacyDir), ...
        string(summaryFile));
end

clear cleanup
end
