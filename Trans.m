function [ResData, DeviceDatas, transitionMatrix] = ...
    Trans(LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, initialSolution, outputStep, totalTime, varargin)
% TRANS Advance one fixed-output transient window for shooting.
% Shooting uses the same trapezoidal companion update as TransTR_fix:
% internally the circuit is advanced with a half output step and only every
% outputStep sample is returned to callers.

capacitorLine = CINFO('CLine');
inductorLine = LINFO('LLine');
capacitorCount = numel(CINFO('Name'));
inductorCount = numel(LINFO('Name'));
capacitorNodePairs = CINFO('NodeMat');
inductorNodePairs = LINFO('NodeMat');

sinLine = SinINFO('SinLine');
sinAcValues = SinINFO('AcValue');
sinDcValues = SinINFO('DcValue');
sinPhase = SinINFO('Phase');
sinFrequency = SinINFO('Freq');
sinCount = numel(sinAcValues);

capacitorResistanceIndex = capacitorLine + 2 * (1:capacitorCount) - 2;
capacitorVoltageIndex = capacitorLine + 2 * (1:capacitorCount) - 1;
inductorCurrentIndex = inductorLine + 2 * (1:inductorCount) - 2;
inductorResistanceIndex = inductorLine + 2 * (1:inductorCount) - 1;
sinValueIndex = sinLine + (1:sinCount) - 1;

currentDeviceValue = LinerNet('Value');
currentDeviceValue = currentDeviceValue(:);

internalStep = 0.5 * outputStep;
capacitorValue = CINFO('Value');
inductorValue = LINFO('Value');
capacitorValue = capacitorValue(:);
inductorValue = inductorValue(:);

capacitorResistance = CINFO('R') * internalStep;
inductorResistance = LINFO('R') / internalStep;
capacitorResistance = capacitorResistance(:);
inductorResistance = inductorResistance(:);

currentDeviceValue(capacitorResistanceIndex) = capacitorResistance;
currentDeviceValue(inductorResistanceIndex) = inductorResistance;
LinerNet('Value') = currentDeviceValue;

currentSolution = initialSolution(:);
trackTransition = ~isempty(varargin);
transitionMatrix = [];

plotTimeCount = numel(0:outputStep:totalTime);
ResData = zeros(numel(currentSolution), plotTimeCount);
DeviceDatas = zeros(numel(currentDeviceValue), plotTimeCount);

