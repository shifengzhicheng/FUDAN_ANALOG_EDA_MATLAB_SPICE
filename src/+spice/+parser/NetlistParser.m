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
            [lines, physicalLineCount] = spice.parser.preprocessNetlistLines(sourceText);

            circuit = spice.model.Circuit( ...
                'SourceName', obj.SourceName, ...
                'RawText', string(sourceText), ...
                'LineCount', physicalLineCount);

            for idx = 1:numel(lines)
                line = strtrim(char(lines(idx).Text));
                lineNumber = lines(idx).LineNumber;
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
                case {".options", ".option", ".print", ".probe", ".title"}
                    % Reporting and simulator-control cards are accepted so
                    % HSPICE-style fixtures can still feed the object model.
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
                case {".op", ".dc", ".dcsweep", ".ac", ".tran", ".trans", ".shoot", ".pz"}
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
