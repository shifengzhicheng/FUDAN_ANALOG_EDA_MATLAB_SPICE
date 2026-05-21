classdef AnalysisContext < handle
    % ANALYSISCONTEXT Shared state passed through native analyses.
    % It carries the requested analysis mode, the current operating-point
    % guess, device linearization states, sweep overrides, and transient
    % history so all native analyses reuse the same device protocol.
    properties (SetAccess = private)
        AnalysisType (1,1) string
        NativeCircuit
        Options struct
        Omega (1,1) double = 0
        Time (1,1) double = 0
        TimeStep (1,1) double = 0
    end

    properties
        OperatingPointSolution = []
        DeviceStates struct = struct()
        TransientHistory struct = struct('capacitors', struct(), 'inductors', struct())
        SweepOverrides struct = struct()
    end

    methods
        function obj = AnalysisContext(analysisType, nativeCircuit, options, varargin)
            obj.AnalysisType = string(analysisType);
            obj.NativeCircuit = nativeCircuit;
            obj.Options = options;
            for idx = 1:2:numel(varargin)
                name = string(varargin{idx});
                value = varargin{idx + 1};
                switch name
                    case "Omega"
                        obj.Omega = double(value);
                    case "Time"
                        obj.Time = double(value);
                    case "TimeStep"
                        obj.TimeStep = double(value);
                    case "OperatingPointSolution"
                        obj.OperatingPointSolution = value;
                    case "TransientHistory"
                        obj.TransientHistory = value;
                    case "SweepOverrides"
                        obj.SweepOverrides = value;
                    otherwise
                        error('spice:analysis:native:AnalysisContext:UnknownOption', 'Unknown AnalysisContext option %s.', name);
                end
            end
        end

        function setDeviceState(obj, deviceName, state)
            obj.DeviceStates.(obj.key(deviceName)) = state;
        end

        function state = deviceState(obj, deviceName)
            key = obj.key(deviceName);
            if isfield(obj.DeviceStates, key)
                state = obj.DeviceStates.(key);
            else
                state = struct();
            end
        end

        function value = overrideDcValue(obj, deviceName, defaultValue)
            key = obj.key(deviceName);
            if isfield(obj.SweepOverrides, key)
                value = obj.SweepOverrides.(key);
            else
                value = defaultValue;
            end
        end

        function item = capacitorHistory(obj, historyKey)
            key = obj.key(historyKey);
            if isfield(obj.TransientHistory.capacitors, key)
                item = obj.TransientHistory.capacitors.(key);
            else
                item = struct('voltage', 0, 'current', 0);
            end
        end

        function setCapacitorHistory(obj, historyKey, voltage, current)
            obj.TransientHistory.capacitors.(obj.key(historyKey)) = struct('voltage', voltage, 'current', current);
        end

        function item = inductorHistory(obj, historyKey)
            key = obj.key(historyKey);
            if isfield(obj.TransientHistory.inductors, key)
                item = obj.TransientHistory.inductors.(key);
            else
                item = struct('voltage', 0, 'current', 0);
            end
        end

        function setInductorHistory(obj, historyKey, voltage, current)
            obj.TransientHistory.inductors.(obj.key(historyKey)) = struct('voltage', voltage, 'current', current);
        end

        function clone = copy(obj)
            clone = spice.analysis.native.AnalysisContext(obj.AnalysisType, obj.NativeCircuit, obj.Options, ...
                'Omega', obj.Omega, 'Time', obj.Time, 'TimeStep', obj.TimeStep, ...
                'OperatingPointSolution', obj.OperatingPointSolution, ...
                'TransientHistory', obj.TransientHistory, ...
                'SweepOverrides', obj.SweepOverrides);
            clone.DeviceStates = obj.DeviceStates;
        end
    end

    methods (Access = private)
        function fieldKey = key(~, rawKey)
            fieldKey = matlab.lang.makeValidName(char(string(rawKey)));
        end
    end
end
