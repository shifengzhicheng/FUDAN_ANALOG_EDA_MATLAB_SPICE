function paths = case_output_paths(caseName, outputRoot)
% CASE_OUTPUT_PATHS Return ignored local output paths for one testcase.
% All generated artifacts should live under this case-scoped directory so
% plots, logs, and temporary outputs do not pollute the repository root.
arguments
    caseName {mustBeTextScalar}
    outputRoot {mustBeTextScalar} = "local"
end

caseName = string(caseName);
[~, caseStem, ~] = fileparts(char(caseName));
if strlength(string(caseStem)) == 0
    caseStem = char(caseName);
end

caseFolder = sanitizePathSegment(string(caseStem));
caseRoot = fullfile(char(outputRoot), char(caseFolder));

paths = struct( ...
    'caseName', caseFolder, ...
    'root', string(caseRoot), ...
    'plots', string(fullfile(caseRoot, 'plots')), ...
    'logs', string(fullfile(caseRoot, 'logs')));
end

function name = sanitizePathSegment(name)
name = regexprep(string(name), '[<>:"/\\|?*\s]+', '_');
name = regexprep(name, '^_+|_+$', '');
if strlength(name) == 0
    name = "case";
end
end
