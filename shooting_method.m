function [ResData, DeviceValues, printTimePoint] = shooting_method( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, ~, Error, stepTime, totalTime, ~)
% SHOOTING_METHOD Find a periodic companion state, then simulate it.
% Strict convergence is checked on the values that seed the next transient
% period: capacitor companion voltages and inductor companion currents.
% Algebraic node voltages are recomputed from those states for each trial.

LinerNet('Value') = LinerNet('Value')';
[CINFO, LINFO] = prepareCompanionInfo(CINFO, LINFO);

[~, initialDeviceValue] = TranInit(LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, Error, stepTime);
period = sourceFundamentalPeriod(SinINFO('Freq'));
printTimePoint = 0:stepTime:totalTime;
stateInfo = buildShootingStateInfo(LinerNet, CINFO, LINFO);

tolerance = shootingTolerance(Error);
coarseStep = 5 * stepTime;
maxCoarseFixedPointIterations = 500;
maxCoarseNewtonIterations = 4;
maxFineFixedPointIterations = 20;
maxFineNewtonIterations = 4;

startDynamicState = extractDynamicState(initialDeviceValue, stateInfo);
if isempty(startDynamicState)
    error('spice:shooting:NoDynamicState', 'Shooting analysis requires independent capacitor or inductor states.');
end

baseDeviceValue = initialDeviceValue(:);
[trial, ~] = evaluateShootingResidual( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, baseDeviceValue, startDynamicState, stateInfo, coarseStep, period, tolerance);

[trial, ~, coarseFixedPointIterations] = fixedPointShootingRefine( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, coarseStep, period, tolerance, maxCoarseFixedPointIterations);
[trial, ~, coarseNewtonIterations] = newtonShootingRefine( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, coarseStep, period, tolerance, maxCoarseNewtonIterations);

% Re-check convergence using the original timestep.  Coarse shooting is only
% an accelerator; the accepted periodic state must pass the accurate map.
[strictTrial, ~] = evaluateShootingResidual( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial.startDeviceValue, ...
    trial.startDynamicState, stateInfo, stepTime, period, tolerance);

[strictTrial, ~, fineFixedPointIterations] = fixedPointShootingRefine( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, strictTrial, stateInfo, stepTime, period, tolerance, maxFineFixedPointIterations);
[strictTrial, strictMetric, fineNewtonIterations] = newtonShootingRefine( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, strictTrial, stateInfo, stepTime, period, tolerance, maxFineNewtonIterations);

if ~strictMetric.converged
    error('spice:shooting:NoConvergence', ...
        ['Shooting did not satisfy dynamic-state convergence. ', ...
        'strict voltage metric %.3g, strict current metric %.3g. ', ...
        'coarse fixed-point %d, coarse Newton %d, fine fixed-point %d, fine Newton %d.'], ...
        strictMetric.voltageMetric, strictMetric.currentMetric, ...
        coarseFixedPointIterations, coarseNewtonIterations, fineFixedPointIterations, fineNewtonIterations);
end

% Run two accurate periods before producing the requested waveform.  This
% preserves the legacy polish step after shooting convergence.
[~, ~, polishedSolution, polishedDeviceValue] = runShootingPeriod( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, ...
    strictTrial.endSolution, strictTrial.endDeviceValue, stepTime, 2 * period);

LinerNet('Value') = polishedDeviceValue;
[ResData, DeviceValues] = Trans( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, polishedSolution, stepTime, totalTime);
end

function [CINFO, LINFO] = prepareCompanionInfo(CINFO, LINFO)
CValue = CINFO('Value')';
LValue = LINFO('Value')';
CINFO('R') = 0.5 ./ CValue;
LINFO('R') = 2 * LValue;
LINFO('Value') = LINFO('Value')';
CINFO('Value') = CINFO('Value')';
end

function period = sourceFundamentalPeriod(frequencies)
fundamentalFrequency = frequencies(1);
for idx = 2:length(frequencies)
    fundamentalFrequency = gcd(fundamentalFrequency, frequencies(idx));
end
period = 1 / fundamentalFrequency;
end

function tolerance = shootingTolerance(errorTolerance)
tolerance = struct( ...
    'voltageAbs', max(1e4 * errorTolerance, 1e-2), ...
    'voltageRel', 1e-3, ...
    'currentAbs', max(1e2 * errorTolerance, 1e-5), ...
    'currentRel', 1e-3);
