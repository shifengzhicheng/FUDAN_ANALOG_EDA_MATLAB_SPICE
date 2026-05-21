classdef Circuit < handle
    properties (SetAccess = private)
        SourceName (1,1) string = ""
        RawText (1,1) string = ""
        LineCount (1,1) double = 0
        Elements cell = {}
        Probes cell = {}
        Analysis = []
        Models
    end

    methods
        function obj = Circuit(varargin)
            obj.Models = spice.model.ModelLibrary();
            if nargin == 0
                return;
            end

            for idx = 1:2:numel(varargin)
                name = string(varargin{idx});
                value = varargin{idx + 1};
                switch name
                    case "SourceName"
                        obj.SourceName = string(value);
                    case "RawText"
                        obj.RawText = string(value);
                    case "LineCount"
                        obj.LineCount = double(value);
                    otherwise
                        error('spice:model:Circuit:UnknownOption', 'Unknown Circuit option %s.', name);
                end
            end
        end

        function addElement(obj, element)
            obj.Elements{end + 1, 1} = element;
        end

        function addProbe(obj, probe)
            obj.Probes{end + 1, 1} = probe;
        end

        function addModel(obj, model)
            obj.Models.add(model);
        end

        function setAnalysis(obj, analysis)
            if ~isempty(obj.Analysis)
                error('spice:model:Circuit:MultipleAnalyses', 'Only one primary analysis directive is supported.');
            end
            obj.Analysis = analysis;
        end

        function count = elementCount(obj)
            count = numel(obj.Elements);
        end

        function count = probeCount(obj)
            count = numel(obj.Probes);
        end

        function ids = nodeIds(obj)
            ids = [];
            for idx = 1:numel(obj.Elements)
                ids = [ids, obj.Elements{idx}.nodeIds()]; %#ok<AGROW>
            end
            ids = unique(ids, 'sorted');
        end

        function names = probeNames(obj)
            names = strings(numel(obj.Probes), 1);
            for idx = 1:numel(obj.Probes)
                names(idx) = obj.Probes{idx}.DisplayName;
            end
        end

        function summary = toStruct(obj)
            if isempty(obj.Analysis)
                error('spice:model:Circuit:MissingAnalysis', 'Circuit has no primary analysis directive.');
            end

            summary = struct( ...
                'elements', obj.elementStructs(), ...
                'models', obj.Models.toStruct(), ...
                'probes', obj.probeStructs(), ...
                'analysis', obj.Analysis.toStruct(), ...
                'meta', struct('sourceName', obj.SourceName, 'lineCount', obj.LineCount, 'rawText', obj.RawText));
        end

        function structs = elementStructs(obj)
            if isempty(obj.Elements)
                structs = repmat(spice.model.Circuit.emptyElementStruct(), 0, 1);
                return;
            end

            cells = cellfun(@(item) item.toStruct(), obj.Elements, 'UniformOutput', false);
            structs = vertcat(cells{:});
        end

        function structs = probeStructs(obj)
            if isempty(obj.Probes)
                structs = repmat(spice.model.Circuit.emptyProbeStruct(), 0, 1);
                return;
            end

            cells = cellfun(@(item) item.toStruct(), obj.Probes, 'UniformOutput', false);
            structs = vertcat(cells{:});
        end

        function meta = summary(obj)
            meta = struct( ...
                'sourceName', obj.SourceName, ...
                'lineCount', obj.LineCount, ...
                'elementCount', obj.elementCount(), ...
                'probeCount', obj.probeCount(), ...
                'analysisType', obj.Analysis.Type);
        end
    end

    methods (Static, Access = private)
        function item = emptyElementStruct()
            item = struct('name', "", 'kind', "", 'nodeTokens', string.empty(1, 0), ...
                'params', struct(), 'rawTokens', {{}}, 'lineNumber', 0);
        end

        function item = emptyProbeStruct()
            item = struct('kind', "", 'target', "", 'port', "", 'displayName', "", 'lineNumber', 0, 'rawTokens', {{}});
        end
    end
end
