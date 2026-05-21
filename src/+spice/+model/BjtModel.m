classdef BjtModel < spice.model.ModelDefinition
    properties (Constant)
        Category = "bjt"
    end

    methods
        function obj = BjtModel(id, js, alphaF, alphaR, cje, cjc, lineNumber, rawTokens)
            params = struct('js', js, 'alphaF', alphaF, 'alphaR', alphaR, 'cje', cje, 'cjc', cjc);
            obj@spice.model.ModelDefinition(id, params, lineNumber, rawTokens);
        end

        function out = toStruct(obj)
            out = struct('id', obj.Id, 'js', obj.Parameters.js, 'alphaF', obj.Parameters.alphaF, ...
                'alphaR', obj.Parameters.alphaR, 'cje', obj.Parameters.cje, 'cjc', obj.Parameters.cjc, ...
                'rawTokens', {obj.RawTokens}, 'lineNumber', obj.LineNumber);
        end

        function exportToLegacy(obj, collector)
            collector.addBjtModel(obj);
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            if numel(tokens) < 12
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 12 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.BjtModel( ...
                str2double(tokens{2}), ...
                spice.util.parseNumericWithSuffix(tokens{4}), ...
                spice.util.parseNumericWithSuffix(tokens{6}), ...
                spice.util.parseNumericWithSuffix(tokens{8}), ...
                spice.util.parseNumericWithSuffix(tokens{10}), ...
                spice.util.parseNumericWithSuffix(tokens{12}), ...
                lineNumber, tokens);
        end
    end
end
