function result = buildHspiceTransientReference(circuit, tr0Audit)
% BUILDHSPICETRANSIENTREFERENCE Convert parsed HSPICE waveforms into the
% same result contract used by native and legacy transient comparisons.
% Only node-voltage probes are emitted because Dynamic + TR sign-off is
% currently driven by waveform voltage alignment rather than current probes.
arguments
    circuit (1,1) spice.model.Circuit
    tr0Audit struct
end

axis = struct('name', "time", 'values', tr0Audit.time(:).', 'unit', "s", 'scale', "linear");
signalTemplate = struct( ...
    'name', "", ...
    'kind', "nodeVoltage", ...
    'axisName', "time", ...
    'axisValues', axis.values, ...
    'unit', "V", ...
    'domain', "real", ...
    'values', [], ...
    'magnitude', [], ...
    'phaseDeg', []);
signals = repmat(signalTemplate, 0, 1);

availableSignals = strings(numel(tr0Audit.signals), 1);
for idx = 1:numel(tr0Audit.signals)
    availableSignals(idx) = tr0Audit.signals(idx).name;
end

for idx = 1:numel(circuit.Probes)
    probe = circuit.Probes{idx};
    if probe.Kind ~= "nodeVoltage"
        continue;
    end
    signalIndex = find(availableSignals == probe.Target, 1);
    if isempty(signalIndex)
        continue;
    end
    signal = signalTemplate;
    signal.name = probe.DisplayName;
    signal.values = tr0Audit.signals(signalIndex).values(:).';
    signals(end + 1, 1) = signal; %#ok<AGROW>
end

result = struct();
result.analysisType = "trans";
result.axis = axis;
result.signals = signals;
result.operatingPoint = struct();
result.deviceState = struct();
result.artifacts = struct();
result.meta = struct( ...
    'backend', "hspice", ...
    'backendReason', "hspice_tr0_reference", ...
    'newton', struct(), ...
    'acceptedByRegression', false);
end
