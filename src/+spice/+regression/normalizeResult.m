function normalized = normalizeResult(result, probeSelection)
% NORMALIZERESULT Flatten a SimulationResult into comparable signal slices.
% The comparator works on this normalized view so native, legacy, and audit
% loaders all share one axis/signal contract before tolerances are applied.
if nargin < 2 || (isstring(probeSelection) && isscalar(probeSelection) && probeSelection == "all")
    selectedNames = string({result.signals.name});
else
    selectedNames = string(probeSelection);
end

normalized = struct();
normalized.analysisType = string(result.analysisType);
normalized.axis = result.axis;
normalized.signals = repmat(struct( ...
    'name', "", ...
    'kind', "", ...
    'unit', "", ...
    'domain', "real", ...
    'axisValues', [], ...
    'values', [], ...
    'magnitude', [], ...
    'phaseDeg', []), 0, 1);
normalized.signalNames = strings(0, 1);
normalized.operatingPoint = normalizeOperatingPoint(result);

for idx = 1:numel(result.signals)
    signal = result.signals(idx);
    if ~any(string(signal.name) == selectedNames)
        continue;
    end
    signal = sortSignalForComparison(result.analysisType, signal);
    normalized.signals(end + 1, 1) = struct( ...
        'name', string(signal.name), ...
        'kind', string(signal.kind), ...
        'unit', string(signal.unit), ...
        'domain', string(signal.domain), ...
        'axisValues', signal.axisValues, ...
        'values', signal.values, ...
        'magnitude', signal.magnitude, ...
        'phaseDeg', signal.phaseDeg); %#ok<AGROW>
end
normalized.signalNames = string({normalized.signals.name}).';
end

function signal = sortSignalForComparison(analysisType, signal)
if string(analysisType) ~= "pz" || isempty(signal.values) || ~isvector(signal.values)
    return;
end
values = signal.values(:);
if ~isreal(values)
    [~, order] = sortrows([real(values), imag(values)], [1 2]);
else
    [~, order] = sort(values);
end
signal.values = values(order).';
if ~isempty(signal.magnitude)
    signal.magnitude = signal.magnitude(order).';
end
if ~isempty(signal.phaseDeg)
    signal.phaseDeg = signal.phaseDeg(order).';
end
if ~isempty(signal.axisValues)
    signal.axisValues = signal.axisValues(order).';
end
end

function operatingPoint = normalizeOperatingPoint(result)
operatingPoint = struct('nodeIds', zeros(0, 1), 'values', zeros(0, 1));
if ~isfield(result, 'operatingPoint') || isempty(result.operatingPoint) || ~isfield(result.operatingPoint, 'nodeMap')
    return;
end

nodeMap = result.operatingPoint.nodeMap;
solution = result.operatingPoint.solution;
if isempty(nodeMap) || isempty(solution)
    return;
end

nodeIds = zeros(numel(nodeMap), 1);
nodeIndexes = zeros(numel(nodeMap), 1);
if isstruct(nodeMap)
    fields = fieldnames(nodeMap);
    for idx = 1:numel(fields)
        nodeIds(idx) = str2double(regexprep(fields{idx}, '^N', ''));
        nodeIndexes(idx) = nodeMap.(fields{idx});
    end
elseif isa(nodeMap, 'containers.Map')
    keysList = keys(nodeMap);
    valuesList = values(nodeMap);
    nodeIds = zeros(numel(keysList), 1);
    nodeIndexes = zeros(numel(keysList), 1);
    for idx = 1:numel(keysList)
        nodeIds(idx) = str2double(regexprep(string(keysList{idx}), '^N', ''));
        nodeIndexes(idx) = valuesList{idx};
    end
else
    nodeIds = nodeMap(:);
    nodeIndexes = (1:numel(nodeIds)).';
end

keep = nodeIndexes >= 1 & nodeIndexes <= numel(solution);
operatingPoint.nodeIds = nodeIds(keep);
operatingPoint.values = solution(nodeIndexes(keep));
end
