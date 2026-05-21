classdef NativeCircuit < handle
    % NATIVECIRCUIT Compile a Circuit object into native-solver indexing.
    % The class centralizes node numbering, branch-variable numbering,
    % model lookup, and device lookup for the native analysis backend.
    properties (SetAccess = private)
        Circuit
        NodeIds (:,1) double
        BranchNames (:,1) string = strings(0, 1)
        TransientMethod (1,1) string = "BE"
    end

    properties
        OperatingPointSolution = []
        OperatingPointContext = []
    end

    properties (Access = private)
        NodeLookup (:,1) double
        BranchIndexByName = containers.Map('KeyType', 'char', 'ValueType', 'double')
        ConfiguredAnalysisType (1,1) string = ""
        ConfiguredTransientMethod (1,1) string = ""
        MosModelById cell = {}
        DiodeModelById cell = {}
        BjtModelById cell = {}
    end

    methods
        function obj = NativeCircuit(circuit)
            obj.Circuit = circuit;
            nodeIds = circuit.nodeIds();
            nodeIds = nodeIds(nodeIds ~= 0);
            obj.NodeIds = nodeIds(:);
            if isempty(obj.NodeIds)
                obj.NodeLookup = zeros(1, 1);
            else
                obj.NodeLookup = zeros(max(obj.NodeIds) + 1, 1);
                for idx = 1:numel(obj.NodeIds)
                    obj.NodeLookup(obj.NodeIds(idx) + 1) = idx;
                end
            end
            obj.buildModelCaches();
        end

        function [tf, reason] = supportsAnalysis(obj, analysisType, options)
            analysisType = string(analysisType);
            mappedType = obj.nativeSupportType(analysisType);
            if mappedType == ""
                tf = false;
                reason = "analysis_not_supported";
                return;
            end
            if analysisType == "shoot" && upper(string(options.TransientMethod)) ~= "BE"
                tf = false;
                reason = "shoot_tr_not_supported_yet";
                return;
            end
            for idx = 1:numel(obj.Circuit.Elements)
                if ~obj.Circuit.Elements{idx}.supportsNativeAnalysis(mappedType, options)
                    tf = false;
                    reason = "device_unsupported:" + obj.Circuit.Elements{idx}.Name;
                    return;
                end
            end
            tf = true;
            reason = "native_supported";
        end

        function configureAnalysis(obj, analysisType, varargin)
            analysisType = string(analysisType);
            transientMethod = obj.TransientMethod;
            if analysisType == "trans"
                for idx = 1:2:numel(varargin)
                    if string(varargin{idx}) == "TransientMethod"
                        transientMethod = string(varargin{idx + 1});
                    end
                end
            end

            if obj.ConfiguredAnalysisType == analysisType && obj.ConfiguredTransientMethod == transientMethod
                return;
            end

            obj.TransientMethod = transientMethod;
            branchChunks = cell(numel(obj.Circuit.Elements), 1);
            branchCount = 0;
            for idx = 1:numel(obj.Circuit.Elements)
                branchNames = string(obj.Circuit.Elements{idx}.branchVariableNames(analysisType));
                if ~isempty(branchNames)
                    branchNames = branchNames(:);
                    branchChunks{idx} = branchNames;
                    branchCount = branchCount + numel(branchNames);
                end
            end
            obj.BranchNames = obj.flattenBranchNames(branchChunks, branchCount);
            obj.BranchIndexByName = obj.buildBranchIndex(obj.BranchNames);
            obj.ConfiguredAnalysisType = analysisType;
            obj.ConfiguredTransientMethod = transientMethod;
        end

        function index = nodeVarIndex(obj, nodeToken)
            nodeId = str2double(string(nodeToken));
            if isnan(nodeId)
                error('spice:analysis:native:NonNumericNode', 'Node token %s is not numeric.', string(nodeToken));
            end
            if nodeId == 0
                index = 0;
                return;
            end
            if nodeId + 1 > numel(obj.NodeLookup) || obj.NodeLookup(nodeId + 1) == 0
                error('spice:analysis:native:UnknownNode', 'Node %g is not present in the native node map.', nodeId);
            end
            index = obj.NodeLookup(nodeId + 1);
        end

        function voltage = nodeVoltage(~, solutionMatrix, nodeIndex)
            if nodeIndex == 0
                voltage = zeros(1, size(solutionMatrix, 2));
            else
                voltage = solutionMatrix(nodeIndex, :);
            end
        end

        function branchIndex = branchVarIndex(obj, branchName)
            key = char(string(branchName));
            if ~isKey(obj.BranchIndexByName, key)
                error('spice:analysis:native:UnknownBranch', 'Unknown native branch variable %s.', string(branchName));
            end
            branchIndex = obj.BranchIndexByName(key);
        end

        function current = branchCurrent(~, solutionMatrix, branchIndex)
            current = solutionMatrix(branchIndex, :);
        end

        function count = matrixSize(obj)
            count = numel(obj.NodeIds) + numel(obj.BranchNames);
        end

        function labels = solutionLabels(obj)
            labels = strings(obj.matrixSize(), 1);
            for idx = 1:numel(obj.NodeIds)
                labels(idx) = "V(" + string(obj.NodeIds(idx)) + ")";
            end
            for idx = 1:numel(obj.BranchNames)
                labels(numel(obj.NodeIds) + idx) = "I(" + obj.BranchNames(idx) + ")";
            end
        end

        function device = findDevice(obj, name)
            for idx = 1:numel(obj.Circuit.Elements)
                if obj.Circuit.Elements{idx}.Name == string(name)
                    device = obj.Circuit.Elements{idx};
                    return;
                end
            end
            error('spice:analysis:native:UnknownDevice', 'Unknown device %s.', string(name));
        end

        function model = mosModel(obj, modelId)
            model = obj.modelById(obj.MosModelById, modelId, "MOS");
        end

        function model = diodeModel(obj, modelId)
            model = obj.modelById(obj.DiodeModelById, modelId, "Diode");
        end

        function model = bjtModel(obj, modelId)
            model = obj.modelById(obj.BjtModelById, modelId, "BJT");
        end

        function guess = clampNodeVoltages(obj, guess)
            maxVoltage = obj.estimatedSupplyVoltage();
            if maxVoltage <= 0 || isempty(guess)
                return;
            end
            nodeCount = numel(obj.NodeIds);
            guess(1:nodeCount) = min(max(guess(1:nodeCount), -0.5), maxVoltage + 0.5);
        end

        function maxVoltage = estimatedSupplyVoltage(obj)
            maxVoltage = 0;
            for idx = 1:numel(obj.Circuit.Elements)
                element = obj.Circuit.Elements{idx};
                if isa(element, 'spice.model.VoltageSource')
                    maxVoltage = max(maxVoltage, abs(element.Parameters.dcValue));
                end
            end
            if maxVoltage == 0
                maxVoltage = 5;
            end
        end
    end

    methods (Access = private)
        function mappedType = nativeSupportType(~, analysisType)
            switch string(analysisType)
                case {"dc", "dcsweep", "ac", "trans"}
                    mappedType = string(analysisType);
                case "shoot"
                    mappedType = "trans";
                case "pz"
                    mappedType = "ac";
                otherwise
                    mappedType = "";
            end
        end

        function buildModelCaches(obj)
            obj.MosModelById = obj.cacheModels(obj.Circuit.Models.Mos);
            obj.DiodeModelById = obj.cacheModels(obj.Circuit.Models.Diode);
            obj.BjtModelById = obj.cacheModels(obj.Circuit.Models.Bjt);
        end

        function branchNames = flattenBranchNames(~, branchChunks, branchCount)
            if branchCount == 0
                branchNames = strings(0, 1);
                return;
            end

            branchNames = strings(branchCount, 1);
            writeIndex = 1;
            for idx = 1:numel(branchChunks)
                chunk = branchChunks{idx};
                if isempty(chunk)
                    continue;
                end
                nextIndex = writeIndex + numel(chunk) - 1;
                branchNames(writeIndex:nextIndex) = chunk;
                writeIndex = nextIndex + 1;
            end
        end

        function branchIndexByName = buildBranchIndex(obj, branchNames)
            branchIndexByName = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for idx = 1:numel(branchNames)
                key = char(branchNames(idx));
                if isKey(branchIndexByName, key)
                    error('spice:analysis:native:DuplicateBranch', ...
                        'Duplicate native branch variable %s.', string(branchNames(idx)));
                end
                branchIndexByName(key) = numel(obj.NodeIds) + idx;
            end
        end

        function cache = cacheModels(~, models)
            if isempty(models)
                cache = {};
                return;
            end
            maxId = max(cellfun(@(item) item.Id, models));
            cache = cell(1, maxId);
            for idx = 1:numel(models)
                cache{models{idx}.Id} = models{idx};
            end
        end

        function model = modelById(~, cache, modelId, modelType)
            if modelId < 1 || modelId > numel(cache) || isempty(cache{modelId})
                error('spice:analysis:native:MissingModel', '%s model %d is not available.', modelType, modelId);
            end
            model = cache{modelId};
        end
    end
end
