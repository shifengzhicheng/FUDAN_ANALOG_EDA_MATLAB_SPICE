function ir = build(circuit)
nodeMap = circuit.nodeIds();
elementCount = circuit.elementCount();

if isempty(nodeMap)
    nodeMap = 0;
end

elementNames = strings(elementCount, 1);
elementKinds = strings(elementCount, 1);
elementNodeIndices = cell(elementCount, 1);

for idx = 1:elementCount
    element = circuit.Elements{idx};
    elementNames(idx) = element.Name;
    elementKinds(idx) = element.Kind;
    nodeIds = element.nodeIds();
    [found, indices] = ismember(nodeIds, nodeMap);
    if ~all(found)
        error('spice:ir:NodeIndexMissing', 'Failed to map every node for element %s.', element.Name);
    end
    elementNodeIndices{idx} = indices;
end

ir = struct( ...
    'analysisType', circuit.Analysis.Type, ...
    'nodeMap', nodeMap(:), ...
    'elementNames', elementNames, ...
    'elementKinds', elementKinds, ...
    'elementNodeIndices', {elementNodeIndices}, ...
    'probeNames', circuit.probeNames(), ...
    'meta', struct( ...
        'elementCount', circuit.elementCount(), ...
        'probeCount', circuit.probeCount(), ...
        'nodeCount', numel(nodeMap)));
end
