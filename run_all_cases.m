function summary = run_all_cases(opts)
% RUN_ALL_CASES Execute every root-level testfile/*.sp netlist.
arguments
    opts.EmitPlots (1,1) logical = false
end

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
    try
        % Continue after individual failures so one broken analysis does not
        % hide the health of the rest of the testcase set.
        run_spice_case(caseName, EmitPlots=opts.EmitPlots, FigureVisible="off");
        elapsed = toc(timer);
        reports(idx) = struct('caseName', caseName, 'passed', true, 'elapsedSeconds', elapsed, 'message', "");
        fprintf('PASS %s %.3fs\n', caseName, elapsed);
    catch err
        elapsed = toc(timer);
        reports(idx) = struct('caseName', caseName, 'passed', false, 'elapsedSeconds', elapsed, 'message', string(err.identifier) + ": " + string(err.message));
        fprintf('FAIL %s %.3fs %s: %s\n', caseName, elapsed, string(err.identifier), string(err.message));
    end
end

summary = struct( ...
    'totalCases', numel(reports), ...
    'passedCount', sum([reports.passed]), ...
    'failedCount', sum(~[reports.passed]), ...
    'caseReports', reports);
fprintf('ALL_CASES_DONE total=%d passed=%d failed=%d\n', summary.totalCases, summary.passedCount, summary.failedCount);
end
