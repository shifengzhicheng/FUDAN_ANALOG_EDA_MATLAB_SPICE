classdef ModelLibrary < handle
    properties (SetAccess = private)
        Mos cell = {}
        Diode cell = {}
        Bjt cell = {}
    end

    methods
        function add(obj, model)
            switch model.Category
                case "mos"
                    obj.Mos{end + 1, 1} = model;
                case "diode"
                    obj.Diode{end + 1, 1} = model;
                case "bjt"
                    obj.Bjt{end + 1, 1} = model;
                otherwise
                    error('spice:model:ModelLibrary:UnsupportedCategory', 'Unsupported model category %s.', model.Category);
            end
        end

        function out = toStruct(obj)
            out = struct( ...
                'mos', obj.collect(obj.Mos, @spice.model.ModelLibrary.emptyMosStruct), ...
                'diode', obj.collect(obj.Diode, @spice.model.ModelLibrary.emptyDiodeStruct), ...
                'bjt', obj.collect(obj.Bjt, @spice.model.ModelLibrary.emptyBjtStruct));
        end

        function exportToLegacy(obj, collector)
            obj.exportGroup(obj.Mos, collector);
            obj.exportGroup(obj.Diode, collector);
            obj.exportGroup(obj.Bjt, collector);
        end
    end

    methods (Access = private)
        function out = collect(~, items, emptyFactory)
            if isempty(items)
                out = repmat(emptyFactory(), 0, 1);
                return;
            end

            cells = cellfun(@(item) item.toStruct(), items, 'UniformOutput', false);
            out = vertcat(cells{:});
        end

        function exportGroup(~, items, collector)
            for idx = 1:numel(items)
                items{idx}.exportToLegacy(collector);
            end
        end
    end

    methods (Static, Access = private)
        function item = emptyMosStruct()
            item = struct('id', 0, 'vt', 0, 'mu', 0, 'cox', 0, 'lambda', 0, 'cj0', 0, 'rawTokens', {{}}, 'lineNumber', 0);
        end

        function item = emptyDiodeStruct()
            item = struct('id', 0, 'is', 0, 'rawTokens', {{}}, 'lineNumber', 0);
        end

        function item = emptyBjtStruct()
            item = struct('id', 0, 'js', 0, 'alphaF', 0, 'alphaR', 0, 'cje', 0, 'cjc', 0, 'rawTokens', {{}}, 'lineNumber', 0);
        end
    end
end
