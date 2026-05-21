classdef LegacyCollector < handle
    properties (Access = private)
        RName = {}
        RN1 = {}
        RN2 = {}
        RValue = {}
        CName = {}
        CN1 = {}
        CN2 = {}
        CValue = {}
        LName = {}
        LN1 = {}
        LN2 = {}
        LValue = {}
        SourceName = {}
        SourceN1 = {}
        SourceN2 = {}
        SourceType = {}
        SourceDcValue = {}
        SourceAcValue = {}
        SourceFreq = {}
        SourcePhase = {}
        MosName = {}
        MosD = {}
        MosG = {}
        MosS = {}
        MosType = {}
        MosW = {}
        MosL = {}
        MosId = {}
        DiodeName = {}
        DiodeN1 = {}
        DiodeN2 = {}
        DiodeId = {}
        BjtName = {}
        BjtC = {}
        BjtB = {}
        BjtE = {}
        BjtType = {}
        BjtArea = {}
        BjtId = {}
        MosModels cell = {}
        DiodeModels cell = {}
        BjtModels cell = {}
        PlotCards cell = cell(0, 1)
    end

    methods
        function addPassive(obj, kind, name, nodeTokens, value)
            switch upper(char(kind))
                case 'R'
                    [obj.RName, obj.RN1, obj.RN2, obj.RValue] = obj.appendPassive(obj.RName, obj.RN1, obj.RN2, obj.RValue, name, nodeTokens, value);
                case 'C'
                    [obj.CName, obj.CN1, obj.CN2, obj.CValue] = obj.appendPassive(obj.CName, obj.CN1, obj.CN2, obj.CValue, name, nodeTokens, value);
                case 'L'
                    [obj.LName, obj.LN1, obj.LN2, obj.LValue] = obj.appendPassive(obj.LName, obj.LN1, obj.LN2, obj.LValue, name, nodeTokens, value);
                otherwise
                    error('spice:stamp:LegacyCollector:UnsupportedPassive', 'Unsupported passive kind %s.', kind);
            end
        end

        function addSource(obj, ~, name, nodeTokens, params)
            obj.SourceName{end + 1} = char(name);
            obj.SourceN1{end + 1} = char(nodeTokens(1));
            obj.SourceN2{end + 1} = char(nodeTokens(2));
            obj.SourceType{end + 1} = params.waveform;
            obj.SourceDcValue{end + 1} = obj.formatNumber(params.dcValue);
            obj.SourceAcValue{end + 1} = obj.formatNumber(params.acValue);
            obj.SourceFreq{end + 1} = obj.formatNumber(params.freq);
            obj.SourcePhase{end + 1} = obj.formatNumber(params.phase);
        end

        function addMosfet(obj, device)
            obj.MosName{end + 1} = char(device.Name);
            obj.MosD{end + 1} = char(device.NodeTokens(1));
            obj.MosG{end + 1} = char(device.NodeTokens(2));
            obj.MosS{end + 1} = char(device.NodeTokens(3));
            obj.MosType{end + 1} = device.Parameters.polarity;
            obj.MosW{end + 1} = obj.formatNumber(device.Parameters.width);
            obj.MosL{end + 1} = obj.formatNumber(device.Parameters.length);
            obj.MosId{end + 1} = obj.formatInteger(device.Parameters.modelId);
        end

        function addDiode(obj, device)
            obj.DiodeName{end + 1} = char(device.Name);
            obj.DiodeN1{end + 1} = char(device.NodeTokens(1));
            obj.DiodeN2{end + 1} = char(device.NodeTokens(2));
            obj.DiodeId{end + 1} = obj.formatInteger(device.Parameters.modelId);
        end

        function addBjt(obj, device)
            obj.BjtName{end + 1} = char(device.Name);
            obj.BjtC{end + 1} = char(device.NodeTokens(1));
            obj.BjtB{end + 1} = char(device.NodeTokens(2));
            obj.BjtE{end + 1} = char(device.NodeTokens(3));
            obj.BjtType{end + 1} = device.Parameters.polarity;
            obj.BjtArea{end + 1} = obj.formatNumber(device.Parameters.junctionArea);
            obj.BjtId{end + 1} = obj.formatInteger(device.Parameters.modelId);
        end

        function addMosModel(obj, model)
            obj.MosModels{end + 1, 1} = model;
        end

        function addDiodeModel(obj, model)
            obj.DiodeModels{end + 1, 1} = model;
        end

        function addBjtModel(obj, model)
            obj.BjtModels{end + 1, 1} = model;
        end

        function addProbe(obj, probe)
            switch probe.Kind
                case "nodeVoltage"
                    obj.PlotCards{end + 1, 1} = {'.plotnv', char(probe.Target)};
                case "deviceCurrent"
                    obj.PlotCards{end + 1, 1} = {'.plotnc', sprintf('%s(%s)', probe.Target, probe.Port)};
                otherwise
                    error('spice:stamp:LegacyCollector:UnsupportedProbe', 'Unsupported probe kind %s.', probe.Kind);
            end
        end

        function legacy = build(obj)
            mosModels = obj.buildMosModelCells();
            diodeModels = obj.buildDiodeModelCells();
            bjtModels = obj.buildBjtModelCells();

            rInfo = containers.Map({'Name', 'N1', 'N2', 'Value'}, {obj.RName, obj.RN1, obj.RN2, obj.RValue});
            cInfo = containers.Map({'Name', 'N1', 'N2', 'Value'}, {obj.CName, obj.CN1, obj.CN2, obj.CValue});
            lInfo = containers.Map({'Name', 'N1', 'N2', 'Value'}, {obj.LName, obj.LN1, obj.LN2, obj.LValue});
            rclInfo = containers.Map({'RINFO', 'CINFO', 'LINFO'}, {rInfo, cInfo, lInfo});

            sourceInfo = containers.Map( ...
                {'Name', 'N1', 'N2', 'type', 'DcValue', 'AcValue', 'Freq', 'Phase'}, ...
                {obj.SourceName, obj.SourceN1, obj.SourceN2, obj.SourceType, obj.SourceDcValue, obj.SourceAcValue, obj.SourceFreq, obj.SourcePhase});
            mosInfo = containers.Map( ...
                {'Name', 'd', 'g', 's', 'type', 'W', 'L', 'ID', 'MODEL'}, ...
                {obj.MosName, obj.MosD, obj.MosG, obj.MosS, obj.MosType, obj.MosW, obj.MosL, obj.MosId, mosModels});
            diodeInfo = containers.Map( ...
                {'Name', 'N1', 'N2', 'ID', 'MODEL'}, ...
                {obj.DiodeName, obj.DiodeN1, obj.DiodeN2, obj.DiodeId, diodeModels});
            bjtInfo = containers.Map( ...
                {'Name', 'c', 'b', 'e', 'type', 'Junctionarea', 'ID', 'MODEL'}, ...
                {obj.BjtName, obj.BjtC, obj.BjtB, obj.BjtE, obj.BjtType, obj.BjtArea, obj.BjtId, bjtModels});

            rclInfo('CINFO') = compCINFO(rclInfo('CINFO'), mosInfo, bjtInfo);

            legacy = struct();
            legacy.RCLINFO = rclInfo;
            legacy.SourceINFO = sourceInfo;
            legacy.MOSINFO = mosInfo;
            legacy.DIODEINFO = diodeInfo;
            legacy.BJTINFO = bjtInfo;
            legacy.PlotCards = obj.PlotCards;
        end
    end

    methods (Access = private)
        function [names, n1, n2, values] = appendPassive(obj, names, n1, n2, values, name, nodeTokens, value)
            names{end + 1} = char(name);
            n1{end + 1} = char(nodeTokens(1));
            n2{end + 1} = char(nodeTokens(2));
            values{end + 1} = obj.formatNumber(value);
        end

        function cells = buildMosModelCells(obj)
            maxId = max([0; cellfun(@(item) item.Id, obj.MosModels)]);
            cells = repmat({[]}, 1, maxId);
            for idx = 1:numel(obj.MosModels)
                model = obj.MosModels{idx};
                cells{model.Id} = [model.Id; model.Parameters.vt; model.Parameters.mu; model.Parameters.cox; model.Parameters.lambda; model.Parameters.cj0];
            end
        end

        function cells = buildDiodeModelCells(obj)
            maxId = max([0; cellfun(@(item) item.Id, obj.DiodeModels)]);
            cells = repmat({[]}, 1, maxId);
            for idx = 1:numel(obj.DiodeModels)
                model = obj.DiodeModels{idx};
                cells{model.Id} = [model.Id; model.Parameters.is];
            end
        end

        function cells = buildBjtModelCells(obj)
            maxId = max([0; cellfun(@(item) item.Id, obj.BjtModels)]);
            cells = repmat({[]}, 1, maxId);
            for idx = 1:numel(obj.BjtModels)
                model = obj.BjtModels{idx};
                cells{model.Id} = [model.Id; model.Parameters.js; model.Parameters.alphaF; model.Parameters.alphaR; model.Parameters.cje; model.Parameters.cjc];
            end
        end

        function text = formatNumber(~, value)
            text = num2str(value, '%.15g');
        end

        function text = formatInteger(~, value)
            text = sprintf('%d', round(value));
        end
    end
end
