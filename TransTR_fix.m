function [ResData, DeviceDatas] = TransTR_fix(InitRes, InitDeviceValue, CVp, CIp, LVp, LIp, ...
                                                LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, ...
                                                Error, delta_t, stopTime, stepTime)
% TRANSTR_FIX Fixed-step trapezoidal transient simulation.
% C/L companion resistances are constant for the fixed internal step.  Each
% iteration updates only the companion source terms and sinusoidal sources,
% then solves the nonlinear DC equivalent at the current time point.

capacitorValue = CINFO('Value');
inductorValue = LINFO('Value');
capacitorValue = capacitorValue(:);
inductorValue = inductorValue(:);

capacitorNodePairs = CINFO('NodeMat');
inductorNodePairs = LINFO('NodeMat');
capacitorCount = numel(capacitorValue);
inductorCount = numel(inductorValue);
capacitorLine = CINFO('CLine');
inductorLine = LINFO('LLine');

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

capacitorResistance = 0.5 * delta_t ./ capacitorValue;
inductorResistance = 2 .* inductorValue ./ delta_t;

capacitorVoltage = CVp(:);
capacitorCurrent = CIp(:);
inductorVoltage = LVp(:);
inductorCurrent = LIp(:);

plotTimeCount = numel(0:stepTime:stopTime);
currentSolution = InitRes(:);
currentDeviceValue = InitDeviceValue(:);

ResData = zeros(numel(currentSolution), plotTimeCount);
DeviceDatas = zeros(numel(currentDeviceValue), plotTimeCount);
ResData(:, 1) = currentSolution;
DeviceDatas(:, 1) = currentDeviceValue;

currentPlotTime = stepTime;
plotIndex = 1;
currentTime = 0;

while plotIndex < plotTimeCount
    currentTime = currentTime + delta_t;

    companionCapacitorVoltage = capacitorVoltage + capacitorResistance .* capacitorCurrent;
    companionInductorCurrent = inductorCurrent + delta_t * 0.5 * (inductorVoltage ./ inductorValue);

    nextDeviceValue = currentDeviceValue;
    nextDeviceValue(capacitorResistanceIndex) = capacitorResistance;
    nextDeviceValue(capacitorVoltageIndex) = companionCapacitorVoltage;
    nextDeviceValue(inductorCurrentIndex) = companionInductorCurrent;
    nextDeviceValue(inductorResistanceIndex) = inductorResistance;
    nextDeviceValue(sinValueIndex) = Sin_Calculator(sinDcValues, sinAcValues, sinFrequency, currentTime, sinPhase).';

    LinerNet('Value') = nextDeviceValue;
    [nodeSolution, ~, currentDeviceValue] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
    currentDeviceValue = currentDeviceValue(:);
    currentSolution = [0; nodeSolution];

    % Original C/L nodes appear before companion-only variables, so the same
    % ground-inclusive node pairs can be reused after each DC solve.
    if ~isempty(inductorNodePairs)
        inductorVoltage = currentSolution(inductorNodePairs(:, 1)) - currentSolution(inductorNodePairs(:, 2));
    end
    if ~isempty(capacitorNodePairs)
        capacitorVoltage = currentSolution(capacitorNodePairs(:, 1)) - currentSolution(capacitorNodePairs(:, 2));
    end

    inductorCurrent = companionInductorCurrent + inductorVoltage ./ inductorResistance;
    capacitorCurrent = (capacitorVoltage - companionCapacitorVoltage) ./ capacitorResistance;

    if abs(currentTime - currentPlotTime) <= delta_t / 2
        plotIndex = plotIndex + 1;
        ResData(:, plotIndex) = currentSolution;
        DeviceDatas(:, plotIndex) = currentDeviceValue;
        currentPlotTime = currentPlotTime + stepTime;
    end
end
end
