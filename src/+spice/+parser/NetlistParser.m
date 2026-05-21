classdef NetlistParser < handle
    properties (SetAccess = private)
        SourceName (1,1) string = ""
    end

    methods
        function obj = NetlistParser(varargin)
            for idx = 1:2:numel(varargin)
                name = string(varargin{idx});
                value = varargin{idx + 1};
                switch name
                    case "SourceName"
                        obj.SourceName = string(value);
                    otherwise
                        error('spice:parser:NetlistParser:UnknownOption', 'Unknown parser option %s.', name);
                end
            end
        end

        function circuit = parse(obj, sourceText)
            rawText = char(string(sourceText));
            normalizedText = strrep(rawText, sprintf('\r\n'), sprintf('\n'));
            lines = regexp(normalizedText, '\n', 'split');

            circuit = spice.model.Circuit( ...
                'SourceName', obj.SourceName, ...
                'RawText', string(sourceText), ...
                'LineCount', numel(lines));

            for lineNumber = 1:numel(lines)
                line = strtrim(lines{lineNumber});
                if isempty(line) || startsWith(line, '*')
                    continue;
                end

                tokens = regexp(line, '\s+', 'split');
                head = string(tokens{1});
                lowerHead = lower(head);

                if startsWith(lowerHead, '.')
                    shouldStop = obj.handleDirective(circuit, lowerHead, tokens, lineNumber);
                    if shouldStop
                        break;
                    end
                else
                    circuit.addElement(spice.model.DeviceFactory.fromTokens(tokens, lineNumber));
                end
            end

            if isempty(circuit.Analysis)
                error('spice:parseNetlist:MissingAnalysis', 'No primary analysis directive found.');
            end
        end
    end

    methods (Access = private)
        function shouldStop = handleDirective(~, circuit, directive, tokens, lineNumber)
            shouldStop = false;

            switch directive
                case ".end"
                    shouldStop = true;
                case ".model"
                    circuit.addModel(spice.model.MosModel.fromTokens(tokens, lineNumber));
                case ".diode"
                    circuit.addModel(spice.model.DiodeModel.fromTokens(tokens, lineNumber));
                case ".bipolar"
                    circuit.addModel(spice.model.BjtModel.fromTokens(tokens, lineNumber));
                case ".plotnv"
                    circuit.addProbe(spice.model.Probe.fromNodeDirective(tokens, lineNumber));
                case ".plotnc"
                    circuit.addProbe(spice.model.Probe.fromCurrentDirective(tokens, lineNumber));
                case {".dc", ".dcsweep", ".ac", ".trans", ".shoot", ".pz"}
                    if ~isempty(circuit.Analysis)
                        error('spice:parseNetlist:MultipleAnalyses', ...
                            'Only one primary analysis directive is supported. Found another at line %d.', lineNumber);
                    end
                    circuit.setAnalysis(spice.model.AnalysisRequest.fromTokens(tokens, lineNumber));
                otherwise
                    error('spice:parseNetlist:UnsupportedDirective', ...
                        'Unsupported directive "%s" at line %d.', directive, lineNumber);
            end
        end
    end
end
