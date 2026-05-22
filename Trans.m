function [ResData, DeviceDatas] = ...
    Trans(LinerNet, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, SinINFO, Error, initialSolution, delta_t, totalTime)
% TRANS Advance one fixed-step transient window.
% This routine is used by shooting_method.  The companion RC/RL values are
% fixed for the whole window; only the companion source terms and sinusoidal
% sources change at each time point.

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

capacitorResistance = CINFO('R') * delta_t;
inductorResistance = LINFO('R') / delta_t;
capacitorResistance = capacitorResistance(:);
inductorResistance = inductorResistance(:);

currentDeviceValue(capacitorResistanceIndex) = capacitorResistance;
currentDeviceValue(inductorResistanceIndex) = inductorResistance;
LinerNet('Value') = currentDeviceValue;

capacitorVoltage = currentDeviceValue(capacitorVoltageIndex);
inductorCurrent = currentDeviceValue(inductorCurrentIndex);
capacitorVoltage = capacitorVoltage(:);
inductorCurrent = inductorCurrent(:);

stepCount = round(totalTime / delta_t);
currentSolution = initialSolution(:);

ResData = zeros(numel(currentSolution), stepCount + 1);
DeviceDatas = zeros(numel(currentDeviceValue), stepCount + 1);
ResData(:, 1) = currentSolution;
DeviceDatas(:, 1) = currentDeviceValue;

currentTime = 0;
for stepIndex = 2:(stepCount + 1)
    currentTime = currentTime + delta_t;

    % LC companion sources are derived from the previous converged solution.
    % Node pairs already use the ground-inclusive indexing expected here.
    previousInductorVoltage = [];
    if ~isempty(inductorNodePairs)
        previousInductorVoltage = currentSolution(inductorNodePairs(:, 1)) - currentSolution(inductorNodePairs(:, 2));
    end

    previousCapacitorVoltage = [];
    if ~isempty(capacitorNodePairs)
        previousCapacitorVoltage = currentSolution(capacitorNodePairs(:, 1)) - currentSolution(capacitorNodePairs(:, 2));
    end

    previousInductorCurrent = inductorCurrent + previousInductorVoltage ./ inductorResistance;
    previousCapacitorCurrent = (previousCapacitorVoltage - capacitorVoltage) ./ capacitorResistance;

    capacitorVoltage = previousCapacitorVoltage + capacitorResistance .* previousCapacitorCurrent;
    inductorCurrent = previousInductorCurrent + previousInductorVoltage ./ inductorResistance;

    nextDeviceValue = currentDeviceValue;
    nextDeviceValue(capacitorVoltageIndex) = capacitorVoltage;
    nextDeviceValue(inductorCurrentIndex) = inductorCurrent;
    nextDeviceValue(sinValueIndex) = Sin_Calculator(sinDcValues, sinAcValues, sinFrequency, currentTime, sinPhase).';

    LinerNet('Value') = nextDeviceValue;
    [nodeSolution, ~, currentDeviceValue] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
    currentDeviceValue = currentDeviceValue(:);

    currentSolution = [0; nodeSolution];
    LinerNet('Value') = currentDeviceValue;

    ResData(:, stepIndex) = currentSolution;
    DeviceDatas(:, stepIndex) = currentDeviceValue;
end
end
