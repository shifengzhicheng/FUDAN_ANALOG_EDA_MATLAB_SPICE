function signals = buildSignals(probes, analysisType, axis, context)
signalTemplate = struct( ...
    'name', "", ...
    'kind', "", ...
    'axisName', string(axis.name), ...
    'axisValues', axis.values, ...
    'unit', "", ...
    'domain', "real", ...
    'values', [], ...
    'magnitude', [], ...
    'phaseDeg', []);

signals = repmat(signalTemplate, 0, 1);
resultMatrix = normalizeResultMatrix(context.resultMatrix);

for idx = 1:numel(probes)
    probe = probes(idx);
    signal = signalTemplate;
    signal.name = probe.displayName;

    switch probe.kind
        case "nodeVoltage"
            nodeId = str2double(probe.target);
            signal.kind = "nodeVoltage";
            signal.unit = "V";
            rowIndex = find(context.nodeMap == nodeId, 1);
            if isempty(rowIndex)
                error('spice:buildSignals:UnknownNode', 'Probe node %s not found in node map.', probe.target);
            end
            values = resultMatrix(rowIndex, :);
        case "deviceCurrent"
            signal.kind = "deviceCurrent";
            signal.unit = "A";
            localContext = context;
            localContext.resultMatrix = resultMatrix;
            values = computeCurrentSignal(probe, analysisType, localContext);
        otherwise
            error('spice:buildSignals:UnknownProbe', 'Unknown probe kind %s.', probe.kind);
    end

    signal.values = values;
    if ~isreal(values)
        signal.domain = "complex";
        signal.magnitude = abs(values);
        signal.phaseDeg = rad2deg(angle(values));
    end
    signals(end + 1, 1) = signal; %#ok<AGROW>
end

function resultMatrix = normalizeResultMatrix(resultMatrix)
if isvector(resultMatrix)
    resultMatrix = resultMatrix(:);
end
end
end

function values = computeCurrentSignal(probe, analysisType, context)
deviceName = char(probe.target);
portName = char(probe.port);

switch analysisType
    case {"dc", "dcsweep"}
        values = getCurrentDC(deviceName, portName, context.linerNet, context.xLabels, context.resultMatrix);
    case "ac"
        values = getCurrentAC(deviceName, portName, context.linerNet, context.xLabels, context.resultMatrix, context.frequencyVector);
    case {"trans", "shoot"}
        values = getCurrentTrans(deviceName, portName, context.linerNet, context.xLabels, context.resultMatrix);
    otherwise
        error('spice:buildSignals:UnsupportedAnalysis', 'Current extraction is unsupported for %s.', analysisType);
end
end
