function indices = dynamicTransientErrorNodeIndices(circuit, nativeCircuit)
% DYNAMICTRANSIENTERRORNODEINDICES Prefer probed node voltages for LTE checks.
indices = zeros(0, 1);
for idx = 1:numel(circuit.Probes)
    probe = circuit.Probes{idx};
    if probe.Kind ~= "nodeVoltage"
        continue;
    end

    nodeIndex = nativeCircuit.nodeVarIndex(probe.Target);
    if nodeIndex > 0
        indices(end + 1, 1) = nodeIndex; %#ok<AGROW>
    end
end
indices = unique(indices, 'stable');
end
