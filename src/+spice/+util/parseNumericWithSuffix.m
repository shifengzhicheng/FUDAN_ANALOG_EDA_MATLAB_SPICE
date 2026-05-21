function value = parseNumericWithSuffix(token)
token = char(string(token));
token = strtrim(token);
if isempty(token)
    error('spice:parseNumericWithSuffix:EmptyToken', 'Numeric token is empty.');
end

normalized = upper(token);
normalized = regexprep(normalized, 'HZ$', '');
normalized = strrep(normalized, 'OHM', '');
normalized = regexprep(normalized, '(V|A|S|SEC|FARAD|HENRY|DEG)$', '');

parts = regexp(normalized, '^([+\-]?(?:\d+\.?\d*|\.\d+)(?:E[+\-]?\d+)?)([A-Z]+)?$', 'tokens', 'once');
if isempty(parts)
    error('spice:parseNumericWithSuffix:InvalidToken', 'Invalid numeric token: %s', token);
end

value = str2double(parts{1});
suffix = "";
if numel(parts) > 1 && ~isempty(parts{2})
    suffix = string(parts{2});
end

switch suffix
    case ""
        scale = 1;
    case "T"
        scale = 1e12;
    case "G"
        scale = 1e9;
    case "MEG"
        scale = 1e6;
    case "X"
        scale = 1e6;
    case "K"
        scale = 1e3;
    case "M"
        scale = 1e-3;
    case "U"
        scale = 1e-6;
    case "N"
        scale = 1e-9;
    case "P"
        scale = 1e-12;
    case "F"
        scale = 1e-15;
    otherwise
        error('spice:parseNumericWithSuffix:UnsupportedSuffix', 'Unsupported suffix "%s" in token %s.', suffix, token);
end

value = value * scale;
end
