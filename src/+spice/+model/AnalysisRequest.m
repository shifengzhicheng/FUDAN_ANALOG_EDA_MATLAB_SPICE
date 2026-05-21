classdef AnalysisRequest
    properties (SetAccess = private)
        Type (1,1) string
        Parameters struct
        RawTokens cell
        LineNumber (1,1) double
    end

    methods
        function obj = AnalysisRequest(type, parameters, rawTokens, lineNumber)
            obj.Type = string(type);
            obj.Parameters = parameters;
            obj.RawTokens = rawTokens;
            obj.LineNumber = double(lineNumber);
        end

        function out = toStruct(obj)
            out = struct('type', obj.Type, 'params', obj.Parameters, 'rawTokens', {obj.RawTokens}, 'lineNumber', obj.LineNumber);
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            kind = lower(string(tokens{1}));
            rawTokens = tokens;

            switch kind
                case ".dc"
                    obj = spice.model.AnalysisRequest("dc", struct(), rawTokens, lineNumber);
                case ".dcsweep"
                    if numel(tokens) < 4
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 4 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    rangeParts = regexp(tokens{3}, '^\[\s*([^,\]]+)\s*,\s*([^\]]+)\s*\]$', 'tokens', 'once');
                    if isempty(rangeParts)
                        error('spice:parseNetlist:BadSweepRange', 'Invalid DC sweep range at line %d.', lineNumber);
                    end
                    params = struct( ...
                        'deviceName', string(tokens{2}), ...
                        'startValue', spice.util.parseNumericWithSuffix(rangeParts{1}), ...
                        'stopValue', spice.util.parseNumericWithSuffix(rangeParts{2}), ...
                        'stepValue', spice.util.parseNumericWithSuffix(tokens{4}));
                    obj = spice.model.AnalysisRequest("dcsweep", params, rawTokens, lineNumber);
                case ".ac"
                    if numel(tokens) < 5
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 5 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    params = struct( ...
                        'mode', upper(string(tokens{2})), ...
                        'points', str2double(tokens{3}), ...
                        'startFreq', spice.util.parseNumericWithSuffix(tokens{4}), ...
                        'stopFreq', spice.util.parseNumericWithSuffix(tokens{5}));
                    obj = spice.model.AnalysisRequest("ac", params, rawTokens, lineNumber);
                case ".trans"
                    if numel(tokens) < 3
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 3 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    params = struct( ...
                        'totalTime', spice.util.parseNumericWithSuffix(tokens{2}), ...
                        'stepTime', spice.util.parseNumericWithSuffix(tokens{3}));
                    obj = spice.model.AnalysisRequest("trans", params, rawTokens, lineNumber);
                case ".shoot"
                    if numel(tokens) < 3
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 3 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    params = struct( ...
                        'totalTime', spice.util.parseNumericWithSuffix(tokens{2}), ...
                        'stepTime', spice.util.parseNumericWithSuffix(tokens{3}));
                    obj = spice.model.AnalysisRequest("shoot", params, rawTokens, lineNumber);
                case ".pz"
                    params = struct('targets', {tokens(2:end)});
                    obj = spice.model.AnalysisRequest("pz", params, rawTokens, lineNumber);
                otherwise
                    error('spice:parseNetlist:UnsupportedAnalysis', 'Unsupported analysis at line %d.', lineNumber);
            end
        end
    end
end