end

function stateInfo = buildShootingStateInfo(LinerNet, CINFO, LINFO)
capacitorCount = numel(CINFO('Name'));
inductorCount = numel(LINFO('Name'));
capacitorDeviceIndex = (CINFO('CLine') + 2 * (1:capacitorCount) - 1).';
inductorDeviceIndex = (LINFO('LLine') + 2 * (1:inductorCount) - 2).';

capacitorActive = true(capacitorCount, 1);
activeCapacitorDeviceIndex = zeros(0, 1);
capacitorGroupIndex = zeros(0, 1);
capacitorGroupSign = zeros(0, 1);
if capacitorCount > 0
    sourceComponent = voltageSourceComponents(LinerNet, CINFO);
    capacitorNodePairs = CINFO('NodeMat');
    capacitorActive = sourceComponent(capacitorNodePairs(:, 1)) ~= sourceComponent(capacitorNodePairs(:, 2));
    [capacitorGroupIndex, capacitorGroupSign] = capacitorStateGroups(capacitorNodePairs(capacitorActive, :));
    activeCapacitorDeviceIndex = capacitorDeviceIndex(capacitorActive);
end

% Capacitors inside one ideal-voltage-source component have prescribed,
% periodic branch voltage. Parallel capacitors share one independent branch
% voltage state, which keeps the Newton matrix from carrying duplicate rows.
stateInfo = struct( ...
    'capacitorCount', max([0; capacitorGroupIndex]), ...
    'inductorCount', inductorCount, ...
    'capacitorDeviceIndex', activeCapacitorDeviceIndex, ...
    'capacitorGroupIndex', capacitorGroupIndex, ...
    'capacitorGroupSign', capacitorGroupSign, ...
    'inductorDeviceIndex', inductorDeviceIndex, ...
    'excludedCapacitorCount', capacitorCount - nnz(capacitorActive));
end

function [groupIndex, groupSign] = capacitorStateGroups(nodePairs)
if isempty(nodePairs)
    groupIndex = zeros(0, 1);
    groupSign = zeros(0, 1);
    return;
end

canonicalPairs = nodePairs;
groupSign = ones(size(nodePairs, 1), 1);
reversed = nodePairs(:, 1) > nodePairs(:, 2);
canonicalPairs(reversed, :) = nodePairs(reversed, [2, 1]);
groupSign(reversed) = -1;
[~, ~, groupIndex] = unique(canonicalPairs, 'rows');
end

function component = voltageSourceComponents(LinerNet, CINFO)
netN1 = LinerNet('N1');
netN2 = LinerNet('N2');
capacitorNodePairs = CINFO('NodeMat');
maxNetNode = max([netN1(:); netN2(:)]) + 1;
maxCapNode = 1;
if ~isempty(capacitorNodePairs)
    maxCapNode = max(capacitorNodePairs(:));
end
nodeCount = max(maxNetNode, maxCapNode);
parent = 1:nodeCount;

names = LinerNet('Name');
lastIndependentSource = CINFO('CLine') - 1;
for idx = 1:lastIndependentSource
    name = names{idx};
    if ischar(name) && strncmp(name, 'V', 1)
        parent = unionNodes(parent, netN1(idx) + 1, netN2(idx) + 1);
    end
end

component = zeros(nodeCount, 1);
for node = 1:nodeCount
    component(node) = rootOf(parent, node);
end
[~, ~, component] = unique(component);
end

function parent = unionNodes(parent, firstNode, secondNode)
firstRoot = rootOf(parent, firstNode);
secondRoot = rootOf(parent, secondNode);
if firstRoot ~= secondRoot
    parent(secondRoot) = firstRoot;
end
end

function root = rootOf(parent, node)
root = node;
while parent(root) ~= root
    root = parent(root);
end
end

function [trial, metric] = evaluateShootingResidual( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, baseDeviceValue, dynamicState, stateInfo, step, period, tolerance)
startDeviceValue = applyDynamicState(baseDeviceValue, dynamicState, stateInfo);
[startSolution, startDeviceValue] = solveConsistentInitialPoint( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, startDeviceValue, Error);

[~, ~, endSolution, endDeviceValue] = runShootingPeriod( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, startSolution, startDeviceValue, step, period);

