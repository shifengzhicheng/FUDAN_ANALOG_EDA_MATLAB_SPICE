function outputNodes = nodeVoltageProbeTargets(circuit)
% NODEVOLTAGEPROBETARGETS Return unique node-voltage probe targets.
outputNodes = strings(0, 1);
for idx = 1:numel(circuit.Probes)
    probe = circuit.Probes{idx};
    if probe.Kind == "nodeVoltage"
        outputNodes(end + 1, 1) = probe.Target; %#ok<AGROW>
    end
end
outputNodes = unique(outputNodes, 'stable');
end
