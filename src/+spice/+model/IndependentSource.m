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
            if numel(tokens) < 5
                error('spice:parseNetlist:BadSource', 'Bad source definition at line %d.', lineNumber);
            end
            waveform = upper(string(tokens{4}));
            switch waveform
                case "DC"
                    if numel(tokens) < 5
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 5 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    params = struct('waveform', "DC", 'dcValue', spice.util.parseNumericWithSuffix(tokens{5}), ...
                        'acValue', 0, 'freq', 0, 'phase', 0);
                case "AC"
                    if numel(tokens) < 7
                        error('spice:parseNetlist:TooFewTokens', ...
                            'Expected at least 7 tokens at line %d but got %d.', lineNumber, numel(tokens));
                    end
                    params = struct('waveform', "ac", 'dcValue', spice.util.parseNumericWithSuffix(tokens{5}), ...
                        'acValue', spice.util.parseNumericWithSuffix(tokens{6}), 'freq', 0, ...
                        'phase', spice.util.parseNumericWithSuffix(tokens{7}));
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
                    error('spice:parseNetlist:UnsupportedWaveform', ...
                        'Unsupported source waveform "%s" at line %d.', waveform, lineNumber);
            end
        end
    end
end