endDynamicState = extractDynamicState(endDeviceValue, stateInfo);
residual = endDynamicState - dynamicState;
metric = dynamicResidualMetric(dynamicState, endDynamicState, stateInfo, tolerance);

trial = struct( ...
    'startSolution', startSolution, ...
    'startDeviceValue', startDeviceValue, ...
    'startDynamicState', dynamicState, ...
    'endSolution', endSolution, ...
    'endDeviceValue', endDeviceValue, ...
    'endDynamicState', endDynamicState, ...
    'residual', residual, ...
    'metric', metric);
end

function [trial, metric, iterationCount] = fixedPointShootingRefine( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, step, period, tolerance, maxIterations)
% Picard iteration is cheap and gives Newton a better starting point.
metric = trial.metric;
iterationCount = 0;
while ~metric.converged && iterationCount < maxIterations
    iterationCount = iterationCount + 1;
    [trial, metric] = evaluateShootingResidual( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, ...
        trial.endDeviceValue, trial.endDynamicState, stateInfo, step, period, tolerance);
end
end

function [trial, metric, iterationCount] = newtonShootingRefine( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, step, period, tolerance, maxIterations)
metric = trial.metric;
iterationCount = 0;
while ~metric.converged && iterationCount < maxIterations
    [nextTrial, nextMetric, accepted] = newtonShootingStep( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, step, period, tolerance);
    if ~accepted
        break;
    end
    iterationCount = iterationCount + 1;
    trial = nextTrial;
    metric = nextMetric;
end
end

function [solution, deviceValue] = solveConsistentInitialPoint(LinerNet, MOSINFO, DIODEINFO, BJTINFO, deviceValue, Error)
LinerNet('Value') = deviceValue(:);
[nodeSolution, ~, solvedDeviceValue] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
if isempty(nodeSolution)
    error('spice:shooting:BadInitialPoint', 'Shooting trial state could not be linearized to a consistent DC point.');
end
solution = [0; nodeSolution];
deviceValue = solvedDeviceValue(:);
end

function [ResData, DeviceValues, endSolution, endDeviceValue] = runShootingPeriod( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, solution, deviceValue, step, period)
LinerNet('Value') = deviceValue(:);
[ResData, DeviceValues] = Trans(LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, solution(:), step, period);
endSolution = ResData(:, end);
endDeviceValue = DeviceValues(:, end);
end

function [trial, metric, accepted] = newtonShootingStep( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, step, period, tolerance)
[jacobian, scaledResidual, stateScale] = finiteDifferenceJacobian( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, step, period, tolerance);
scaledCorrection = solveNewtonCorrection(jacobian, scaledResidual);
if any(~isfinite(scaledCorrection))
    metric = trial.metric;
    accepted = false;
    return;
end

correction = stateScale .* scaledCorrection;
[trial, metric, accepted] = dampedNewtonSearch( ...
    LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, correction, stateInfo, step, period, tolerance);
end

function correction = solveNewtonCorrection(jacobian, scaledResidual)
correction = -(jacobian \ scaledResidual);
end

function [jacobian, scaledResidual, stateScale] = finiteDifferenceJacobian( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, stateInfo, step, period, tolerance)
state = trial.startDynamicState;
stateCount = numel(state);
jacobian = zeros(stateCount, stateCount);
stateScale = dynamicStateCoordinateScale(state, stateInfo);
residualScale = dynamicStateToleranceScale(trial.startDynamicState, trial.endDynamicState, stateInfo, tolerance);
scaledResidual = trial.residual(:) ./ residualScale;

for col = 1:stateCount
    perturbation = finiteDifferenceStep(state(col), stateScale(col));
    forwardState = state;
    backwardState = state;
    forwardState(col) = forwardState(col) + perturbation;
    backwardState(col) = backwardState(col) - perturbation;

    [forwardTrial, ~] = evaluateShootingResidual( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, ...
        trial.startDeviceValue, forwardState, stateInfo, step, period, tolerance);
    [backwardTrial, ~] = evaluateShootingResidual( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, ...
        trial.startDeviceValue, backwardState, stateInfo, step, period, tolerance);
    rawColumn = (forwardTrial.residual - backwardTrial.residual) / (2 * perturbation);
    jacobian(:, col) = (rawColumn(:) .* stateScale(col)) ./ residualScale;
end
end

