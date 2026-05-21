classdef (Abstract) IndependentSource < spice.model.Device
    properties (Abstract, Constant)
        LegacySourceKind
    end

    methods
        function obj = IndependentSource(name, nodeTokens, waveformParams, lineNumber, rawTokens)
            if numel(nodeTokens) ~= 2
                error('spice:model:IndependentSource:BadNodeCount', ...
                    'Source %s expects exactly two nodes.', name);
            end
            obj@spice.model.Device(name, nodeTokens, waveformParams, lineNumber, rawTokens);
        end

        function exportToLegacy(obj, collector)
            collector.addSource(obj.LegacySourceKind, obj.Name, obj.NodeTokens, obj.Parameters);
        end
    end

    methods (Static)
        function params = parseWaveform(tokens, lineNumber)
            if numel(tokens) < 4
                error('spice:parseNetlist:BadSource', 'Bad source definition at line %d.', lineNumber);
            end
            waveform = upper(string(tokens{4}));
            switch waveform
                case "DC"
                    if numel(tokens) < 5
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 5 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    dcValue = spice.util.parseNumericWithSuffix(tokens{5});
                    params = spice.model.IndependentSource.dcParams(dcValue);
                    if numel(tokens) >= 7 && upper(string(tokens{6})) == "AC"
                        params = spice.model.IndependentSource.addAcParams(params, tokens(7:end), lineNumber);
                    end
                case "AC"
                    params = spice.model.IndependentSource.parseAcParams(tokens(5:end), lineNumber);
                case "SIN"
                    if numel(tokens) < 8
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 8 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    params = struct('waveform', "SIN", 'dcValue', spice.util.parseNumericWithSuffix(tokens{5}), ...
                        'acValue', spice.util.parseNumericWithSuffix(tokens{6}), ...
                        'freq', spice.util.parseNumericWithSuffix(tokens{7}), ...
                        'phase', spice.util.parseNumericWithSuffix(tokens{8}));
                otherwise
                    params = spice.model.IndependentSource.parseBareDcSource(tokens, lineNumber);
            end
        end
    end

    methods (Static, Access = private)
        function params = parseBareDcSource(tokens, lineNumber)
            try
                params = spice.model.IndependentSource.dcParams(spice.util.parseNumericWithSuffix(tokens{4}));
            catch err
                if startsWith(string(err.identifier), "spice:parseNumericWithSuffix:")
                    error('spice:parseNetlist:UnsupportedWaveform', ...
                        'Unsupported source waveform "%s" at line %d.', string(tokens{4}), lineNumber);
                end
                rethrow(err);
            end

            if numel(tokens) >= 6 && upper(string(tokens{5})) == "AC"
                params = spice.model.IndependentSource.addAcParams(params, tokens(6:end), lineNumber);
            end
        end

        function params = dcParams(dcValue)
            params = struct('waveform', "DC", 'dcValue', dcValue, 'acValue', 0, 'freq', 0, 'phase', 0);
        end

        function params = parseAcParams(valueTokens, lineNumber)
            values = spice.model.IndependentSource.parseNumericList(valueTokens, lineNumber, "AC");
            switch numel(values)
                case 1
                    dcValue = 0;
                    acValue = values(1);
                    phase = 0;
                case 2
                    dcValue = 0;
                    acValue = values(1);
                    phase = values(2);
                otherwise
                    dcValue = values(1);
                    acValue = values(2);
                    phase = values(3);
            end
            params = struct('waveform', "AC", 'dcValue', dcValue, 'acValue', acValue, 'freq', 0, 'phase', phase);
        end

        function params = addAcParams(params, valueTokens, lineNumber)
            values = spice.model.IndependentSource.parseNumericList(valueTokens, lineNumber, "AC");
            params.waveform = "AC";
            params.acValue = values(1);
            if numel(values) >= 2
                params.phase = values(2);
            end
        end

        function values = parseNumericList(tokens, lineNumber, context)
            if isempty(tokens)
                error('spice:parseNetlist:TooFewTokens', ...
                    'Expected numeric values for %s source at line %d.', context, lineNumber);
            end
            values = zeros(1, numel(tokens));
            for idx = 1:numel(tokens)
                values(idx) = spice.util.parseNumericWithSuffix(tokens{idx});
            end
        end
    end
end
