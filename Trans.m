function [ResData, DeviceDatas] = ...
    Trans(LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, initialSolution, outputStep, totalTime)
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

plotTimeCount = numel(0:outputStep:totalTime);
ResData = zeros(numel(currentSolution), plotTimeCount);
DeviceDatas = zeros(numel(currentDeviceValue), plotTimeCount);
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

    nextDeviceValue = currentDeviceValue;
    nextDeviceValue(capacitorVoltageIndex) = companionCapacitorVoltage;
    nextDeviceValue(inductorCurrentIndex) = companionInductorCurrent;
    nextDeviceValue(sinValueIndex) = Sin_Calculator(sinDcValues, sinAcValues, sinFrequency, currentTime, sinPhase).';

    LinerNet('Value') = nextDeviceValue;
    [nodeSolution, ~, currentDeviceValue] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
    currentDeviceValue = currentDeviceValue(:);

    currentSolution = [0; nodeSolution];
    LinerNet('Value') = currentDeviceValue;

    capacitorVoltage = branchVoltage(currentSolution, capacitorNodePairs);
    inductorVoltage = branchVoltage(currentSolution, inductorNodePairs);
    capacitorCurrent = (capacitorVoltage - companionCapacitorVoltage) ./ capacitorResistance;
    inductorCurrent = companionInductorCurrent + inductorVoltage ./ inductorResistance;

    if abs(currentTime - currentPlotTime) <= internalStep / 2
        plotIndex = plotIndex + 1;
        ResData(:, plotIndex) = currentSolution;
        DeviceDatas(:, plotIndex) = currentDeviceValue;
        currentPlotTime = currentPlotTime + outputStep;
    end
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
