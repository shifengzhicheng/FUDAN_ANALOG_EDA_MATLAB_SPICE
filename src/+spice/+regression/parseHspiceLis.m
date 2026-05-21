function audit = parseHspiceLis(lisPath)
% PARSEHSPICELIS Parse lightweight audit data from an HSPICE .lis file.
% The first-stage parser extracts operating-point node voltages and keeps
% generic numeric analysis blocks so we can spot-check native or legacy
% results against HSPICE without blocking on binary .ac0/.tr0/.sw0 parsers.
arguments
    lisPath {mustBeTextScalar}
end

lisPath = string(lisPath);
lines = string(splitlines(fileread(lisPath)));
audit = struct( ...
    'sourcePath', lisPath, ...
    'operatingPoint', struct('nodeIds', zeros(0, 1), 'values', zeros(0, 1)), ...
    'analysisBlocks', {{}}, ...
    'notes', {{}});

[audit.operatingPoint.nodeIds, audit.operatingPoint.values] = parseOperatingPoint(lines);
audit.analysisBlocks = parseAnalysisBlocks(lines);
if isempty(audit.analysisBlocks)
    audit.notes{end + 1} = 'No generic analysis blocks were parsed from the .lis file.';
end
end

function [nodeIds, values] = parseOperatingPoint(lines)
nodeIds = zeros(0, 1);
values = zeros(0, 1);
sectionStart = find(contains(lower(lines), "operating point information"), 1, 'first');
if isempty(sectionStart)
    return;
end

for idx = sectionStart:min(numel(lines), sectionStart + 200)
    line = lines(idx);
    if idx > sectionStart + 3 && startsWith(strtrim(line), "****")
        break;
    end
    matches = regexp(char(line), '0:(\d+)\s*=\s*([^\s]+)', 'tokens');
    for matchIdx = 1:numel(matches)
        nodeIds(end + 1, 1) = str2double(matches{matchIdx}{1}); %#ok<AGROW>
        values(end + 1, 1) = spice.util.parseNumericWithSuffix(matches{matchIdx}{2}); %#ok<AGROW>
    end
end
end

function blocks = parseAnalysisBlocks(lines)
blocks = {};
currentAnalysis = "";
idx = 1;
while idx <= numel(lines)
    trimmed = strtrim(lines(idx));
    lowerTrimmed = lower(trimmed);
    if contains(lowerTrimmed, 'dc transfer curves')
        currentAnalysis = "dc";
    elseif contains(lowerTrimmed, 'ac analysis')
        currentAnalysis = "ac";
    elseif contains(lowerTrimmed, 'transient analysis')
        currentAnalysis = "trans";
    end

    if startsWith(lowerTrimmed, 'freq') || startsWith(lowerTrimmed, 'time') || startsWith(lowerTrimmed, 'volt')
        [block, nextIdx] = parseNumericBlock(lines, idx, currentAnalysis);
        if ~isempty(block)
            blocks{end + 1, 1} = block; %#ok<AGROW>
            idx = nextIdx;
            continue;
        end
    end
    idx = idx + 1;
end
end

function [block, nextIdx] = parseNumericBlock(lines, startIdx, analysisType)
headerTokens = strsplit(strtrim(lines(startIdx)));
if numel(headerTokens) < 2
    block = [];
    nextIdx = startIdx + 1;
    return;
end

labelLines = strings(0, 1);
idx = startIdx + 1;
while idx <= numel(lines)
    trimmed = strtrim(lines(idx));
    if trimmed == "" || lower(trimmed) == "x" || lower(trimmed) == "y"
        idx = idx + 1;
        continue;
    end
    if startsWith(trimmed, '1******') || startsWith(trimmed, '******') || startsWith(lower(trimmed), 'runtime statistics')
        break;
    end
    if looksNumericRow(trimmed)
        break;
    end
    labelLines(end + 1, 1) = trimmed; %#ok<AGROW>
    idx = idx + 1;
end

rows = zeros(0, numel(headerTokens));
while idx <= numel(lines)
    trimmed = strtrim(lines(idx));
    if ~looksNumericRow(trimmed)
        break;
    end
    rowTokens = strsplit(trimmed);
    if numel(rowTokens) ~= numel(headerTokens)
        break;
    end
    row = zeros(1, numel(rowTokens));
    for tokenIdx = 1:numel(rowTokens)
        row(tokenIdx) = spice.util.parseNumericWithSuffix(rowTokens{tokenIdx});
    end
    rows(end + 1, :) = row; %#ok<AGROW>
    idx = idx + 1;
end

if isempty(rows)
    block = [];
    nextIdx = startIdx + 1;
    return;
end

block = struct( ...
    'analysisType', string(analysisType), ...
    'axisName', string(headerTokens{1}), ...
    'columnHeaders', {headerTokens(2:end)}, ...
    'labelLines', cellstr(labelLines), ...
    'data', rows);
nextIdx = idx;
end

function tf = looksNumericRow(trimmedLine)
if trimmedLine == ""
    tf = false;
    return;
end
firstToken = strsplit(trimmedLine);
firstToken = string(firstToken{1});
tf = ~isempty(regexp(char(firstToken), '^[+\-]?(?:\d+\.?\d*|\.\d+)(?:e[+\-]?\d+)?[a-zA-Z]*$', 'once'));
end
