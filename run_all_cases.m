function summary = run_all_cases(opts)
% RUN_ALL_CASES Execute every root-level testfile/*.sp netlist.
arguments
    opts.EmitPlots (1,1) logical = false
    opts.OutputRoot {mustBeTextScalar} = "local"
    opts.OutputDir {mustBeTextScalar} = ""
    opts.WriteLogs (1,1) logical = true
end

outputRoot = resolveOutputRoot(opts);

% Root-level testfile/*.sp files are the project-owned testcase set. The
% hspice/test_ori subfolders are references and are deliberately skipped.
caseFiles = dir(fullfile('testfile', '*.sp'));
caseNames = erase(string({caseFiles.name}), ".sp");
caseNames = sort(caseNames(:));

reports = repmat(struct('caseName', "", 'passed', false, 'elapsedSeconds', NaN, 'message', ""), numel(caseNames), 1);
for idx = 1:numel(caseNames)
    caseName = caseNames(idx);
    fprintf('START %s\n', caseName);
    timer = tic;
    caseOutput = "";
    outputPaths = case_output_paths(caseName, outputRoot);
    try
        % Continue after individual failures so one broken analysis does not
        % hide the health of the rest of the testcase set.
        caseError = [];
        caseOutput = evalc('try, run_spice_case(caseName, EmitPlots=opts.EmitPlots, FigureVisible="off", OutputRoot=outputRoot); catch caughtError, caseError = caughtError; end');
        if ~isempty(caseError)
            rethrow(caseError);
        end
        elapsed = toc(timer);
        reports(idx) = struct('caseName', caseName, 'passed', true, 'elapsedSeconds', elapsed, 'message', "");
        if opts.WriteLogs
            writeCaseLogs(outputPaths, caseName, "PASS", elapsed, "", caseOutput);
        end
        fprintf('PASS %s %.3fs\n', caseName, elapsed);
    catch err
        elapsed = toc(timer);
        message = string(err.identifier) + ": " + string(err.message);
        reports(idx) = struct('caseName', caseName, 'passed', false, 'elapsedSeconds', elapsed, 'message', message);
        if opts.WriteLogs
            writeCaseLogs(outputPaths, caseName, "FAIL", elapsed, message, caseOutput);
        end
        fprintf('FAIL %s %.3fs %s: %s\n', caseName, elapsed, string(err.identifier), string(err.message));
    end
end

summary = struct( ...
    'totalCases', numel(reports), ...
    'passedCount', sum([reports.passed]), ...
    'failedCount', sum(~[reports.passed]), ...
    'caseReports', reports, ...
    'outputRoot', outputRoot);
fprintf('ALL_CASES_DONE total=%d passed=%d failed=%d\n', summary.totalCases, summary.passedCount, summary.failedCount);
end

function outputRoot = resolveOutputRoot(opts)
outputRoot = string(opts.OutputRoot);
if strlength(string(opts.OutputDir)) > 0
    outputRoot = string(opts.OutputDir);
end
end

function writeCaseLogs(outputPaths, caseName, status, elapsed, message, caseOutput)
ensureDirectory(outputPaths.logs);

summaryText = sprintf('case=%s\nstatus=%s\nelapsedSeconds=%.6f\nmessage=%s\nplots=%s\nlogs=%s\n', ...
    string(caseName), status, elapsed, string(message), outputPaths.plots, outputPaths.logs);
writeTextFile(fullfile(char(outputPaths.logs), 'backend_summary.txt'), summaryText);

caseLog = sprintf('CASE %s\nSTATUS %s\nELAPSED %.6f\nMESSAGE %s\n\n--- console ---\n%s', ...
    string(caseName), status, elapsed, string(message), string(caseOutput));
writeTextFile(fullfile(char(outputPaths.logs), 'case.log'), caseLog);
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, 'w');
if fid < 0
    error('spice:io:CannotOpenLog', 'Cannot open log file for writing: %s.', filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(textValue));
delete(cleanup);
end

function ensureDirectory(pathValue)
if ~isfolder(pathValue)
    mkdir(pathValue);
end
end
