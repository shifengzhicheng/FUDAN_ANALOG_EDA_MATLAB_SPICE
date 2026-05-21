function [logicalLines, physicalLineCount] = preprocessNetlistLines(sourceText)
% PREPROCESSNETLISTLINES Normalize comments and continuations before parsing.
rawText = char(string(sourceText));
rawText = strrep(rawText, sprintf('\r\n'), newline);
rawText = strrep(rawText, sprintf('\r'), newline);
physicalLines = regexp(rawText, '\n', 'split');
physicalLineCount = numel(physicalLines);

template = struct('Text', "", 'LineNumber', 0);
logicalLines = repmat(template, 0, 1);
currentText = "";
currentLineNumber = 0;

for lineNumber = 1:physicalLineCount
    line = stripNetlistComment(physicalLines{lineNumber});
    line = strtrim(line);
    if isempty(line) || startsWith(line, '*')
        continue;
    end

    if startsWith(line, '+')
        if strlength(currentText) == 0
            error('spice:parseNetlist:ContinuationWithoutLine', ...
                'Continuation line %d does not have a previous statement.', lineNumber);
        end
        currentText = currentText + " " + strtrim(extractAfter(string(line), 1));
        continue;
    end

    logicalLines = appendPendingLine(logicalLines, currentText, currentLineNumber);
    currentText = string(line);
    currentLineNumber = lineNumber;
end

logicalLines = appendPendingLine(logicalLines, currentText, currentLineNumber);
end

function line = stripNetlistComment(line)
commentIndex = strfind(line, '$');
if ~isempty(commentIndex)
    line = line(1:commentIndex(1) - 1);
end
end

function logicalLines = appendPendingLine(logicalLines, currentText, currentLineNumber)
if strlength(currentText) > 0
    logicalLines(end + 1, 1) = struct('Text', currentText, 'LineNumber', currentLineNumber); %#ok<AGROW>
end
end