if trackTransition
    stateInfo = varargin{1};
    [nodeSolution, xNames, currentDeviceValue, linearizedA] = calculateDC( ...
        LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
    currentDeviceValue = currentDeviceValue(:);
    currentSolution = [0; nodeSolution];
    LinerNet('Value') = currentDeviceValue;
    [capacitorSourceSensitivity, inductorSourceSensitivity] = initialDynamicSourceSensitivity( ...
        stateInfo, capacitorCount, inductorCount);
    solutionSensitivity = solveStateSolutionSensitivity( ...
        linearizedA, xNames, LinerNet, capacitorVoltageIndex, inductorCurrentIndex, ...
        capacitorSourceSensitivity, inductorSourceSensitivity);
end

ResData(:, 1) = currentSolution;
DeviceDatas(:, 1) = currentDeviceValue;

companionCapacitorVoltage = currentDeviceValue(capacitorVoltageIndex);
companionInductorCurrent = currentDeviceValue(inductorCurrentIndex);
companionCapacitorVoltage = companionCapacitorVoltage(:);
companionInductorCurrent = companionInductorCurrent(:);

capacitorVoltage = branchVoltage(currentSolution, capacitorNodePairs);
inductorVoltage = branchVoltage(currentSolution, inductorNodePairs);
capacitorCurrent = (capacitorVoltage - companionCapacitorVoltage) ./ capacitorResistance;
inductorCurrent = companionInductorCurrent + inductorVoltage ./ inductorResistance;

currentTime = 0;
currentPlotTime = outputStep;
plotIndex = 1;

while plotIndex < plotTimeCount
    currentTime = currentTime + internalStep;

    % TR history sources are derived from the previous physical C/L state.
    companionCapacitorVoltage = capacitorVoltage + capacitorResistance .* capacitorCurrent;
    companionInductorCurrent = inductorCurrent + internalStep * 0.5 * (inductorVoltage ./ inductorValue);
    if trackTransition
        [nextCapacitorSourceSensitivity, nextInductorSourceSensitivity] = nextDynamicSourceSensitivity( ...
            solutionSensitivity, capacitorSourceSensitivity, inductorSourceSensitivity, ...
            capacitorNodePairs, inductorNodePairs, inductorResistance);
    end

    nextDeviceValue = currentDeviceValue;
    nextDeviceValue(capacitorVoltageIndex) = companionCapacitorVoltage;
    nextDeviceValue(inductorCurrentIndex) = companionInductorCurrent;
    nextDeviceValue(sinValueIndex) = Sin_Calculator(sinDcValues, sinAcValues, sinFrequency, currentTime, sinPhase).';

    LinerNet('Value') = nextDeviceValue;
    if trackTransition
        [nodeSolution, xNames, currentDeviceValue, linearizedA] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
    else
        [nodeSolution, ~, currentDeviceValue] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
    end
    currentDeviceValue = currentDeviceValue(:);

    currentSolution = [0; nodeSolution];
    LinerNet('Value') = currentDeviceValue;

    capacitorVoltage = branchVoltage(currentSolution, capacitorNodePairs);
    inductorVoltage = branchVoltage(currentSolution, inductorNodePairs);
    capacitorCurrent = (capacitorVoltage - companionCapacitorVoltage) ./ capacitorResistance;
    inductorCurrent = companionInductorCurrent + inductorVoltage ./ inductorResistance;
    if trackTransition
        capacitorSourceSensitivity = nextCapacitorSourceSensitivity;
        inductorSourceSensitivity = nextInductorSourceSensitivity;
        solutionSensitivity = solveStateSolutionSensitivity( ...
            linearizedA, xNames, LinerNet, capacitorVoltageIndex, inductorCurrentIndex, ...
            capacitorSourceSensitivity, inductorSourceSensitivity);
    end

    if abs(currentTime - currentPlotTime) <= internalStep / 2
        plotIndex = plotIndex + 1;
        ResData(:, plotIndex) = currentSolution;
        DeviceDatas(:, plotIndex) = currentDeviceValue;
        currentPlotTime = currentPlotTime + outputStep;
    end
end

if trackTransition
    transitionMatrix = extractDynamicStateSensitivity(capacitorSourceSensitivity, inductorSourceSensitivity, stateInfo);
end
end

function voltage = branchVoltage(solution, nodePairs)
if isempty(nodePairs)
    voltage = zeros(0, 1);
    return;
end

voltage = solution(nodePairs(:, 1)) - solution(nodePairs(:, 2));
voltage = voltage(:);
end

function [capacitorSensitivity, inductorSensitivity] = initialDynamicSourceSensitivity(stateInfo, capacitorCount, inductorCount)
stateCount = stateInfo.capacitorCount + stateInfo.inductorCount;
capacitorSensitivity = zeros(capacitorCount, stateCount);
for idx = 1:numel(stateInfo.capacitorDeviceIndex)
    capacitorPosition = stateInfo.capacitorPosition(idx);
    group = stateInfo.capacitorGroupIndex(idx);
    capacitorSensitivity(capacitorPosition, group) = stateInfo.capacitorGroupSign(idx);
end

inductorSensitivity = zeros(inductorCount, stateCount);
for idx = 1:inductorCount
    inductorSensitivity(idx, stateInfo.capacitorCount + idx) = 1;
end
end

function [capacitorSensitivity, inductorSensitivity] = nextDynamicSourceSensitivity( ...
        solutionSensitivity, currentCapacitorSensitivity, currentInductorSensitivity, capacitorNodePairs, inductorNodePairs, inductorResistance)
capacitorBranchSensitivity = branchSensitivity(solutionSensitivity, capacitorNodePairs);
inductorBranchSensitivity = branchSensitivity(solutionSensitivity, inductorNodePairs);

capacitorSensitivity = 2 * capacitorBranchSensitivity - currentCapacitorSensitivity;
inductorSensitivity = currentInductorSensitivity;
if ~isempty(inductorSensitivity)
    inductorSensitivity = currentInductorSensitivity + 2 * (inductorBranchSensitivity ./ inductorResistance(:));
end
end

function sensitivity = branchSensitivity(solutionSensitivity, nodePairs)
if isempty(nodePairs)
    sensitivity = zeros(0, size(solutionSensitivity, 2));
    return;
end

sensitivity = solutionSensitivity(nodePairs(:, 1), :) - solutionSensitivity(nodePairs(:, 2), :);
end

function solutionSensitivity = solveStateSolutionSensitivity( ...
        linearizedA, xNames, LinerNet, capacitorVoltageIndex, inductorCurrentIndex, capacitorSensitivity, inductorSensitivity)
rhs = dynamicSourceRhs(xNames, LinerNet, capacitorVoltageIndex, inductorCurrentIndex, capacitorSensitivity, inductorSensitivity);
if isempty(rhs)
    solutionSensitivity = zeros(1, 0);
    return;
end

nodeSensitivity = LU_solve(linearizedA, rhs);
solutionSensitivity = [zeros(1, size(nodeSensitivity, 2)); nodeSensitivity];
end

function rhs = dynamicSourceRhs(xNames, LinerNet, capacitorVoltageIndex, inductorCurrentIndex, capacitorSensitivity, inductorSensitivity)
stateCount = size([capacitorSensitivity; inductorSensitivity], 2);
rhs = zeros(numel(xNames), stateCount);
names = LinerNet('Name');
node1 = LinerNet('N1');
node2 = LinerNet('N2');

for idx = 1:numel(capacitorVoltageIndex)
    sensitivity = capacitorSensitivity(idx, :);
    if any(sensitivity)
        sourceName = names{capacitorVoltageIndex(idx)};
        row = find(strcmp(xNames, ['I_' sourceName]), 1);
        rhs(row, :) = rhs(row, :) + sensitivity;
    end
end

for idx = 1:numel(inductorCurrentIndex)
    sensitivity = inductorSensitivity(idx, :);
    if any(sensitivity)
        sourceIndex = inductorCurrentIndex(idx);
        rhs = stampCurrentSourceSensitivity(rhs, xNames, node1(sourceIndex), node2(sourceIndex), sensitivity);
    end
end
end

function rhs = stampCurrentSourceSensitivity(rhs, xNames, sourceNode, sinkNode, sensitivity)
if sourceNode ~= 0
    row = find(strcmp(xNames, ['v_' num2str(sourceNode)]), 1);
    rhs(row, :) = rhs(row, :) - sensitivity;
end
if sinkNode ~= 0
    row = find(strcmp(xNames, ['v_' num2str(sinkNode)]), 1);
    rhs(row, :) = rhs(row, :) + sensitivity;
end
end

function stateSensitivity = extractDynamicStateSensitivity(capacitorSensitivity, inductorSensitivity, stateInfo)
stateCount = stateInfo.capacitorCount + stateInfo.inductorCount;
capacitorStateSensitivity = zeros(stateInfo.capacitorCount, stateCount);
for group = 1:stateInfo.capacitorCount
    member = stateInfo.capacitorGroupIndex == group;
    memberPosition = stateInfo.capacitorPosition(member);
    memberSign = stateInfo.capacitorGroupSign(member);
    capacitorStateSensitivity(group, :) = mean(memberSign .* capacitorSensitivity(memberPosition, :), 1);
end

stateSensitivity = [capacitorStateSensitivity; inductorSensitivity];
end
