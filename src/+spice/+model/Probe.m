classdef Probe
    properties (SetAccess = private)
        Kind (1,1) string
        Target (1,1) string
        Port (1,1) string
        DisplayName (1,1) string
        LineNumber (1,1) double
        RawTokens cell
    end

    methods
        function obj = Probe(kind, target, port, displayName, lineNumber, rawTokens)
            obj.Kind = string(kind);
            obj.Target = string(target);
            obj.Port = string(port);
            obj.DisplayName = string(displayName);
            obj.LineNumber = double(lineNumber);
            obj.RawTokens = rawTokens;
        end

        function out = toStruct(obj)
            out = struct( ...
                'kind', obj.Kind, ...
                'target', obj.Target, ...
                'port', obj.Port, ...
                'displayName', obj.DisplayName, ...
                'lineNumber', obj.LineNumber, ...
                'rawTokens', {obj.RawTokens});
        end

        function exportToLegacy(obj, collector)
            collector.addProbe(obj);
        end
    end

    methods (Static)
        function obj = fromNodeDirective(tokens, lineNumber)
            if numel(tokens) < 2
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 2 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            target = string(tokens{2});
            obj = spice.model.Probe("nodeVoltage", target, "", "V(" + target + ")", lineNumber, tokens);
        end

        function obj = fromCurrentDirective(tokens, lineNumber)
            if numel(tokens) < 2
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 2 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            match = regexp(tokens{2}, '^([A-Za-z]\w*)\(([^)]+)\)$', 'tokens', 'once');
            if isempty(match)
                error('spice:parseNetlist:BadPlotCurrent', 'Invalid .plotnc expression at line %d.', lineNumber);
            end
            obj = spice.model.Probe("deviceCurrent", string(match{1}), string(match{2}), ...
                "I(" + string(match{1}) + "," + string(match{2}) + ")", lineNumber, tokens);
        end
    end
end
