classdef (Abstract) ModelDefinition
    properties (Abstract, Constant)
        Category
    end

    properties (SetAccess = protected)
        Id (1,1) double
        Parameters struct
        LineNumber (1,1) double
        RawTokens cell
    end

    methods
        function obj = ModelDefinition(id, parameters, lineNumber, rawTokens)
            obj.Id = double(id);
            obj.Parameters = parameters;
            obj.LineNumber = double(lineNumber);
            obj.RawTokens = rawTokens;
        end
    end

    methods (Abstract)
        out = toStruct(obj)
        exportToLegacy(obj, collector)
    end
end
