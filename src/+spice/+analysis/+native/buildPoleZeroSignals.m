function signals = buildPoleZeroSignals(gMatrix, eMatrix, inputVector, outputNodes, nativeCircuit)
% BUILDPOLEZEROSIGNALS Compute descriptor-form PZ roots for probed outputs.
gMatrix = full(gMatrix);
eMatrix = full(eMatrix);
inputVector = full(inputVector(:));

poleRoots = finiteRoots(eig(-gMatrix, eMatrix));
signals = repmat(struct('name', "", 'kind', "", 'axisName', "root_index", 'axisValues', [], ...
    'unit', "rad/s", 'domain', "complex", 'values', [], 'magnitude', [], 'phaseDeg', []), 0, 1);

for idx = 1:numel(outputNodes)
    outputNode = outputNodes(idx);
    outputIndex = nativeCircuit.nodeVarIndex(outputNode);
    outputSelector = zeros(1, size(gMatrix, 1));
    outputSelector(outputIndex) = 1;
    zeroRoots = finiteRoots(computePzZeros(gMatrix, eMatrix, inputVector, outputSelector));
    signals(end + 1, 1) = makePzSignal("Zeros(" + outputNode + ")", "zeroRoots", zeroRoots); %#ok<AGROW>
    signals(end + 1, 1) = makePzSignal("Poles(" + outputNode + ")", "poleRoots", poleRoots); %#ok<AGROW>
end
end

function roots = computePzZeros(gMatrix, eMatrix, inputVector, outputSelector)
augG = [gMatrix, inputVector; outputSelector, 0];
augE = [eMatrix, zeros(size(eMatrix, 1), 1); zeros(1, size(eMatrix, 2) + 1)];
roots = eig(-augG, augE);
end

function roots = finiteRoots(values)
values = values(:).';
mask = isfinite(real(values)) & isfinite(imag(values));
roots = values(mask);
if isempty(roots)
    return;
end

[~, order] = sortrows([real(roots(:)), imag(roots(:))], [1 2]);
roots = roots(order).';
end

function signal = makePzSignal(name, kind, values)
signal = struct( ...
    'name', string(name), ...
    'kind', string(kind), ...
    'axisName', "root_index", ...
    'axisValues', 1:numel(values), ...
    'unit', "rad/s", ...
    'domain', "complex", ...
    'values', values, ...
    'magnitude', abs(values), ...
    'phaseDeg', rad2deg(angle(values)));
end
