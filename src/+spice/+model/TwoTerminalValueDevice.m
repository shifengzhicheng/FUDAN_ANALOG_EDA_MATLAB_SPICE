classdef (Abstract) TwoTerminalValueDevice < spice.model.Device
    properties (Abstract, Constant)
        LegacyPassiveKind
    end

    methods
        function obj = TwoTerminalValueDevice(name, nodeTokens, value, lineNumber, rawTokens)
            if numel(nodeTokens) ~= 2
                error('spice:model:TwoTerminalValueDevice:BadNodeCount', ...
                    'Device %s expects exactly two nodes.', name);
            end
            obj@spice.model.Device(name, nodeTokens, struct('value', value), lineNumber, rawTokens);
        end

        function exportToLegacy(obj, collector)
            collector.addPassive(obj.LegacyPassiveKind, obj.Name, obj.NodeTokens, obj.Parameters.value);
        end
    end
end
