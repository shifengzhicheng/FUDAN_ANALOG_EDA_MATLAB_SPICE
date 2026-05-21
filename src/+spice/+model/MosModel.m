classdef MosModel < spice.model.ModelDefinition
    properties (Constant)
        Category = "mos"
    end

    methods
        function obj = MosModel(id, vt, mu, cox, lambda, cj0, lineNumber, rawTokens)
            params = struct('vt', vt, 'mu', mu, 'cox', cox, 'lambda', lambda, 'cj0', cj0);
            obj@spice.model.ModelDefinition(id, params, lineNumber, rawTokens);
        end

        function out = toStruct(obj)
            out = struct('id', obj.Id, 'vt', obj.Parameters.vt, 'mu', obj.Parameters.mu, ...
                'cox', obj.Parameters.cox, 'lambda', obj.Parameters.lambda, 'cj0', obj.Parameters.cj0, ...
                'rawTokens', {obj.RawTokens}, 'lineNumber', obj.LineNumber);
        end

        function exportToLegacy(obj, collector)
            collector.addMosModel(obj);
        end
    end

    methods (Static)
        function obj = fromTokens(tokens, lineNumber)
            if numel(tokens) < 12
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected at least 12 tokens at line %d but got %d.', lineNumber, numel(tokens));
            end
            obj = spice.model.MosModel( ...
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
