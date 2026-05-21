function signals = buildSignals(circuit, analysisType, axis, nativeCircuit, solutionMatrix)
% BUILDSIGNALS Convert native solution matrices into public signal structs.
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

signals = repmat(signalTemplate, numel(circuit.Probes), 1);
for idx = 1:numel(circuit.Probes)
    probe = circuit.Probes{idx};
    signal = signalTemplate;
    signal.name = probe.DisplayName;
    switch probe.Kind
        case "nodeVoltage"
            signal.kind = "nodeVoltage";
            signal.unit = "V";
            values = nativeCircuit.nodeVoltage(solutionMatrix, nativeCircuit.nodeVarIndex(probe.Target));
        case "deviceCurrent"
            signal.kind = "deviceCurrent";
            signal.unit = "A";
            device = nativeCircuit.findDevice(probe.Target);
            values = device.currentForProbe(analysisType, nativeCircuit, solutionMatrix, axis.values, probe.Port);
        otherwise
            error('spice:analysis:native:UnknownProbeKind', 'Unknown probe kind %s.', probe.Kind);
    end
    signal.values = values;
    if ~isreal(values)
        signal.domain = "complex";
        signal.magnitude = abs(values);
        signal.phaseDeg = rad2deg(angle(values));
    end
    signals(idx, 1) = signal;
end
end
