classdef DiodeModel < spice.model.ModelDefinition
    properties (Constant)
        Category = "diode"
    end

    methods
        function obj = DiodeModel(id, saturationCurrent, lineNumber, rawTokens)
            params = struct('is', saturationCurrent);
            obj@spice.model.ModelDefinition(id, params, lineNumber, rawTokens);
        end

        function out = toStruct(obj)
            out = struct('id', obj.Id, 'is', obj.Parameters.is, 'rawTokens', {obj.RawTokens}, 'lineNumber', obj.LineNumber);
        end

        function exportToLegacy(obj, collector)
            collector.addDiodeModel(obj);
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            if numel(tokens) < 4
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 4 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.DiodeModel( ...
                str2double(tokens{2}), ...
                spice.util.parseNumericWithSuffix(tokens{4}), ...
                lineNumber, tokens);
        end
    end
end