function [acceptedTrial, acceptedMetric, accepted] = dampedNewtonSearch( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, trial, correction, stateInfo, step, period, tolerance)
accepted = false;
acceptedTrial = trial;
acceptedMetric = trial.metric;
bestScore = max(trial.metric.voltageMetric, trial.metric.currentMetric);

for damping = [1, 0.5, 0.25, 0.125, 0.0625, 0.03125]
    candidateState = trial.startDynamicState + damping * correction;
    [candidateTrial, candidateMetric] = evaluateShootingResidual( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, ...
        trial.startDeviceValue, candidateState, stateInfo, step, period, tolerance);
    candidateScore = max(candidateMetric.voltageMetric, candidateMetric.currentMetric);

    if candidateScore < bestScore
        accepted = true;
        acceptedTrial = candidateTrial;
        acceptedMetric = candidateMetric;
        return;
    end
end
end

function state = extractDynamicState(deviceValue, stateInfo)
capacitorState = zeros(stateInfo.capacitorCount, 1);
for group = 1:stateInfo.capacitorCount
    member = stateInfo.capacitorGroupIndex == group;
    memberValue = deviceValue(stateInfo.capacitorDeviceIndex(member));
    capacitorState(group) = mean(stateInfo.capacitorGroupSign(member) .* memberValue(:));
end

inductorState = deviceValue(stateInfo.inductorDeviceIndex);
state = [capacitorState; inductorState(:)];
end

function deviceValue = applyDynamicState(deviceValue, dynamicState, stateInfo)
deviceValue = deviceValue(:);
for group = 1:stateInfo.capacitorCount
    member = stateInfo.capacitorGroupIndex == group;
    deviceValue(stateInfo.capacitorDeviceIndex(member)) = ...
        stateInfo.capacitorGroupSign(member) .* dynamicState(group);
end

inductorOffset = stateInfo.capacitorCount;
deviceValue(stateInfo.inductorDeviceIndex) = dynamicState(inductorOffset + (1:stateInfo.inductorCount));
end

function metric = dynamicResidualMetric(startState, endState, stateInfo, tolerance)
capacitorCount = stateInfo.capacitorCount;
scale = dynamicStateToleranceScale(startState, endState, stateInfo, tolerance);
voltageMetric = maxScaledResidual(startState(1:capacitorCount), endState(1:capacitorCount), scale(1:capacitorCount));
currentMetric = maxScaledResidual(startState(capacitorCount + 1:end), endState(capacitorCount + 1:end), scale(capacitorCount + 1:end));

metric = struct( ...
    'voltageMetric', voltageMetric, ...
    'currentMetric', currentMetric, ...
    'converged', voltageMetric <= 1 && currentMetric <= 1);
end

function scale = dynamicStateToleranceScale(startState, endState, stateInfo, tolerance)
capacitorCount = stateInfo.capacitorCount;
voltageScale = scaledTolerance( ...
    startState(1:capacitorCount), endState(1:capacitorCount), tolerance.voltageAbs, tolerance.voltageRel);
currentScale = scaledTolerance( ...
    startState(capacitorCount + 1:end), endState(capacitorCount + 1:end), tolerance.currentAbs, tolerance.currentRel);
scale = [voltageScale; currentScale];
end

function scale = dynamicStateCoordinateScale(state, stateInfo)
capacitorCount = stateInfo.capacitorCount;
voltageState = state(1:capacitorCount);
currentState = state(capacitorCount + 1:end);
voltageScale = zeros(numel(voltageState), 1);
currentScale = zeros(numel(currentState), 1);
if ~isempty(voltageState)
    voltageScale = max(1, abs(voltageState(:)));
end
if ~isempty(currentState)
    currentScale = max(1e-3, abs(currentState(:)));
end
scale = [voltageScale(:); currentScale(:)];
end

function perturbation = finiteDifferenceStep(stateValue, coordinateScale)
perturbation = 1e-4 * max(abs(stateValue), coordinateScale);
end

function scale = scaledTolerance(startValue, endValue, absTol, relTol)
if isempty(startValue)
    scale = zeros(0, 1);
    return;
end

scale = max(absTol, relTol * max(abs([startValue(:), endValue(:)]), [], 2));
end

function metric = maxScaledResidual(startValue, endValue, scale)
if isempty(startValue)
    metric = 0;
    return;
end

metric = max(abs(endValue(:) - startValue(:)) ./ scale);
end
